import CoreGraphics
import CoreText
import Domain
import Foundation

/// A test page to check a printer keeps exact sizes: a standard card outline where the first slot prints,
/// two 100 mm rulers, the 5 mm safety box, and edge marks showing how close to the edge it can print.
public enum CalibrationPage {
  private static let lineWidth = 0.2
  private static let rulerLength = 100
  private static let edgeMarkOffsets = 1...5

  @concurrent
  public static func renderPDF(to url: URL) async throws(RenderError) {
    var mediaBox = CGRect(x: 0, y: 0, width: Page.a4.width.points, height: Page.a4.height.points)
    guard let context = CGContext(url as CFURL, mediaBox: &mediaBox, nil) else { throw .cannotCreateDocument }
    context.beginPDFPage(nil)
    let scale = Millimeters(mm: 1).points
    context.translateBy(x: 0, y: Page.a4.height.points)
    context.scaleBy(x: scale, y: -scale)
    context.setStrokeColor(CGColor(gray: 0, alpha: 1))
    context.setLineWidth(lineWidth)

    drawCardOutline(in: context)
    drawSafetyBox(in: context)
    drawHorizontalRuler(in: context, x: 60, y: 150)
    drawVerticalRuler(in: context, x: 40, y: 165)
    drawEdgeMarks(in: context)
    drawCaption(in: context)

    context.endPDFPage()
    context.closePDF()
  }

  private static func drawCardOutline(in context: CGContext) {
    guard let slot = try? GridLayout.make(SheetGeometry(slot: .standardCard)).slots.first else { return }
    context.setLineWidth(0.5)
    context.stroke(CGRect(x: slot.x, y: slot.y, width: slot.width, height: slot.height))
    context.setLineWidth(lineWidth)
    drawText("54 × 85,6 mm", at: CGPoint(x: slot.x + 3, y: slot.y + 8), in: context)
  }

  private static func drawSafetyBox(in context: CGContext) {
    let margin = Page.safetyMargin.mm
    context.setLineDash(phase: 0, lengths: [1, 1])
    context.stroke(
      CGRect(
        x: margin, y: margin, width: Page.a4.width.mm - 2 * margin, height: Page.a4.height.mm - 2 * margin))
    context.setLineDash(phase: 0, lengths: [])
  }

  private static func drawHorizontalRuler(in context: CGContext, x: Double, y: Double) {
    for mm in 0...rulerLength {
      let tick = mm % 10 == 0 ? 4.0 : (mm % 5 == 0 ? 2.5 : 1.5)
      strokeLine(
        from: CGPoint(x: x + Double(mm), y: y), to: CGPoint(x: x + Double(mm), y: y - tick), in: context)
    }
    strokeLine(from: CGPoint(x: x, y: y), to: CGPoint(x: x + Double(rulerLength), y: y), in: context)
    drawText("100 mm", at: CGPoint(x: x + 42, y: y + 5), in: context)
  }

  private static func drawVerticalRuler(in context: CGContext, x: Double, y: Double) {
    for mm in 0...rulerLength {
      let tick = mm % 10 == 0 ? 4.0 : (mm % 5 == 0 ? 2.5 : 1.5)
      strokeLine(
        from: CGPoint(x: x, y: y + Double(mm)), to: CGPoint(x: x + tick, y: y + Double(mm)), in: context)
    }
    strokeLine(from: CGPoint(x: x, y: y), to: CGPoint(x: x, y: y + Double(rulerLength)), in: context)
    drawText("100 mm", at: CGPoint(x: x + 6, y: y + 52), in: context)
  }

  /// Short lines 1 to 5 mm from each edge: the first one that prints is the printer's real margin.
  private static func drawEdgeMarks(in context: CGContext) {
    let width = Page.a4.width.mm
    let height = Page.a4.height.mm
    for offset in edgeMarkOffsets.map(Double.init) {
      strokeLine(
        from: CGPoint(x: width / 2 - 4, y: offset), to: CGPoint(x: width / 2 + 4, y: offset), in: context)
      strokeLine(
        from: CGPoint(x: width / 2 - 4, y: height - offset),
        to: CGPoint(x: width / 2 + 4, y: height - offset),
        in: context)
      strokeLine(
        from: CGPoint(x: offset, y: height / 2 - 4), to: CGPoint(x: offset, y: height / 2 + 4), in: context)
      strokeLine(
        from: CGPoint(x: width - offset, y: height / 2 - 4),
        to: CGPoint(x: width - offset, y: height / 2 + 4),
        in: context)
    }
  }

  private static func drawCaption(in context: CGContext) {
    let lines = [
      "Page de calibration — Card Sheet Creator",
      "1. Le cadre de carte doit mesurer 54 × 85,6 mm, les règles 100 mm (± 0,5 mm).",
      "2. Au milieu de chaque bord, compte les traits imprimés (1 à 5 mm du bord) :",
      "    le premier trait visible donne la marge réelle de l'imprimante.",
    ]
    for (index, line) in lines.enumerated() {
      drawText(line, at: CGPoint(x: 90, y: 40 + Double(index) * 6), in: context)
    }
  }

  private static func strokeLine(from start: CGPoint, to end: CGPoint, in context: CGContext) {
    context.move(to: start)
    context.addLine(to: end)
    context.strokePath()
  }

  /// Text in the flipped millimetre space: un-flip locally so glyphs are upright.
  private static func drawText(_ text: String, at point: CGPoint, in context: CGContext) {
    let font = CTFontCreateWithName("Helvetica" as CFString, 3, nil)
    let attributed = NSAttributedString(
      string: text, attributes: [.init(kCTFontAttributeName as String): font])
    let line = CTLineCreateWithAttributedString(attributed)
    context.saveGState()
    context.translateBy(x: point.x, y: point.y)
    context.scaleBy(x: 1, y: -1)
    context.textPosition = .zero
    CTLineDraw(line, context)
    context.restoreGState()
  }
}
