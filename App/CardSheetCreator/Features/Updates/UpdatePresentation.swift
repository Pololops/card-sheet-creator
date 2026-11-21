import SwiftUI

extension View {
  /// Shows the update sheet once nothing else is presented. `isBlocked` is true while another sheet or alert is up.
  func updatePresentation(_ controller: UpdateController, isBlocked: Bool) -> some View {
    modifier(UpdatePresentation(controller: controller, isBlocked: isBlocked))
  }
}

private struct UpdatePresentation: ViewModifier {
  let controller: UpdateController
  let isBlocked: Bool
  /// Once shown, the sheet stays up until the controller is done with it: a sheet or alert opened
  /// meanwhile must not make it vanish, or the offer would be lost.
  @State private var isShown = false

  func body(content: Content) -> some View {
    content
      .sheet(isPresented: sheetBinding) {
        UpdateSheet(controller: controller)
          .interactiveDismissDisabled(controller.isBusy)
      }
      // `initial` catches an answer that arrived before this window was on screen.
      .onChange(of: controller.isPresenting, initial: true) { syncPresentation() }
      .onChange(of: isBlocked) { syncPresentation() }
  }

  private var sheetBinding: Binding<Bool> {
    Binding(get: { isShown }, set: { if !$0 { controller.dismiss() } })
  }

  private func syncPresentation() {
    if !controller.isPresenting {
      isShown = false
    } else if !isBlocked {
      isShown = true
    }
  }
}
