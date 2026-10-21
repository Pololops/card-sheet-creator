import Foundation
import Testing

@testable import CardSheetCreator

@MainActor @Suite struct ColorCalibrationRouteTests {
  @Test func startingWithNoWindowOpenLaunchesAFlowForTheGivenSheets() {
    let route = ColorCalibrationRoute()
    let sheetID = UUID()

    route.start(printerName: "Canon G5000 series", sheetIDs: [sheetID])

    #expect(route.launch.printerName == "Canon G5000 series")
    #expect(route.launch.sheetIDs == [sheetID])
  }

  @Test func startingWhileTheWindowIsOpenKeepsTheRunningFlow() {
    let route = ColorCalibrationRoute()
    route.start(printerName: "Canon G5000 series", sheetIDs: [])
    let running = route.launch
    route.isWindowOpen = true

    route.start(printerName: "Epson XP-2100", sheetIDs: [UUID()])

    #expect(route.launch == running)
  }
}
