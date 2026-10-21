import SwiftUI

/// Counts the ink's drying down. The view owns the clock: when time is up it tells the model, which
/// never sleeps, and says so to VoiceOver.
struct DryingRing: View {
  let model: ColorCalibrationModel
  let diameter: CGFloat

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    Group {
      if model.isInkWet, let end = model.dryingEndsAt {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
          ring(remaining: max(0, end.timeIntervalSince(timeline.date)))
        }
      } else {
        ring(remaining: 0)
      }
    }
    .task(id: model.dryingEndsAt) { await waitUntilDry() }
  }

  private func ring(remaining: TimeInterval) -> some View {
    let isDry = remaining == 0
    let progress = 1 - remaining / ColorCalibrationModel.dryingDuration
    return ZStack {
      Circle().stroke(Color.secondary.opacity(0.18), lineWidth: 8)
      Circle()
        .trim(from: 0, to: progress)
        .stroke(
          isDry ? Design.Palette.success : Color.accentColor,
          style: StrokeStyle(lineWidth: 8, lineCap: .round)
        )
        .rotationEffect(.degrees(-90))
        .animation(reduceMotion ? nil : .linear(duration: 1), value: progress)
      VStack(spacing: 0) {
        Text(isDry ? "Prêt" : "\(Int(remaining.rounded(.up)))")
          .font(Design.Typography.stepHero)
          .monospacedDigit()
        if !isDry { Text("secondes").font(Design.Typography.caption).foregroundStyle(.secondary) }
      }
    }
    .padding(4)
    .frame(width: diameter, height: diameter)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Séchage de l'encre")
    .accessibilityValue(isDry ? "Terminé" : "\(Int(remaining.rounded(.up))) secondes restantes")
    .accessibilityAddTraits(.updatesFrequently)
  }

  private func waitUntilDry() async {
    guard model.isInkWet else { return }
    while model.isInkWet, let end = model.dryingEndsAt, !Task.isCancelled {
      // The floor keeps a clock that wakes a hair early from spinning.
      try? await Task.sleep(for: .seconds(max(end.timeIntervalSinceNow, 0.1)))
      if !Task.isCancelled { model.finishDrying() }
    }
    guard !model.isInkWet, !Task.isCancelled else { return }
    AccessibilityNotification.Announcement("L'encre est sèche, tu peux comparer.").post()
  }
}
