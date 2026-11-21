import AppKit
import Domain
import SwiftUI

// Why: see docs/adr/0010-ui-direction.md (HIG and Liquid Glass: the print dialog's construction, native
// controls) and docs/adr/0002-native-swift-swiftui.md (Swift 6 and SwiftUI, targeting macOS 26).
/// What the updater tells the user: an answer to the menu check, an update on offer, or its progress.
struct UpdateSheet: View {
  let controller: UpdateController

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      HStack(alignment: .top, spacing: 16) {
        Image(nsImage: NSApp.applicationIconImage)
          .resizable()
          .frame(width: Design.Metrics.updateAppIcon, height: Design.Metrics.updateAppIcon)
          .accessibilityHidden(true)
        VStack(alignment: .leading, spacing: 6) { message }
      }
      footer
    }
    .padding(24)
    .frame(width: Design.Metrics.updateDialogWidth)
  }

  @ViewBuilder
  private var message: some View {
    switch controller.phase {
    case .upToDate:
      title("Card Sheet Creator est à jour")
      detail("La version \(controller.installedVersion.description) est la plus récente.")
    case .available(let update):
      offer(version: update.version)
    case .downloading:
      offer(version: controller.offeredVersion)
    case .installing:
      installation(of: controller.offeredVersion)
    case .failed(.network):
      title("Impossible de rechercher les mises à jour")
      Text("Vérifiez votre connexion à Internet, puis réessayez.").font(Design.Typography.body)
    case .failed(.notAuthentic):
      title("La mise à jour n’a pas été installée")
      detail("Le fichier téléchargé n’est pas authentique. Votre version actuelle n’a pas été modifiée.")
    case .failed(.location):
      title("Installation impossible depuis cet emplacement")
      detail(
        "Déplacez Card Sheet Creator dans le dossier Applications, ouvrez-le, puis relancez la mise à jour.")
    case .failed(.installFailed):
      title("La mise à jour n’a pas été installée")
      detail("Votre version actuelle n’a pas été modifiée. Réessayez plus tard.")
    case nil:
      EmptyView()
    }
  }

  @ViewBuilder
  private var footer: some View {
    switch controller.phase {
    case .downloading(let received, let total):
      DownloadFooter(received: received, total: total, cancel: controller.cancel)
    case .installing:
      InstallFooter()
    case .upToDate, .available, .failed, nil:
      HStack(spacing: 10) {
        Spacer()
        buttons
      }
      .controlSize(.large)
    }
  }

  @ViewBuilder
  private var buttons: some View {
    switch controller.phase {
    case .upToDate, .failed(.notAuthentic), .failed(.installFailed):
      Button("OK", action: controller.dismiss).primaryAction()
    case .available:
      Button("Plus tard", action: controller.dismiss)
        .keyboardShortcut(.cancelAction)
        .secondaryAction()
      Button("Redémarrer et installer") { Task { await controller.install() } }
        .primaryAction()
    case .failed(.network):
      dismissButton
      Button("Réessayer") { Task { await controller.checkFromMenu() } }
        .primaryAction()
    case .failed(.location):
      dismissButton
      Button("Afficher dans le Finder", action: controller.revealApp).primaryAction()
    case .downloading, .installing, nil:
      EmptyView()
    }
  }

  private var dismissButton: some View {
    Button("OK", action: controller.dismiss)
      .keyboardShortcut(.cancelAction)
      .secondaryAction()
  }

  @ViewBuilder
  private func offer(version: SemanticVersion?) -> some View {
    title("Une nouvelle version est disponible")
    if let version {
      VersionChips(installed: controller.installedVersion, offered: version)
    }
  }

  @ViewBuilder
  private func installation(of version: SemanticVersion?) -> some View {
    if let version {
      title("Installation de la version \(version.description)")
    }
    detail("Card Sheet Creator va redémarrer.")
  }

  private func title(_ text: LocalizedStringKey) -> some View {
    Text(text).font(Design.Typography.dialogTitle)
  }

  private func detail(_ text: LocalizedStringKey) -> some View {
    Text(text).font(Design.Typography.body).foregroundStyle(.secondary)
  }
}

/// The bar and `Annuler` share a centre line; the caption sits below that pair, outside the centring.
private struct DownloadFooter: View {
  let received: Int64
  let total: Int64
  let cancel: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 5) {
      HStack(alignment: .center, spacing: 12) {
        ProgressView(value: Double(received), total: Double(total))
          .accessibilityLabel("Téléchargement")
        Button("Annuler", action: cancel)
          .keyboardShortcut(.cancelAction)
          .secondaryAction()
          .controlSize(.large)
      }
      Text(UpdateController.downloadLabel(received: received, total: total))
        .font(Design.Typography.caption).foregroundStyle(.secondary)
    }
  }
}

/// No button: from here the app is about to quit, and there is nothing left to cancel.
private struct InstallFooter: View {
  var body: some View {
    ProgressView().progressViewStyle(.linear)
      .accessibilityLabel("Installation")
  }
}

/// The installed version, an arrow, the one on offer: read as a single phrase by VoiceOver.
private struct VersionChips: View {
  let installed: SemanticVersion
  let offered: SemanticVersion

  var body: some View {
    HStack(spacing: 6) {
      Text("Version \(installed.description)")
        .padding(.horizontal, 10).padding(.vertical, 3)
        .background(.quaternary, in: Capsule())
      Image(systemName: "arrow.right").foregroundStyle(.secondary)
      Text("Nouvelle version \(offered.description)")
        .fontWeight(.semibold).foregroundStyle(Color.accentColor)
        .padding(.horizontal, 10).padding(.vertical, 3)
        .background(Design.Palette.newVersionChip, in: Capsule())
    }
    .font(Design.Typography.callout)
    .lineLimit(1)
    .padding(.top, 4)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Version \(installed.description), nouvelle version \(offered.description)")
  }
}
