import CoreGraphics
import CoreText
import Domain
import Foundation

/// The pages of the colour calibration: a chart of patches printed around the current correction, and a
/// verification page of references showing the result. Everything is drawn in millimetres, y downward.
public enum ColorChart {
  private static let titleSize = 5.0
  private static let bodySize = 3.0
  private static let titleBaseline = 15.0
  private static let firstLineBaseline = 22.0
  private static let secondLineBaseline = 27.0
  private static let textLeft = 12.0

  /// Patch `k` of a round is printed with `centre` plus the offset of `k`, so the chart brackets the
  /// printer's current setting without marking which patch that is.
  @concurrent
  public static func renderPDF(
    to url: URL, centre: ColorCorrection, rounds: [CalibrationRound]
  ) async throws(RenderError) {
    try writePage(to: url) { context throws(RenderError) in
      drawHeader(
        "Mire de réglage des couleurs — Card Sheet Creator",
        "Laisse sécher l'encre une minute avant de comparer.",
        "Dans chaque rangée, repère la pastille la plus proche de l'écran.", in: context)
      for section in ChartLayout.sectionTops(for: rounds) {
        drawText(section.round.title, at: ChartLayout.sectionTitlePoint(top: section.top), in: context)
      }
      try drawPatches(rounds: rounds, centre: centre, in: context)
    }
  }

  /// One reference per round, corrected with `correction`: each must look like its screen reference.
  @concurrent
  public static func renderVerificationPDF(
    to url: URL, correction: ColorCorrection, rounds: [CalibrationRound]
  ) async throws(RenderError) {
    try writePage(to: url) { context throws(RenderError) in
      drawHeader(
        "Vérification des couleurs — Card Sheet Creator",
        "Laisse sécher l'encre une minute avant de comparer.",
        "Chaque pastille doit ressembler à sa référence sur l'écran.", in: context)
      for (round, rect) in ChartLayout.verificationRects(for: rounds) {
        let reference = try referenceImage(for: round)
        try draw(reference, correctedBy: correction, in: rect, context: context)
        drawText(round.title, at: ChartLayout.captionPoint(below: rect), centred: true, in: context)
      }
    }
  }

  /// The round's pattern as it should look on screen, uncorrected: what the paper is compared with.
  public static func referenceImage(for round: CalibrationRound) throws(RenderError) -> CGImage {
    try ChartPatch.image(for: round, side: ChartLayout.referenceSide)
  }

  private static func drawPatches(
    rounds: [CalibrationRound], centre: ColorCorrection, in context: CGContext
  ) throws(RenderError) {
    var images: [CalibrationRound: CGImage] = [:]
    for round in rounds {
      images[round] = try ChartPatch.image(for: round, side: ChartLayout.patchSide)
    }
    for placed in ChartLayout.patches(for: rounds) {
      guard let image = images[placed.round] else { continue }
      try draw(image, correctedBy: centre.adding(placed.variant.offset), in: placed.rect, context: context)
      let letter = String(placed.variant.letter)
      drawText(letter, at: ChartLayout.letterPoint(below: placed.rect), centred: true, in: context)
    }
  }

  private static func draw(
    _ image: CGImage, correctedBy correction: ColorCorrection, in rect: CGRect, context: CGContext
  ) throws(RenderError) {
    let printed = correction.isNeutral ? image : try ColorCorrector(correction: correction).apply(to: image)
    Artwork.bitmap(printed).draw(in: rect, context: context)
  }

  private static func drawHeader(
    _ title: String, _ firstLine: String, _ secondLine: String, in context: CGContext
  ) {
    drawText(title, at: CGPoint(x: textLeft, y: titleBaseline), size: titleSize, in: context)
    drawText(firstLine, at: CGPoint(x: textLeft, y: firstLineBaseline), in: context)
    drawText(secondLine, at: CGPoint(x: textLeft, y: secondLineBaseline), in: context)
  }

  /// A one-page A4 PDF whose user space is millimetres with y growing downward.
  private static func writePage(to url: URL, _ body: (CGContext) throws(RenderError) -> Void)
    throws(RenderError)
  {
    var mediaBox = CGRect(x: 0, y: 0, width: Page.a4.width.points, height: Page.a4.height.points)
    guard let context = CGContext(url as CFURL, mediaBox: &mediaBox, nil) else { throw .cannotCreateDocument }
    context.beginPDFPage(nil)
    defer {
      context.endPDFPage()
      context.closePDF()
    }
    let scale = Millimeters(mm: 1).points
    context.translateBy(x: 0, y: Page.a4.height.points)
    context.scaleBy(x: scale, y: -scale)
    try body(context)
  }

  /// Text in the flipped millimetre space: un-flip locally so glyphs are upright.
  private static func drawText(
    _ text: String, at point: CGPoint, size: Double = bodySize, centred: Bool = false, in context: CGContext
  ) {
    let font = CTFontCreateWithName("Helvetica" as CFString, size, nil)
    let attributed = NSAttributedString(
      string: text, attributes: [.init(kCTFontAttributeName as String): font])
    let line = CTLineCreateWithAttributedString(attributed)
    let width = centred ? CTLineGetTypographicBounds(line, nil, nil, nil) : 0
    context.saveGState()
    context.translateBy(x: point.x - width / 2, y: point.y)
    context.scaleBy(x: 1, y: -1)
    context.textPosition = .zero
    CTLineDraw(line, context)
    context.restoreGState()
  }
}
