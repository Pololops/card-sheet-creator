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

  struct ActiveDrag: Equatable {
    var slot: Int
    var image: ImageRef
    var anchor: CropAnchor
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

/// While dragging: the overflowing part of the image in transparency, plus centre guides once centered.
private struct DragOverlay: View {
  let drag: SheetCanvas.ActiveDrag
  let frame: CGRect
  let slotSize: SlotSize
  let scale: Double
  let images: ImageCache

  var body: some View {
    let isCentered = Crop.isCentered(drag.anchor)
    ZStack(alignment: .topLeading) {
      SlotView(
        image: drag.image, anchor: drag.anchor, slotSize: slotSize, scale: scale, images: images,
        isDraggable: false
      )
      .opacity(0.3)
      .offset(x: frame.minX, y: frame.minY)
      Rectangle()
        .strokeBorder(Color.accentColor, lineWidth: 2)
        .overlay {
          if isCentered { CenterGuides() }
        }
        .frame(width: frame.width, height: frame.height)
        .offset(x: frame.minX, y: frame.minY)
      if isCentered {
        Text("Centrée")
          .font(.system(size: 10, weight: .bold))
          .foregroundStyle(.white)
          .padding(.horizontal, 8)
          .padding(.vertical, 2)
          .background(Design.Palette.centerGuide, in: Capsule())
          .frame(width: frame.width)
          .offset(x: frame.minX, y: frame.minY - 28)
      }
    }
    .allowsHitTesting(false)
    .accessibilityHidden(true)
  }
}

private struct CenterGuides: View {
  var body: some View {
    ZStack {
      Rectangle().fill(Design.Palette.centerGuide).frame(width: 1.5).shadow(color: .white, radius: 0, x: 1)
        .shadow(color: .white, radius: 0, x: -1)
      Rectangle().fill(Design.Palette.centerGuide).frame(height: 1.5).shadow(color: .white, radius: 0, y: 1)
        .shadow(color: .white, radius: 0, y: -1)
    }
  }
}
