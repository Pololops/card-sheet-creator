import Domain
import SwiftUI

/// Inspector while a sheet's dimensions are being changed; nothing is saved before "Valider".
struct ResizeInspector: View {
  @Bindable var draft: ResizeDraft

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      Text("Dimensions de la planche").font(Design.Typography.body.weight(.bold))
      GeometryFields(geometry: $draft.geometry, original: draft.sheet.geometry)
      VStack(alignment: .leading, spacing: 6) {
        CapacityCard(geometry: draft.geometry, previousCapacity: draft.previousCapacity)
        if draft.movedCount > 0, let capacity = draft.layout?.capacity {
          Text(
            "Les \(capacity) premières images restent ici, dans l'ordre. Les \(draft.movedCount) suivantes iront sur « \(draft.sheet.name) (suite) »."
          )
          .font(Design.Typography.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
        }
      }
      Text("Le cadrage de chaque image est conservé. Rien n'est enregistré avant « Valider ».")
        .font(Design.Typography.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
      Spacer(minLength: 0)
      Text("Échap annule · ↩ valide").font(Design.Typography.caption).foregroundStyle(.secondary)
    }
    .padding(16)
  }
}

/// Floating glass bar under the page: overflow warning, Annuler, Valider.
struct ResizeBar: View {
  let draft: ResizeDraft
  let images: ImageCache
  let onCancel: () -> Void
  let onValidate: () -> Void

  var body: some View {
    HStack(spacing: 12) {
      if draft.movedCount > 0 {
        Image(systemName: "exclamationmark.triangle").foregroundStyle(Design.Palette.warning)
        (Text("\(draft.movedCount) image\(draft.movedCount > 1 ? "s" : "")").fontWeight(.semibold)
          + Text(" passer\(draft.movedCount > 1 ? "ont" : "a") sur une nouvelle planche"))
          .font(Design.Typography.body)
      } else {
        Text(
          draft.hasChanges ? "Aucune image ne change de planche" : "Modifie les dimensions dans l'inspecteur"
        )
        .font(Design.Typography.body)
        .foregroundStyle(.secondary)
      }
      Spacer(minLength: 8)
      Button("Annuler", action: onCancel)
        .keyboardShortcut(.cancelAction)
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .controlSize(.large)
      Button("Valider", action: onValidate)
        .keyboardShortcut(.defaultAction)
        .buttonStyle(.glassProminent)
        .controlSize(.large)
        .disabled(!draft.hasChanges || draft.layout == nil)
    }
    .padding(.leading, 18)
    .padding(.trailing, 7)
    .frame(width: 664, height: 52)
    .glassEffect(.regular, in: .capsule)
  }
}

/// Shown over the page while a resize draft is open.
struct DraftBadge: View {
  var body: some View {
    Text("Brouillon · non enregistré")
      .font(Design.Typography.caption.weight(.semibold))
      .foregroundStyle(Design.Palette.draftText)
      .padding(.horizontal, 10)
      .padding(.vertical, 2)
      .background(Design.Palette.draftBackground, in: Capsule())
      .overlay(Capsule().strokeBorder(Design.Palette.draftText.opacity(0.2)))
  }
}

/// After validation: keep the new size as a blank template, or only change this sheet.
struct TemplateOfferDialog: View {
  let offer: TemplateOffer
  let onAccept: (String) -> Void
  let onDecline: () -> Void

  @State private var name = ""

  var body: some View {
    VStack(spacing: 14) {
      Image(nsImage: NSApp.applicationIconImage)
        .resizable()
        .frame(width: 60, height: 60)
        .accessibilityHidden(true)
      VStack(spacing: 6) {
        Text("Créer aussi un gabarit vierge ?").font(Design.Typography.figure)
        Text(
          "« \(offer.sheetName) » passe en cases de \(offer.geometry.slot.width.formatted) × \(offer.geometry.slot.height.formatted) mm. Enregistre ces dimensions comme gabarit pour tes prochaines planches."
        )
        .font(Design.Typography.callout)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
      }
      VStack(alignment: .leading, spacing: 6) {
        Text("Nom du gabarit").font(Design.Typography.caption.weight(.semibold)).foregroundStyle(.secondary)
        TextField("Nom du gabarit", text: $name).labelsHidden().textFieldStyle(.roundedBorder)
      }
      if let overflowName = offer.overflowSheetName {
        Label(
          "Planche « \(overflowName) » créée avec \(offer.movedCount) image\(offer.movedCount > 1 ? "s" : "").",
          systemImage: "checkmark"
        )
        .font(Design.Typography.callout)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
      }
      HStack(spacing: 8) {
        Button("Seulement cette planche", action: onDecline)
          .keyboardShortcut(.cancelAction)
          .buttonStyle(.bordered)
          .buttonBorderShape(.capsule)
          .frame(maxWidth: .infinity)
        Button("Créer le gabarit") { onAccept(name) }
          .keyboardShortcut(.defaultAction)
          .buttonStyle(.glassProminent)
          .frame(maxWidth: .infinity)
      }
      .controlSize(.large)
    }
    .padding(EdgeInsets(top: 22, leading: 20, bottom: 18, trailing: 20))
    .frame(width: 340)
    .onAppear { name = offer.suggestedName }
  }
}
