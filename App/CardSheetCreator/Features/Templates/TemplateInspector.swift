import Domain
import SwiftUI

struct TemplateInspector: View {
  @Bindable var model: LibraryModel
  let template: Template

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      Text("Gabarit").font(Design.Typography.body.weight(.bold))
      NameField(name: template.name) { model.rename(.template(template.id), to: $0) }
      GeometryFields(geometry: geometryBinding)
      CapacityCard(geometry: template.geometry)
      pageSection
      Spacer(minLength: 0)
      SavedFooter(date: template.updatedAt)
    }
    .padding(16)
  }

  private var geometryBinding: Binding<SheetGeometry> {
    Binding(
      get: { template.geometry },
      set: { model.updateGeometry(ofTemplate: template.id, to: $0) })
  }

  private var pageSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      InspectorHeader(title: "Page")
      InspectorRow(label: "Format", value: "A4 portrait · 210 × 297")
      HStack {
        HStack(spacing: 8) {
          MarginSwatch()
          Text("Marge de sécurité")
        }
        Spacer()
        Text("\(Page.safetyMargin.formatted) mm, fixe").foregroundStyle(.secondary)
      }
      .font(Design.Typography.body)
    }
  }
}

/// Width, height and gutter fields; a value that cannot fit on A4 is refused with a message.
struct GeometryFields: View {
  @Binding var geometry: SheetGeometry
  var original: SheetGeometry?

  private static let slotStep = Millimeters(tenths: 5)
  private static let gutterStep = Millimeters(tenths: 10)
  private static let maxGutter = Millimeters(tenths: 200)

  @State private var rejection: String?

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      InspectorHeader(title: "Cases")
      MillimeterField(
        label: "Largeur", value: field(\.slot.width), step: Self.slotStep,
        range: Domain.GridLayout.minimumSlotSide...usable.width, isChanged: isChanged(\.slot.width))
      MillimeterField(
        label: "Hauteur", value: field(\.slot.height), step: Self.slotStep,
        range: Domain.GridLayout.minimumSlotSide...usable.height, isChanged: isChanged(\.slot.height))
      MillimeterField(
        label: "Gouttière", value: field(\.gutter), step: Self.gutterStep, range: .zero...Self.maxGutter,
        isChanged: isChanged(\.gutter))
      Text(rejection ?? "Cases au pas de 0,5 mm, gouttière au mm.")
        .font(Design.Typography.caption)
        .foregroundStyle(rejection == nil ? AnyShapeStyle(.secondary) : AnyShapeStyle(Design.Palette.warning))
    }
  }

  private var usable: SlotSize {
    let margin = 2 * Page.safetyMargin.tenths
    return SlotSize(
      width: Millimeters(tenths: Page.a4.width.tenths - margin),
      height: Millimeters(tenths: Page.a4.height.tenths - margin))
  }

  private func field(_ keyPath: WritableKeyPath<SheetGeometry, Millimeters>) -> Binding<Millimeters> {
    Binding(
      get: { geometry[keyPath: keyPath] },
      set: { value in
        var candidate = geometry
        candidate[keyPath: keyPath] = value
        guard (try? Domain.GridLayout.make(candidate)) != nil else {
          rejection = "Trop grand : une case doit tenir dans la zone de 200 × 287 mm."
          return
        }
        rejection = nil
        geometry = candidate
      })
  }

  private func isChanged(_ keyPath: KeyPath<SheetGeometry, Millimeters>) -> Bool {
    guard let original else { return false }
    return original[keyPath: keyPath] != geometry[keyPath: keyPath]
  }
}

/// "3 × 3 = 9 cartes", the key figure of a geometry.
struct CapacityCard: View {
  let geometry: SheetGeometry
  var previousCapacity: Int?

  var body: some View {
    let layout = try? Domain.GridLayout.make(geometry)
    HStack(spacing: 12) {
      Image(systemName: "square.grid.3x3")
        .font(.system(size: 17, weight: .medium))
        .foregroundStyle(.white)
        .frame(width: 34, height: 34)
        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 10))
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 1) {
        if let layout {
          Text("\(layout.columns) × \(layout.rows) = \(layout.capacity) cartes").font(
            Design.Typography.figure
          )
          .monospacedDigit()
        }
        if let previousCapacity, previousCapacity != layout?.capacity {
          Text("avant : \(previousCapacity)").font(Design.Typography.callout.weight(.semibold))
            .foregroundStyle(Design.Palette.draftText)
        } else {
          Text("par planche A4").font(Design.Typography.caption).foregroundStyle(.secondary)
        }
      }
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.background.opacity(0.72), in: RoundedRectangle(cornerRadius: 14))
    .accessibilityElement(children: .combine)
  }
}

struct NameField: View {
  let name: String
  let onCommit: (String) -> Void
  @State private var text = ""

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("Nom").font(Design.Typography.caption.weight(.semibold)).foregroundStyle(.secondary)
      TextField("Nom", text: $text)
        .labelsHidden()
        .textFieldStyle(.roundedBorder)
        .onSubmit { onCommit(text) }
        .accessibilityLabel("Nom")
    }
    .onAppear { text = name }
    .onChange(of: name) { _, newName in text = newName }
  }
}

struct SavedFooter: View {
  let date: Date

  var body: some View {
    Label(
      "Enregistré · modifié à \(date.formatted(date: .omitted, time: .shortened))", systemImage: "checkmark"
    )
    .font(Design.Typography.caption)
    .foregroundStyle(.secondary)
  }
}

private struct MarginSwatch: View {
  var body: some View {
    Canvas { context, size in
      var stripes = Path()
      var offset = -size.height
      while offset < size.width {
        stripes.move(to: CGPoint(x: offset, y: size.height))
        stripes.addLine(to: CGPoint(x: offset + size.height, y: 0))
        offset += 4
      }
      context.stroke(stripes, with: .color(Design.Palette.marginHatch.opacity(1.4)), lineWidth: 1.5)
    }
    .frame(width: 14, height: 14)
    .background(Design.Palette.paper)
    .clipShape(RoundedRectangle(cornerRadius: 3))
    .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(.black.opacity(0.2), lineWidth: 0.5))
    .accessibilityHidden(true)
  }
}
