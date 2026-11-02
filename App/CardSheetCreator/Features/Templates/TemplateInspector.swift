import Domain
import SwiftUI

struct TemplateInspector: View {
  @Bindable var model: LibraryModel
  let template: Template

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      Text("Gabarit").font(Design.Typography.body.weight(.bold))
      NameField(name: template.name) { model.rename(.template(template.id), to: $0) }
      GeometryFields(geometry: geometryBinding).id(template.id)
      CapacityCard(geometry: displayedGeometry)
      pageSection
      Spacer(minLength: 0)
      SavedFooter(date: template.updatedAt)
    }
    .padding(16)
  }

  /// The pinch's preview while one is under way, so the capacity follows the fingers.
  private var displayedGeometry: SheetGeometry {
    model.geometry(ofTemplate: template.id) ?? template.geometry
  }

  private var geometryBinding: Binding<SheetGeometry> {
    Binding(
      get: { displayedGeometry },
      set: { model.editGeometry(ofTemplate: template.id, to: $0) })
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
