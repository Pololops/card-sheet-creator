import Foundation

public enum Distribution {
  /// One image fills a whole sheet; several images take one slot each, spilling onto as many sheets as needed.
  public static func sheets(
    for images: [ImageRef], from template: Template, baseName: String, now: Date, makeID: () -> UUID
  ) throws(LayoutError) -> [Sheet] {
    let capacity = try GridLayout.make(template.geometry).capacity
    func sheet(named name: String, fillMode: FillMode, images: [ImageRef]) -> Sheet {
      Sheet(
        id: makeID(), name: name, geometry: template.geometry, sourceTemplateID: template.id,
        fillMode: fillMode, images: images, createdAt: now, updatedAt: now)
    }

    switch images.count {
    case 0:
      return []
    case 1:
      return [sheet(named: baseName, fillMode: .duplicated, images: images)]
    default:
      let chunks = stride(from: 0, to: images.count, by: capacity).map {
        Array(images[$0..<min($0 + capacity, images.count)])
      }
      return chunks.enumerated().map { index, chunk in
        let name = chunks.count == 1 ? baseName : "\(baseName) \(index + 1)/\(chunks.count)"
        return sheet(named: name, fillMode: .list, images: chunk)
      }
    }
  }
}
