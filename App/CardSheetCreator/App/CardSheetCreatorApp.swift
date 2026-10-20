import AppKit
import Rendering
import SwiftUI

@main
struct CardSheetCreatorApp: App {
  @NSApplicationDelegateAdaptor private var delegate: AppDelegate

  var body: some Scene {
    Window("Card Sheet Creator", id: "library") {
      RootView(environment: delegate.environment)
        .frame(minWidth: 1100, minHeight: 720)
    }
    .defaultSize(width: 1280, height: 800)
    .commands { AppCommands() }
  }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
  let environment = AppEnvironment()

  /// Waits for pending saves so quitting right after an edit never loses it.
  func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
    Task {
      try? await environment.model.flush()
      sender.reply(toApplicationShouldTerminate: true)
    }
    return .terminateLater
  }

  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

/// Actions the menu bar triggers on the focused window.
struct AppActions {
  var newTemplate: () -> Void
  var newSheet: () -> Void
  var print: (() -> Void)?
  var zoomToFit: () -> Void
  var zoomToRealSize: () -> Void
  var toggleInspector: () -> Void
  var printCalibrationPage: () -> Void
}

extension FocusedValues {
  @Entry var appActions: AppActions?
}

struct AppCommands: Commands {
  @FocusedValue(\.appActions) private var actions

  var body: some Commands {
    CommandGroup(replacing: .newItem) {
      Button("Nouveau gabarit") { actions?.newTemplate() }
        .keyboardShortcut("n")
      Button("Nouvelle planche…") { actions?.newSheet() }
        .keyboardShortcut("n", modifiers: [.command, .shift])
    }
    CommandGroup(replacing: .printItem) {
      Button("Imprimer…") { actions?.print?() }
        .keyboardShortcut("p")
        .disabled(actions?.print == nil)
    }
    CommandGroup(after: .toolbar) {
      Button("Ajuster à la fenêtre") { actions?.zoomToFit() }
        .keyboardShortcut("0")
      Button("Taille réelle") { actions?.zoomToRealSize() }
        .keyboardShortcut("1")
      Button("Afficher ou masquer l'inspecteur") { actions?.toggleInspector() }
        .keyboardShortcut("0", modifiers: [.command, .option])
    }
    CommandMenu("Calibration") {
      Button("Imprimer la page de calibration…") { actions?.printCalibrationPage() }
    }
  }
}
