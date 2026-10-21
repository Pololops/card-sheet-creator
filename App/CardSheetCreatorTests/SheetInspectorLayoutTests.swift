import AppKit
import SwiftUI
import Testing

@testable import CardSheetCreator

@MainActor @Suite struct SheetInspectorLayoutTests {
  /// Only the pinned footer and its padding may claim height: the rest of the inspector must scroll.
  private static let pinnedFooterMaxHeight: CGFloat = 80

  @Test func selectedSlotNeverForcesTheWindowTaller() async throws {
    let (store, model, sheet) = try await TestLibrary.sheetWithOneImage()
    let inspector = NSHostingController(
      rootView: SheetInspector(
        model: model, sheet: sheet, images: ImageCache(persistence: store), selectedSlot: 0,
        onEditDimensions: {}))

    let minimum = inspector.sizeThatFits(in: CGSize(width: Design.Metrics.inspectorWidth, height: 0))

    #expect(minimum.height > 0)
    #expect(minimum.height <= Self.pinnedFooterMaxHeight)
  }

  @Test func resizeInspectorNeverForcesTheWindowTaller() async throws {
    let (_, _, sheet) = try await TestLibrary.sheetWithOneImage()
    let inspector = NSHostingController(rootView: ResizeInspector(draft: ResizeDraft(sheet: sheet)))

    let minimum = inspector.sizeThatFits(in: CGSize(width: Design.Metrics.inspectorWidth, height: 0))

    #expect(minimum.height > 0)
    #expect(minimum.height <= Self.pinnedFooterMaxHeight)
  }
}
