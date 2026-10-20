import Domain
import SwiftUI

/// Floating glass capsule under the page: Fit · Real size · − % +.
struct ZoomControl: View {
  @Bindable var zoom: CanvasZoom
  let available: CGSize

  var body: some View {
    HStack(spacing: 4) {
      segment("Ajuster", isOn: zoom.mode == .fit) { zoom.mode = .fit }
      segment("Taille réelle", isOn: zoom.mode == .realSize) { zoom.mode = .realSize }
        .help(zoom.realSizeScale == nil ? "Approximatif : cet écran n'indique pas sa taille physique" : "")
      Divider().frame(height: 18).padding(.horizontal, 4)
      iconButton("minus", label: "Zoom arrière") { zoom.zoom(by: -CanvasZoom.step, from: available) }
      Text("\(zoom.percent(fitting: available)) %")
        .font(Design.Typography.callout.weight(.semibold))
        .monospacedDigit()
        .frame(minWidth: 44)
      iconButton("plus", label: "Zoom avant") { zoom.zoom(by: CanvasZoom.step, from: available) }
    }
    .padding(4)
    .glassEffect(.regular, in: .capsule)
  }

  private func segment(_ title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Text(title)
        .font(Design.Typography.callout.weight(isOn ? .semibold : .medium))
        .padding(.horizontal, 14)
        .frame(height: 32)
        .background {
          if isOn { Capsule().fill(.background).shadow(color: .black.opacity(0.14), radius: 1.5, y: 1) }
        }
        .contentShape(Capsule())
    }
    .buttonStyle(.plain)
    .accessibilityAddTraits(isOn ? .isSelected : [])
  }

  private func iconButton(_ systemImage: String, label: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Image(systemName: systemImage)
        .font(.system(size: 12, weight: .semibold))
        .frame(width: 32, height: 32)
        .contentShape(Circle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(label)
  }
}

/// The white A4 page lying on the canvas, `scale` points per millimetre.
struct PaperSheet<Content: View>: View {
  let scale: Double
  @ViewBuilder var content: Content

  var body: some View {
    ZStack(alignment: .topLeading) {
      Design.Palette.paper
      content
    }
    .frame(width: Page.a4.width.mm * scale, height: Page.a4.height.mm * scale)
    .shadow(color: .black.opacity(0.1), radius: 1.5, y: 1)
    .shadow(color: .black.opacity(0.16), radius: 22, y: 18)
  }
}

/// A slot rectangle placed on the page, in points.
extension MMRect {
  func scaled(_ scale: Double) -> CGRect {
    CGRect(x: x * scale, y: y * scale, width: width * scale, height: height * scale)
  }
}

/// Persistent glass notice floating at the top of the canvas (import summary, save failure).
struct CanvasBanner<Actions: View>: View {
  let systemImage: String
  let message: String
  var tint: Color = .primary
  @ViewBuilder var actions: Actions

  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: systemImage).foregroundStyle(tint)
      Text(message).font(Design.Typography.body)
      actions
    }
    .padding(.leading, 16)
    .padding(.trailing, 6)
    .frame(minHeight: 40)
    .glassEffect(.regular, in: .capsule)
    .accessibilityElement(children: .combine)
  }
}

/// Section title in the inspector: 11 pt bold, secondary.
struct InspectorHeader: View {
  let title: String

  var body: some View {
    Text(title)
      .font(Design.Typography.caption.weight(.bold))
      .foregroundStyle(.secondary)
      .accessibilityAddTraits(.isHeader)
  }
}

/// Label / value row in the inspector.
struct InspectorRow: View {
  let label: String
  let value: String

  var body: some View {
    HStack {
      Text(label)
      Spacer()
      Text(value).foregroundStyle(.secondary).monospacedDigit()
    }
    .font(Design.Typography.body)
  }
}
