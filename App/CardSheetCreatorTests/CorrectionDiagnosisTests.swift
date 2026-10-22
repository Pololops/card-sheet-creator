import Domain
import Testing

@testable import CardSheetCreator

@MainActor @Suite struct CorrectionDiagnosisTests {
  @Test func faithfulPrinterNeedsNoCorrection() {
    #expect(
      CorrectionDiagnosis.sentence(for: .neutral)
        == "Ton imprimante reproduit déjà fidèlement l'écran : aucune correction.")
  }

  @Test(arguments: [
    (ColorCorrection(brightness: 3), "assombrit les images"),
    (ColorCorrection(brightness: -3), "éclaircit les images"),
    (ColorCorrection(contrast: 3), "adoucit les contrastes"),
    (ColorCorrection(contrast: -3), "durcit les contrastes"),
    (ColorCorrection(saturation: 3), "pâlit les couleurs"),
    (ColorCorrection(saturation: -3), "avive les couleurs"),
  ])
  func singleTendencyReadsAsOneClause(correction: ColorCorrection, clause: String) {
    #expect(CorrectionDiagnosis.sentence(for: correction) == "Ton imprimante \(clause) : on compense.")
  }

  @Test func clausesJoinWithEt() {
    let two = ColorCorrection(brightness: 3, saturation: 1)
    let three = ColorCorrection(brightness: 3, contrast: -5, saturation: 1)

    #expect(
      CorrectionDiagnosis.sentence(for: two)
        == "Ton imprimante assombrit les images et pâlit un peu les couleurs : on compense.")
    #expect(
      CorrectionDiagnosis.sentence(for: three)
        == "Ton imprimante assombrit les images, durcit nettement les contrastes et pâlit un peu les couleurs : on compense."
    )
  }

  @Test(arguments: [
    (1, 0, "le bleu"), (-1, 0, "le jaune"), (0, 1, "le vert"), (0, -1, "le rose"),
    (1, 1, "le bleu-vert"), (1, -1, "le violet"), (-1, 1, "le jaune-vert"), (-1, -1, "l'orangé"),
  ])
  func castDirectionsNameTheirColour(warmth: Int, tint: Int, colour: String) {
    let correction = ColorCorrection(warmth: warmth, tint: tint)

    #expect(
      CorrectionDiagnosis.sentence(for: correction)
        == "Ton imprimante tire un peu vers \(colour) : on compense.")
  }

  @Test func strongestCastDropsTheAdverb() {
    let correction = ColorCorrection(warmth: 1, tint: -2)

    #expect(
      CorrectionDiagnosis.sentence(for: correction) == "Ton imprimante tire vers le violet : on compense.")
  }

  @Test(arguments: [
    (1, "assombrit un peu"), (2, "assombrit un peu"), (3, "assombrit"), (4, "assombrit"),
    (5, "assombrit nettement"), (6, "assombrit nettement"),
  ])
  func adverbsFollowTheLevel(level: Int, verbPhrase: String) {
    let correction = ColorCorrection(brightness: level)

    #expect(
      CorrectionDiagnosis.sentence(for: correction)
        == "Ton imprimante \(verbPhrase) les images : on compense.")
  }
}
