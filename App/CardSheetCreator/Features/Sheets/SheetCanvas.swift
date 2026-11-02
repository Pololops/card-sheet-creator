import Domain
import SwiftUI

/// A sheet on the page. Drag an image inside its slot to frame it; its clones follow on release.
struct SheetCanvas: View {
  let sheet: Sheet
  /// Geometry shown on screen: the sheet's own, or the unsaved draft one while resizing.
  let geometry: SheetGeometry
  let scale: Double
  let images: ImageCache
  let isEditable: Bool
  @Binding var selectedSlot: Int?
  let onCropChange: (CropAnchor, ImageRef) -> Void

  @State private var drag: ActiveDrag?
  @State private var pan: ActivePan?

  struct ActiveDrag: Equatable {
    var slot: Int
    var image: ImageRef
    var anchor: CropAnchor
  }

  /// A two-finger scroll in progress. The size is `nil` until a cache miss resolves.
  private struct ActivePan {
    var slot: Int
    var image: ImageRef
    var startAnchor: CropAnchor
    var size: PixelSize?
    var offset = MMOffset(dx: 0, dy: 0)
  }

  var body: some View {
    let layout = try? Domain.GridLayout.make(geometry)
    let contents = contents(capacity: layout?.capacity ?? 0)
    PaperSheet(scale: scale) {
      if let layout {
        ForEach(Array(zip(layout.slots, contents).enumerated()), id: \.offset) { index, entry in
          slot(index: index, frame: entry.0.scaled(scale), image: entry.1)
        }
        if let drag, layout.slots.indices.contains(drag.slot) {
          DragOverlay(
            drag: drag, frame: layout.slots[drag.slot].scaled(scale), slotSize: geometry.slot, scale: scale,
            images: images)
        }
      }
    }
    .background(
      TrackpadProbe(role: .page) { handleTrackpad($0, layout: layout, contents: contents) }
    )
    // Only the edge into the centre taps the trackpad; a drag that starts centred, or ends, stays silent.
    .sensoryFeedback(.alignment, trigger: drag.map { Crop.isCentered($0.anchor) }) {
      $0 == false && $1 == true
    }
    .focusable(isEditable)
    .focusEffectDisabled()
    .onKeyPress(keys: [.leftArrow, .rightArrow, .upArrow, .downArrow]) { press in
      nudge(press, contents: contents) ? .handled : .ignored
    }
    .onKeyPress(.escape) {
      guard selectedSlot != nil else { return .ignored }
      selectedSlot = nil
      return .handled
    }
  }

  private func contents(capacity: Int) -> [ImageRef?] {
    var preview = sheet
    preview.geometry = geometry
    return (try? preview.slotContents()) ?? []
  }

  private func slot(index: Int, frame: CGRect, image: ImageRef?) -> some View {
    let isActive = drag?.slot == index
    let isClone = drag != nil && !isActive && image != nil && image == drag?.image
    return SlotView(
      image: image, anchor: isActive ? drag?.anchor ?? .centered : image.map(sheet.crop(for:)) ?? .centered,
      slotSize: geometry.slot, scale: scale, images: images, isDraggable: isEditable
    )
    .frame(width: frame.width, height: frame.height)
    .clipped()
    // Clipping hides the overflowing image but keeps it hit-testable over the neighbouring slots.
    .contentShape(Rectangle())
    .overlay {
      if isClone {
        Rectangle().strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])).padding(
          -3.5)
      } else if selectedSlot == index && drag == nil && isEditable {
        Rectangle().strokeBorder(Color.accentColor, lineWidth: 2)
      }
    }
    .offset(x: frame.minX, y: frame.minY)
    .gesture(dragGesture(index: index, image: image), including: isEditable && image != nil ? .all : .none)
    // Empty slots are hit-testable too, so a tap on one must deselect rather than select nothing.
    .onTapGesture { if isEditable { selectedSlot = image == nil ? nil : index } }
    .accessibilityElement()
    .accessibilityLabel(slotLabel(index: index, image: image))
    .accessibilityAddTraits(selectedSlot == index ? [.isSelected, .isButton] : .isButton)
  }

  private func dragGesture(index: Int, image: ImageRef?) -> some Gesture {
    DragGesture(minimumDistance: 1)
      .onChanged { value in
        guard let image, let size = images.cachedDisplaySize(of: image) else { return }
        let offset = MMOffset(dx: value.translation.width / scale, dy: value.translation.height / scale)
        drag = ActiveDrag(
          slot: index, image: image,
          anchor: Crop.anchor(sheet.crop(for: image), afterDragBy: offset, image: size, slot: geometry.slot))
        selectedSlot = index
      }
      .onEnded { _ in
        if let drag { onCropChange(drag.anchor, drag.image) }
        drag = nil
      }
  }

  /// The image a two-finger scroll pans: the selected slot's, and only while the pointer is over that slot.
  static func panTarget(
    at point: CGPoint, layout: Domain.GridLayout?, contents: [ImageRef?], selectedSlot: Int?, scale: Double
  ) -> (slot: Int, image: ImageRef)? {
    guard let layout, let selectedSlot, layout.slots.indices.contains(selectedSlot),
      contents.indices.contains(selectedSlot), let image = contents[selectedSlot],
      layout.slots[selectedSlot].scaled(scale).contains(point)
    else { return nil }
    return (selectedSlot, image)
  }

  /// Returns whether the event is ours, which is what keeps it from the page scroll.
  private func handleTrackpad(_ event: TrackpadEvent, layout: Domain.GridLayout?, contents: [ImageRef?])
    -> Bool
  {
    switch event {
    case .panBegan(let point):
      return beginPan(at: point, layout: layout, contents: contents)
    case .panChanged(let delta):
      movePan(by: delta)
    case .panEnded:
      endPan()
    case .panCancelled:
      cancelPan()
    case .smartMagnify:
      return false
    }
    return true
  }

  private func beginPan(at point: CGPoint, layout: Domain.GridLayout?, contents: [ImageRef?]) -> Bool {
    guard isEditable,
      let target = Self.panTarget(
        at: point, layout: layout, contents: contents, selectedSlot: selectedSlot, scale: scale)
    else { return false }
    let size = images.cachedDisplaySize(of: target.image)
    if let size, !Crop.canReframe(image: size, slot: geometry.slot) { return false }
    pan = ActivePan(
      slot: target.slot, image: target.image, startAnchor: sheet.crop(for: target.image), size: size)
    // The gesture has already started: claim it now, and drop it if the image turns out to be uncroppable.
    if size == nil { resolvePanSize(of: target.image) }
    return true
  }

  private func resolvePanSize(of image: ImageRef) {
    Task {
      let size = await images.displaySize(of: image)
      guard pan?.image == image else { return }
      guard let size, Crop.canReframe(image: size, slot: geometry.slot) else { return cancelPan() }
      pan?.size = size
      previewPan()
    }
  }

  private func movePan(by delta: CGVector) {
    guard pan != nil else { return }
    pan?.offset.dx += delta.dx / scale
    pan?.offset.dy += delta.dy / scale
    previewPan()
  }

  private func previewPan() {
    guard let pan, let size = pan.size else { return }
    drag = ActiveDrag(
      slot: pan.slot, image: pan.image,
      anchor: Crop.anchor(pan.startAnchor, afterDragBy: pan.offset, image: size, slot: geometry.slot))
  }

  /// One crop change for the whole gesture, so one ⌘Z undoes it.
  private func endPan() {
    if pan != nil, let drag { onCropChange(drag.anchor, drag.image) }
    cancelPan()
  }

  private func cancelPan() {
    guard pan != nil else { return }
    pan = nil
    drag = nil
  }

  private static let nudgeStep = 0.5
  private static let largeNudgeStep = 5.0

  /// Arrow keys move the selected slot's image like a drag, so framing never needs a pointer.
  private func nudge(_ press: KeyPress, contents: [ImageRef?]) -> Bool {
    guard isEditable, let selectedSlot, contents.indices.contains(selectedSlot),
      let image = contents[selectedSlot]
    else { return false }
    let step = press.modifiers.contains(.shift) ? Self.largeNudgeStep : Self.nudgeStep
    let offset: MMOffset =
      switch press.key {
      case .leftArrow: MMOffset(dx: -step, dy: 0)
      case .rightArrow: MMOffset(dx: step, dy: 0)
      case .upArrow: MMOffset(dx: 0, dy: -step)
      default: MMOffset(dx: 0, dy: step)
      }
    Task {
      guard let size = await images.displaySize(of: image) else { return }
      onCropChange(
        Crop.anchor(sheet.crop(for: image), afterDragBy: offset, image: size, slot: geometry.slot), image)
    }
    return true
  }

  private func slotLabel(index: Int, image: ImageRef?) -> String {
    guard let image else { return "Case \(index + 1), vide" }
    let clones = sheet.cloneCount(of: image) - 1
    let framing = Crop.isCentered(sheet.crop(for: image)) ? "centrée" : "décalée"
    let cloneText = clones > 0 ? ", \(clones) clone\(clones > 1 ? "s" : "")" : ""
    return "Case \(index + 1), \(image.originalName), \(framing)\(cloneText)"
  }
}

/// One slot's image, covering the slot and positioned by its crop anchor.
struct SlotView: View {
  let image: ImageRef?
  let anchor: CropAnchor
  let slotSize: SlotSize
  let scale: Double
  let images: ImageCache
  let isDraggable: Bool

  @Environment(\.displayScale) private var displayScale
  @State private var bitmap: CGImage?
  @State private var pixelSize: PixelSize?

  var body: some View {
    ZStack(alignment: .topLeading) {
      if let bitmap, let pixelSize {
        let cover = Crop.coverRect(image: pixelSize, slot: slotSize, anchor: anchor).scaled(scale)
        Image(decorative: bitmap, scale: 1)
          .resizable()
          .frame(width: cover.width, height: cover.height)
          .offset(x: cover.minX, y: cover.minY)
      } else if image != nil {
        Rectangle().fill(.quaternary)
      }
    }
    .frame(width: slotSize.width.mm * scale, height: slotSize.height.mm * scale, alignment: .topLeading)
    // The hand only promises a drag that can move the image; the overflow stays out of the hover area.
    .contentShape(Rectangle())
    .pointerStyle(canReframe ? .grabIdle : nil)
    .task(id: image) {
      // Slot views are reused across sheets: pixels must never outlive the image they were loaded for.
      // A cancelled load still runs to completion, so its result is dropped rather than shown.
      bitmap = nil
      pixelSize = nil
      guard let image else { return }
      let size = await images.displaySize(of: image)
      let maxPixels = Self.maxPixels(slotSize, scale, displayScale)
      let loaded = await images.thumbnail(of: image, maxPixelSize: maxPixels)
      guard !Task.isCancelled else { return }
      pixelSize = size
      bitmap = loaded
    }
  }

  private var canReframe: Bool {
    guard isDraggable, let pixelSize else { return false }
    return Crop.canReframe(image: pixelSize, slot: slotSize)
  }

  /// Enough pixels for the slot at the current zoom, bucketed so zooming doesn't reload constantly.
  static func maxPixels(_ slot: SlotSize, _ scale: Double, _ displayScale: Double) -> Int {
    let needed = max(slot.width.mm, slot.height.mm) * scale * displayScale * 2.5
    return max(256, Int(pow(2, ceil(log2(needed)))))
  }
}
