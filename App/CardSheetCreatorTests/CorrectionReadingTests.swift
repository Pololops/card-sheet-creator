import Domain
import Testing

@testable import CardSheetCreator

@MainActor @Suite struct CorrectionReadingTests {
  private func value(of name: String, in correction: ColorCorrection) throws -> String {
    let readings = CorrectionReading.readings(for: correction, isColorPrinter: true)
    return try #require(readings.first { $0.name == name }).value
  }

  @Test func neutralCorrectionReadsAsNoCorrectionOnEveryAxis() {
    let readings = CorrectionReading.readings(for: .neutral, isColorPrinter: true)

    #expect(readings.map(\.value) == Array(repeating: "Aucune correction", count: 5))
  }

  @Test func valueNamesTheDirectionTakenAndItsSteps() throws {
    let correction = ColorCorrection(brightness: 3, contrast: -1, saturation: -2, warmth: 1, tint: -2)

    #expect(try value(of: "Luminosité", in: correction) == "Éclaircir · 3 crans")
    #expect(try value(of: "Contraste", in: correction) == "Adoucir · 1 cran")
    #expect(try value(of: "Intensité", in: correction) == "Pâlir · 2 crans")
    #expect(try value(of: "Chaud ou froid", in: correction) == "Réchauffer · 1 cran")
    #expect(try value(of: "Vert ou rose", in: correction) == "Plus vert · 2 crans")
  }

  @Test func colourPrinterReadsEveryAxisBrightnessFirst() {
    let readings = CorrectionReading.readings(for: .neutral, isColorPrinter: true)

    #expect(
      readings.map(\.name) == ["Luminosité", "Contraste", "Chaud ou froid", "Vert ou rose", "Intensité"])
  }

  @Test func blackAndWhitePrinterOnlyReadsBrightnessAndContrast() {
    let readings = CorrectionReading.readings(for: ColorCorrection(warmth: 2), isColorPrinter: false)

    #expect(readings.map(\.name) == ["Luminosité", "Contraste"])
  }

  @Test func eachAxisSpansItsOwnLimit() throws {
    let readings = CorrectionReading.readings(for: .neutral, isColorPrinter: true)

    let limits = Dictionary(uniqueKeysWithValues: readings.map { ($0.name, $0.limit) })
    #expect(limits["Luminosité"] == ColorCorrection.levelLimit)
    #expect(limits["Chaud ou froid"] == ColorCorrection.dominantLimit)
  }
}
