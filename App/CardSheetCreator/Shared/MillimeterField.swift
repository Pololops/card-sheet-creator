import Domain
import SwiftUI

/// A labelled millimetre value: free typing plus − / + steps, clamped to `range`.
struct MillimeterField: View {
  let label: String
  @Binding var value: Millimeters
  let step: Millimeters
  let range: ClosedRange<Millimeters>
  var isChanged = false

  @State private var text = ""
  @FocusState private var isFocused: Bool

  var body: some View {
    HStack(spacing: 8) {
      Text(label)
        .font(Design.Typography.body)
        .frame(maxWidth: .infinity, alignment: .leading)
      TextField(label, text: $text)
        .labelsHidden()
        .textFieldStyle(.roundedBorder)
        .multilineTextAlignment(.trailing)
        .monospacedDigit()
        .frame(width: Design.Metrics.fieldWidth)
        .focused($isFocused)
        .overlay {
          if isChanged {
            RoundedRectangle(cornerRadius: 6).strokeBorder(Design.Palette.changedField, lineWidth: 1)
          }
        }
        .onSubmit(commitText)
        .onChange(of: isFocused) { _, focused in if !focused { commitText() } }
        .accessibilityLabel("\(label), en millimètres")
      Text("mm")
        .font(Design.Typography.callout)
        .foregroundStyle(.secondary)
        .frame(width: 22, alignment: .leading)
      HStack(spacing: 0) {
        stepButton(
          systemImage: "minus", delta: -step.tenths,
          label: "Réduire \(label.lowercased()) de \(step.formatted) mm")
        stepButton(
          systemImage: "plus", delta: step.tenths,
          label: "Augmenter \(label.lowercased()) de \(step.formatted) mm")
      }
      .background(.quaternary.opacity(0.6), in: Capsule())
    }
    .onAppear { text = value.formatted }
    .onChange(of: value) { _, newValue in text = newValue.formatted }
  }

  private func stepButton(systemImage: String, delta: Int, label: String) -> some View {
    Button {
      value = clamped(Millimeters(tenths: value.tenths + delta))
    } label: {
      Image(systemName: systemImage)
        .font(.system(size: 10, weight: .bold))
        .frame(width: 28, height: 28)
        .contentShape(Capsule())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(label)
  }

  private func commitText() {
    let normalized = text.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)
    guard let number = Double(normalized) else {
      text = value.formatted
      return
    }
    value = clamped(Millimeters(mm: number))
    text = value.formatted
  }

  private func clamped(_ candidate: Millimeters) -> Millimeters {
    min(max(candidate, range.lowerBound), range.upperBound)
  }
}
