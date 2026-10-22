import SwiftUI

/// The bottom bar of a step: secondary actions on the left, the single primary action on the right.
struct StepFooter<Leading: View, Primary: View>: View {
  @ViewBuilder let leading: Leading
  @ViewBuilder let primary: Primary

  var body: some View {
    VStack(spacing: 0) {
      Divider()
      HStack(spacing: 10) {
        leading
        Spacer()
        primary
      }
      .controlSize(.large)
      .padding(.horizontal, 24)
      .padding(.vertical, 14)
    }
  }
}

extension View {
  func secondaryAction() -> some View {
    buttonStyle(.bordered).buttonBorderShape(.capsule)
  }

  /// Enter always triggers the step's one main action.
  func primaryAction() -> some View {
    buttonStyle(.glassProminent).keyboardShortcut(.defaultAction)
  }
}
