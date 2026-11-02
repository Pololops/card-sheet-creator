import Domain
import SwiftUI

/// A labelled millimetre value: free typing plus − / + steps, clamped to `range`.
struct MillimeterField: View {
  let label: String
  @Binding var value: Millimeters
  let step: Millimeters
  let range: ClosedRange<Millimeters>
  var isChanged = false
  /// Tells when a − / + button goes down and up, so a held step can be one undo step.
  var onPressChange: (Bool) -> Void = { _ in }

  /// Gap between the elements of a row.
  static let spacing: CGFloat = 8
  static let unitWidth: CGFloat = 22
  /// Side of a step button: the tallest element of the row, so also the row height.
  static let stepSide: CGFloat = 28
  /// Width from the leading edge of the text field to the trailing edge of the row.
  static let fieldTrailingSpan = Design.Metrics.fieldWidth + spacing + unitWidth + spacing + 2 * stepSide

  @State private var text = ""
  @FocusState private var isFocused: Bool

  var body: some View {
    HStack(spacing: Self.spacing) {
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
        .frame(width: Self.unitWidth, alignment: .leading)
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
      step(by: delta)
    } label: {
      Image(systemName: systemImage)
        .font(.system(size: 10, weight: .bold))
        .frame(width: Self.stepSide, height: Self.stepSide)
        .contentShape(Capsule())
    }
    .buttonStyle(StepButtonStyle(onPressChange: onPressChange))
    .buttonRepeatBehavior(.enabled)
    .accessibilityLabel(label)
  }

  private func step(by delta: Int) {
    value = clamped(Millimeters(tenths: value.tenths + delta))
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

/// Looks like `.plain`, and reports the press: `Button` exposes `isPressed` to a style only.
private struct StepButtonStyle: ButtonStyle {
  private static let pressedOpacity = 0.55

  let onPressChange: (Bool) -> Void

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .opacity(configuration.isPressed ? Self.pressedOpacity : 1)
      .onChange(of: configuration.isPressed) { _, isPressed in onPressChange(isPressed) }
  }
}
