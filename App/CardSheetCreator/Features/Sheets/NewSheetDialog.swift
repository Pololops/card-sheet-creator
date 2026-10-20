import Domain
import SwiftUI
import UniformTypeIdentifiers

/// ⇧⌘N: pick a template, then the images to place.
struct NewSheetDialog: View {
  let templates: [Template]
  let preselected: Template?
  let onChooseImages: (Template) -> Void
  @Environment(\.dismiss) private var dismiss

  @State private var chosenID: UUID?

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      VStack(alignment: .leading, spacing: 4) {
        Text("Nouvelle planche").font(Design.Typography.dialogTitle)
        Text("Choisis le gabarit, puis les images à placer.").font(Design.Typography.body).foregroundStyle(
          .secondary)
      }
      templatePicker
      rules
      HStack(spacing: 10) {
        Spacer()
        Button("Annuler") { dismiss() }
          .keyboardShortcut(.cancelAction)
          .buttonStyle(.bordered)
          .buttonBorderShape(.capsule)
        Button("Choisir les images…") {
          guard let chosen else { return }
          dismiss()
          onChooseImages(chosen)
        }
        .keyboardShortcut(.defaultAction)
        .buttonStyle(.glassProminent)
        .disabled(chosen == nil)
      }
      .controlSize(.large)
    }
    .padding(24)
    .frame(width: 580)
    .onAppear { chosenID = preselected?.id ?? templates.first?.id }
  }

  private var chosen: Template? { templates.first { $0.id == chosenID } }

  private var templatePicker: some View {
    VStack(alignment: .leading, spacing: 10) {
      InspectorHeader(title: "Gabarit")
      ScrollView {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
          ForEach(templates) { template in
            TemplateChoice(template: template, isChosen: template.id == chosenID) { chosenID = template.id }
          }
        }
        .padding(3)
      }
      .frame(maxHeight: 360)
      .fixedSize(horizontal: false, vertical: templates.count <= 3)
      Text("Dernier gabarit utilisé présélectionné.").font(Design.Typography.caption).foregroundStyle(
        .secondary)
    }
  }

  private var rules: some View {
    let capacity = chosen.flatMap { try? Domain.GridLayout.make($0.geometry).capacity } ?? 0
    return VStack(alignment: .leading, spacing: 8) {
      Label {
        Text("**Une image** : dupliquée sur les \(capacity) cases.")
      } icon: {
        Image(systemName: "photo")
      }
      Label {
        Text(
          "**Plusieurs images** : une par case, dans l'ordre choisi. Au-delà de \(capacity), d'autres planches sont créées."
        )
      } icon: {
        Image(systemName: "square.grid.3x3")
      }
      Text(
        "PNG, JPEG, HEIC, TIFF ou PDF (1re page). Tu peux aussi glisser des images du Finder sur un gabarit."
      )
      .font(Design.Typography.caption)
      .foregroundStyle(.secondary)
    }
    .font(Design.Typography.body)
    .labelStyle(AlignedLabelStyle())
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 14))
  }
}

private struct TemplateChoice: View {
  let template: Template
  let isChosen: Bool
  let onChoose: () -> Void

  var body: some View {
    Button(action: onChoose) {
      VStack(spacing: 10) {
        TemplateThumbnail(geometry: template.geometry, size: Design.Metrics.pickerThumbnail)
        VStack(spacing: 2) {
          Text(template.name).font(Design.Typography.body.weight(.semibold)).lineLimit(1)
          Text(choiceSummary).font(Design.Typography.caption).foregroundStyle(.secondary).monospacedDigit()
        }
      }
      .padding(EdgeInsets(top: 14, leading: 10, bottom: 12, trailing: 10))
      .frame(maxWidth: .infinity)
      .background(.background, in: RoundedRectangle(cornerRadius: 16))
      .overlay(
        RoundedRectangle(cornerRadius: 16)
          .strokeBorder(
            isChosen ? Color.accentColor : Color.primary.opacity(0.1), lineWidth: isChosen ? 2 : 1)
      )
      .overlay(alignment: .topTrailing) {
        if isChosen {
          Image(systemName: "checkmark.circle.fill").font(.system(size: 18)).foregroundStyle(
            Color.accentColor
          )
          .padding(10)
        }
      }
      .contentShape(RoundedRectangle(cornerRadius: 16))
    }
    .buttonStyle(.plain)
    .accessibilityAddTraits(isChosen ? .isSelected : [])
  }

  private var choiceSummary: String {
    let capacity = (try? Domain.GridLayout.make(template.geometry).capacity) ?? 0
    return
      "\(capacity) cartes · \(template.geometry.slot.width.formatted) × \(template.geometry.slot.height.formatted)"
  }
}

private struct AlignedLabelStyle: LabelStyle {
  func makeBody(configuration: Configuration) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: 10) {
      configuration.icon.foregroundStyle(.secondary).frame(width: 16)
      configuration.title.fixedSize(horizontal: false, vertical: true)
    }
  }
}

extension UTType {
  /// Image formats a sheet accepts.
  static let cardImages: [UTType] = [.png, .jpeg, .heic, .heif, .tiff, .pdf]
}
