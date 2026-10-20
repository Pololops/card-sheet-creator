import Domain
import SwiftUI

/// A blank template on the page: dashed slots, the hatched 5 mm safety margin and the slot size.
/// None of this is ever printed.
struct TemplateCanvas: View {
  let geometry: SheetGeometry
  let scale: Double
  /// Number of files currently dragged over the page, if any.
  let droppingCount: Int?

  private static let hatchPeriodMm = 2.4
  private static let hatchLineMm = 0.7

  var body: some View {
    let layout = try? Domain.GridLayout.make(geometry)
    PaperSheet(scale: scale) {
      if droppingCount == nil { marginHatch }
      if let layout {
        ForEach(Array(layout.slots.enumerated()), id: \.offset) { index, slot in
          slotOutline(number: index + 1, frame: slot.scaled(scale))
        }
        if droppingCount == nil, let first = layout.slots.first { dimensionLabels(for: first.scaled(scale)) }
      }
    }
    .overlay {
      if droppingCount != nil {
        Rectangle().strokeBorder(Color.accentColor, lineWidth: 3).padding(-3)
      }
    }
    .overlay {
      if let droppingCount, let layout {
        DropPrompt(imageCount: droppingCount, capacity: layout.capacity)
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(accessibilityDescription(layout))
  }

  private var marginHatch: some View {
    Canvas { context, size in
      let margin = Page.safetyMargin.mm * scale
      var band = Path(CGRect(origin: .zero, size: size))
      band.addRect(
        CGRect(x: margin, y: margin, width: size.width - 2 * margin, height: size.height - 2 * margin))
      context.clip(to: band, style: FillStyle(eoFill: true))
      let period = Self.hatchPeriodMm * scale
      var stripes = Path()
      var offset = -size.height
      while offset < size.width {
        stripes.move(to: CGPoint(x: offset, y: size.height))
        stripes.addLine(to: CGPoint(x: offset + size.height, y: 0))
        offset += period
      }
      context.stroke(stripes, with: .color(Design.Palette.marginHatch), lineWidth: Self.hatchLineMm * scale)
    }
  }

  private func slotOutline(number: Int, frame: CGRect) -> some View {
    Rectangle()
      .fill(Color.accentColor.opacity(droppingCount == nil ? 0.04 : 0.1))
      .overlay(Rectangle().strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])))
      .overlay(alignment: .topLeading) {
        if droppingCount == nil {
          Text("\(number)").font(.system(size: 10)).foregroundStyle(.secondary).monospacedDigit().padding(5)
        }
      }
      .frame(width: frame.width, height: frame.height)
      .offset(x: frame.minX, y: frame.minY)
  }

  private func dimensionLabels(for frame: CGRect) -> some View {
    ZStack(alignment: .topLeading) {
      DimensionTag(text: "\(geometry.slot.width.formattedOneDecimal) mm")
        .frame(width: frame.width)
        .offset(x: frame.minX, y: frame.minY - 22)
      DimensionTag(text: "\(geometry.slot.height.formattedOneDecimal) mm")
        .rotationEffect(.degrees(-90))
        .frame(width: 22, height: frame.height)
        .offset(x: frame.minX - 26, y: frame.minY)
    }
  }

  private func accessibilityDescription(_ layout: Domain.GridLayout?) -> String {
    guard let layout else { return "Gabarit aux dimensions invalides" }
    return
      "Page A4, \(layout.capacity) cases de \(geometry.slot.width.formatted) par \(geometry.slot.height.formatted) millimètres"
  }
}

private struct DimensionTag: View {
  let text: String

  var body: some View {
    Text(text)
      .font(.system(size: 10, weight: .semibold))
      .monospacedDigit()
      .foregroundStyle(.white)
      .padding(.horizontal, 7)
      .padding(.vertical, 1)
      .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 6))
      .fixedSize()
  }
}

/// Centered on the page while files hover over it.
private struct DropPrompt: View {
  let imageCount: Int
  let capacity: Int

  var body: some View {
    let sheets = imageCount <= 1 ? 1 : Int((Double(imageCount) / Double(capacity)).rounded(.up))
    VStack(spacing: 4) {
      Text("Dépose pour créer \(sheets) planche\(sheets > 1 ? "s" : "")")
        .font(Design.Typography.figure)
      Text("\(imageCount) image\(imageCount > 1 ? "s" : "") · \(capacity) cartes par planche")
        .font(Design.Typography.callout)
        .foregroundStyle(.secondary)
        .monospacedDigit()
    }
    .padding(.horizontal, 22)
    .padding(.vertical, 16)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
    .shadow(color: .black.opacity(0.16), radius: 15, y: 10)
  }
}

extension Millimeters {
  /// Always one decimal, for dimension tags: "54,0", "85,6".
  var formattedOneDecimal: String { "\(tenths / 10),\(abs(tenths % 10))" }
}
