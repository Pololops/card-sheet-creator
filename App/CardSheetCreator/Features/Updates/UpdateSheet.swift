import AppKit
import Domain
import SwiftUI

// Why: see docs/adr/0010-ui-direction.md (HIG and Liquid Glass: the print dialog's construction, native
// controls) and docs/adr/0002-native-swift-swiftui.md (Swift 6 and SwiftUI, targeting macOS 26).
/// What the updater tells the user: an answer to the menu check, or an update on offer.
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
      Text("La version \(controller.installedVersion.description) est la plus récente.")
        .font(Design.Typography.body).foregroundStyle(.secondary)
    case .available(let update):
      title("Une nouvelle version est disponible")
      VersionChips(installed: controller.installedVersion, offered: update.version)
    case .failed(.network):
      title("Impossible de rechercher les mises à jour")
      Text("Vérifiez votre connexion à Internet, puis réessayez.").font(Design.Typography.body)
    default:
      EmptyView()
    }
  }

  @ViewBuilder
  private var footer: some View {
    HStack(spacing: 10) {
      Spacer()
      switch controller.phase {
      case .upToDate:
        Button("OK", action: controller.dismiss)
          .keyboardShortcut(.defaultAction)
          .buttonStyle(.glassProminent)
      case .available:
        Button("Plus tard", action: controller.dismiss)
          .keyboardShortcut(.cancelAction)
          .buttonStyle(.bordered)
          .buttonBorderShape(.capsule)
      case .failed(.network):
        Button("OK", action: controller.dismiss)
          .keyboardShortcut(.cancelAction)
          .buttonStyle(.bordered)
          .buttonBorderShape(.capsule)
        Button("Réessayer") { Task { await controller.checkFromMenu() } }
          .keyboardShortcut(.defaultAction)
          .buttonStyle(.glassProminent)
      default:
        EmptyView()
      }
    }
    .controlSize(.large)
  }

  private func title(_ text: LocalizedStringKey) -> some View {
    Text(text).font(Design.Typography.dialogTitle)
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
