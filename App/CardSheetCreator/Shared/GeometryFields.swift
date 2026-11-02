import Domain
import SwiftUI

/// Width, height and gutter fields; a value that cannot fit on A4 is refused with a message.
struct GeometryFields: View {
  @Binding var geometry: SheetGeometry
  var original: SheetGeometry?

  private static let slotStep = Millimeters(tenths: 5)
  private static let gutterStep = Millimeters(tenths: 10)
  private static let maxGutter = Millimeters(tenths: 200)
  private static let rowSpacing: CGFloat = 10
  /// From the Largeur row centre down to the gap centre between both rows.
  private static let lockOffset = (MillimeterField.stepSide + rowSpacing) / 2

  @State private var rejection: String?
  @State private var isLocked = true
  @State private var proportions = ProportionLock()

  var body: some View {
    VStack(alignment: .leading, spacing: Self.rowSpacing) {
      InspectorHeader(title: "Cases")
      slotField(.width, label: "Largeur")
        .overlay(alignment: .trailing) { lockToggle.offset(y: Self.lockOffset) }
        .zIndex(1)  // the lock's lower half sits over the Hauteur row and must still get the click
      slotField(.height, label: "Hauteur")
      MillimeterField(
        label: "Gouttière", value: field(\.gutter), step: Self.gutterStep, range: .zero...Self.maxGutter,
        isChanged: isChanged(\.gutter))
      Text(rejection ?? "Cases au pas de 0,5 mm, gouttière au mm.")
        .font(Design.Typography.caption)
        .foregroundStyle(rejection == nil ? AnyShapeStyle(.secondary) : AnyShapeStyle(Design.Palette.warning))
    }
  }

  // The HIG asks for a "Constrain proportions" checkbox; a padlock between the two fields was requested
  // instead, as it reads at a glance in this dense inspector (AGENTS.md: deviations need a stated reason).
  private var lockToggle: some View {
    Toggle(isOn: $isLocked) {
      Label("Conserver les proportions", systemImage: isLocked ? "lock.fill" : "lock.open")
        .labelStyle(.iconOnly)
        .foregroundStyle(.secondary)
        .frame(width: MillimeterField.stepSide, height: MillimeterField.stepSide)
        .contentShape(Rectangle())
    }
    .toggleStyle(.button)
    .buttonStyle(.plain)
    .help("Conserver les proportions")
    // Geometry read from disk may admit no ratio-keeping value; the fields then edit freely, so the lock
    // must not look active.
    .disabled(!canKeepProportions)
    .padding(.trailing, MillimeterField.fieldTrailingSpan)
  }

  private var canKeepProportions: Bool {
    proportionalRange(of: .width) != nil && proportionalRange(of: .height) != nil
  }

  private func proportionalRange(of side: SlotSide) -> ClosedRange<Millimeters>? {
    proportions.range(
      of: side, for: geometry.slot, minimum: Domain.GridLayout.minimumSlotSide, maximum: Page.usableArea)
  }

  private func slotField(_ side: SlotSide, label: String) -> some View {
    let slot: WritableKeyPath<SheetGeometry, SlotSize> = \.slot
    let path = slot.appending(path: side.keyPath)
    let minimum = Domain.GridLayout.minimumSlotSide
    let lockedRange = isLocked ? proportionalRange(of: side) : nil
    return MillimeterField(
      label: label, value: lockedRange == nil ? field(path) : proportionalField(side),
      step: Self.slotStep, range: lockedRange ?? minimum...Page.usableArea[keyPath: side.keyPath],
      isChanged: isChanged(path))
  }

  private func field(_ keyPath: WritableKeyPath<SheetGeometry, Millimeters>) -> Binding<Millimeters> {
    Binding(
      get: { geometry[keyPath: keyPath] },
      set: { value in
        var candidate = geometry
        candidate[keyPath: keyPath] = value
        apply(candidate)
      })
  }

  /// One `geometry` write per edit, so the template path records a single undo step.
  private func proportionalField(_ side: SlotSide) -> Binding<Millimeters> {
    Binding(
      get: { geometry.slot[keyPath: side.keyPath] },
      set: { value in
        proportions.resize(geometry.slot, setting: side, to: value) { slot in
          var candidate = geometry
          candidate.slot = slot
          return apply(candidate)
        }
      })
  }

  @discardableResult
  private func apply(_ candidate: SheetGeometry) -> Bool {
    guard (try? Domain.GridLayout.make(candidate)) != nil else {
      rejection = "Trop grand : une case doit tenir dans la zone de 200 × 287 mm."
      return false
    }
    rejection = nil
    geometry = candidate
    return true
  }

  private func isChanged(_ keyPath: KeyPath<SheetGeometry, Millimeters>) -> Bool {
    guard let original else { return false }
    return original[keyPath: keyPath] != geometry[keyPath: keyPath]
  }
}
