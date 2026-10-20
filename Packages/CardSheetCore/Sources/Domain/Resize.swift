import Foundation

public struct ResizeOutcome: Sendable {
  public var sheet: Sheet
  /// Extra sheets holding the images that no longer fit, in order.
  public var overflow: [Sheet]
  public var movedCount: Int
}

extension Sheet {
  /// Applies a new geometry; images that no longer fit move to new sheets instead of being dropped.
  public func resized(to geometry: SheetGeometry, now: Date, makeID: () -> UUID) throws(LayoutError)
    -> ResizeOutcome
  {
    let capacity = try GridLayout.make(geometry).capacity
    var kept = self
    kept.geometry = geometry
    kept.updatedAt = now
    guard fillMode == .list, images.count > capacity else {
      return ResizeOutcome(sheet: kept, overflow: [], movedCount: 0)
    }

    kept.images = Array(images.prefix(capacity))
    kept.crops = crops(for: kept.images)
    let moved = Array(images.dropFirst(capacity))
    let overflow = stride(from: 0, to: moved.count, by: capacity).enumerated().map { index, start in
      let chunk = Array(moved[start..<min(start + capacity, moved.count)])
      return Sheet(
        id: makeID(), name: Self.continuationName(of: name, index: index), geometry: geometry,
        sourceTemplateID: sourceTemplateID, fillMode: .list, images: chunk, crops: crops(for: chunk),
        createdAt: now, updatedAt: now)
    }
    return ResizeOutcome(sheet: kept, overflow: overflow, movedCount: moved.count)
  }

  private func crops(for subset: [ImageRef]) -> [String: CropAnchor] {
    let hashes = Set(subset.map(\.sha256))
    return crops.filter { hashes.contains($0.key) }
  }

  private static func continuationName(of name: String, index: Int) -> String {
    index == 0 ? "\(name) (suite)" : "\(name) (suite \(index + 1))"
  }
}
