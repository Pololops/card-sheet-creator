import SwiftUI

/// "Réglage des couleurs": a fixed-size window walking through the five steps of the calibration.
struct ColorCalibrationWindow: View {
  let environment: AppEnvironment
  @State private var model: ColorCalibrationModel?
  @Environment(\.openWindow) private var openWindow
  @Environment(\.dismissWindow) private var dismissWindow
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  private var route: ColorCalibrationRoute { environment.calibrationRoute }

  var body: some View {
    Group {
      if let model { steps(of: model) }
    }
    .frame(width: Design.Metrics.calibrationWindow.width, height: Design.Metrics.calibrationWindow.height)
    // A fresh launch id restarts the flow, even when the window was already open.
    .task(id: route.launch.id) {
      model = ColorCalibrationModel(
        launch: route.launch, library: environment.model, printService: environment.printService)
    }
    .onAppear { route.isWindowOpen = true }
    .onDisappear { route.isWindowOpen = false }
  }

  private func steps(of model: ColorCalibrationModel) -> some View {
    VStack(spacing: 0) {
      StepHeader(current: model.step)
      Divider()
      stepContent(of: model)
        .id(model.step)
        .transition(stepTransition)
    }
    .animation(reduceMotion ? .easeOut(duration: 0.2) : .smooth(duration: 0.32), value: model.step)
  }

  /// Reduce Motion keeps the change of step but drops the slide.
  private var stepTransition: AnyTransition {
    reduceMotion
      ? .opacity
      : .asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity)
  }

  @ViewBuilder
  private func stepContent(of model: ColorCalibrationModel) -> some View {
    switch model.step {
    case .prepare: PrepareStep(model: model)
    case .print: PrintStep(model: model)
    case .compare: CompareStep(model: model)
    case .verify: VerifyStep(model: model)
    case .done: DoneStep(model: model) { finish(model, printingAfterwards: $0) }
    }
  }

  /// The library window opens first: dismissing the last window would quit the app before it could
  /// receive the handoff.
  private func finish(_ model: ColorCalibrationModel, printingAfterwards: Bool) {
    openWindow(id: WindowID.library)
    if printingAfterwards { route.handoff = model.handoff }
    dismissWindow(id: WindowID.colorCalibration)
  }
}
