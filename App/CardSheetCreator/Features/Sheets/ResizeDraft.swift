import Domain
import Foundation
import Observation

/// Unsaved new dimensions for a sheet; nothing touches the library until the user validates.
@Observable
final class ResizeDraft {
  let sheet: Sheet
  var geometry: SheetGeometry

  init(sheet: Sheet) {
    self.sheet = sheet
    geometry = sheet.geometry
  }

  var layout: Domain.GridLayout? { try? Domain.GridLayout.make(geometry) }
  var previousCapacity: Int { (try? Domain.GridLayout.make(sheet.geometry).capacity) ?? 0 }

  /// The sheet as it would look after validation (overflow sheets get throwaway ids).
  var preview: ResizeOutcome? { try? sheet.resized(to: geometry, now: .now, makeID: UUID.init) }
  var movedCount: Int { preview?.movedCount ?? 0 }
  var hasChanges: Bool { geometry != sheet.geometry }
}
