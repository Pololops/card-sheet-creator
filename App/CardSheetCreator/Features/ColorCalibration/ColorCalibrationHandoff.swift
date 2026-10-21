import Domain
import SwiftUI

extension View {
  /// Reopens the print dialog with the same sheets once a calibration launched from it is done.
  func colorCalibrationHandoff(
    route: ColorCalibrationRoute, library: LibraryModel, onReopen: @escaping ([Sheet], String?) -> Void
  ) -> some View {
    modifier(ColorCalibrationHandoff(route: route, library: library, onReopen: onReopen))
  }
}

private struct ColorCalibrationHandoff: ViewModifier {
  let route: ColorCalibrationRoute
  let library: LibraryModel
  let onReopen: ([Sheet], String?) -> Void

  func body(content: Content) -> some View {
    content
      // `initial` catches a handoff made while the library window was closed.
      .onChange(of: route.handoff, initial: true) { reopenIfReady() }
      .onChange(of: library.sheets.count) { reopenIfReady() }
  }

  /// A handoff waits for its sheets: a window opened just now may not have loaded the library yet.
  private func reopenIfReady() {
    guard let handoff = route.handoff else { return }
    let sheets = handoff.sheetIDs.compactMap(library.sheet(id:))
    guard !sheets.isEmpty else { return }
    route.handoff = nil
    onReopen(sheets, handoff.printerName)
  }
}
