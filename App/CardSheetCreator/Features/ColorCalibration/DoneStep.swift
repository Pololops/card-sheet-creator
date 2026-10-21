import SwiftUI

/// Step 5: what the printer does wrong in plain words, and what the app now compensates.
struct DoneStep: View {
  let model: ColorCalibrationModel
  let onFinish: (_ printingAfterwards: Bool) -> Void

  var body: some View {
    VStack(spacing: 0) {
      HStack(alignment: .top, spacing: 36) {
        summary.frame(width: 330, alignment: .leading)
        readings.frame(maxWidth: .infinity, alignment: .leading)
      }
      .padding(.horizontal, 32)
      .padding(.vertical, 24)
      .frame(maxHeight: .infinity, alignment: .center)
      footer
    }
  }

  private var footer: some View {
    StepFooter {
      if model.canPrintAfterwards { Button("Terminer") { onFinish(false) }.secondaryAction() }
    } primary: {
      if model.canPrintAfterwards {
        Button("Terminer et imprimer") { onFinish(true) }.primaryAction()
      } else {
        Button("Terminer") { onFinish(false) }.primaryAction()
      }
    }
  }

  private var summary: some View {
    VStack(alignment: .leading, spacing: 14) {
      Image(systemName: "checkmark.seal")
        .font(.system(size: 34))
        .foregroundStyle(Design.Palette.onAccent)
        .frame(width: 64, height: 64)
        .background(Color.accentColor, in: Circle())
        .accessibilityHidden(true)
      Text("C'est réglé").font(Design.Typography.stepHero)
      if let diagnosis = model.diagnosis {
        Text(diagnosis)
          .font(Design.Typography.lead)
          .fixedSize(horizontal: false, vertical: true)
      }
      Label("Tu peux réactiver Night Shift et True Tone.", systemImage: "moon")
        .font(Design.Typography.callout)
        .foregroundStyle(.secondary)
    }
  }

  private var readings: some View {
    let readings = CorrectionReading.readings(
      for: model.result ?? .neutral, isColorPrinter: model.isColorPrinter)
    return VStack(alignment: .leading, spacing: 14) {
      Text("Ce qu'on compense").font(Design.Typography.body.weight(.semibold))
      ForEach(readings) { CorrectionGauge(reading: $0) }
      Text(footnote)
        .font(Design.Typography.callout)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  private var footnote: String {
    let printer = model.printerName.map { "sur \($0)" } ?? "sur cette imprimante"
    return
      "La correction s'applique à chaque impression \(printer). Tu peux la couper dans la fenêtre d'impression."
  }
}

private struct CorrectionGauge: View {
  let reading: CorrectionReading

  var body: some View {
    Gauge(value: Double(reading.steps), in: -Double(reading.limit)...Double(reading.limit)) {
      Text(reading.name).font(Design.Typography.callout.weight(.semibold))
    } currentValueLabel: {
      Text(reading.value).foregroundStyle(.secondary)
    } minimumValueLabel: {
      Text(reading.lowEnd)
    } maximumValueLabel: {
      Text(reading.highEnd)
    }
    .gaugeStyle(.linearCapacity)
    .font(Design.Typography.caption)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("\(reading.name) : \(reading.value)")
  }
}
