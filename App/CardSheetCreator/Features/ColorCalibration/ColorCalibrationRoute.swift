import Foundation
import Observation

/// What the print dialog and the calibration window tell each other. It is the only link between them,
/// so the window never touches the dialog's `PrintController`.
@Observable
final class ColorCalibrationRoute {
  /// Why the window opens: from the menu there are no sheets, from the print dialog there are.
  /// A fresh `id` restarts the flow even when the window is already open.
  struct Launch: Equatable {
    let id: UUID
    let printerName: String?
    let sheetIDs: [UUID]

    init(id: UUID = UUID(), printerName: String?, sheetIDs: [UUID]) {
      self.id = id
      self.printerName = printerName
      self.sheetIDs = sheetIDs
    }
  }

  /// What the main window reopens the print dialog with once the calibration is done.
  struct Handoff: Equatable {
    let sheetIDs: [UUID]
    let printerName: String?
  }

  var launch = Launch(printerName: nil, sheetIDs: [])
  var handoff: Handoff?
  /// Two windows must not write the print settings at once: the print action waits while this is true.
  var isWindowOpen = false
}
