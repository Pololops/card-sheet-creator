import Foundation

/// An image copied into the library, identified by its content so the same file imported twice is one image.
public struct ImageRef: Hashable, Sendable, Codable {
  public var sha256: String
  public var fileExtension: String
  /// The file name the user picked, shown in the inspector; not part of the image's identity.
  public var originalName: String

  public init(sha256: String, fileExtension: String, originalName: String = "") {
    self.sha256 = sha256
    self.fileExtension = fileExtension
    self.originalName = originalName
  }

  public var fileName: String { "\(sha256).\(fileExtension)" }

  public static func == (lhs: ImageRef, rhs: ImageRef) -> Bool { lhs.sha256 == rhs.sha256 }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(sha256)
  }
}

public enum FillMode: String, Hashable, Sendable, Codable {
  /// One image repeated on every slot, whatever the slot count becomes.
  case duplicated
  /// One image per slot, in selection order.
  case list
}

public struct Sheet: Identifiable, Hashable, Sendable, Codable {
  public var id: UUID
  public var name: String
  public var geometry: SheetGeometry
  public var sourceTemplateID: UUID?
  public var fillMode: FillMode
  public var images: [ImageRef]
  /// Keyed by image hash rather than by slot, so every clone of an image shares one framing.
  public var crops: [String: CropAnchor]
  public var createdAt: Date
  public var updatedAt: Date

  public init(
    id: UUID, name: String, geometry: SheetGeometry, sourceTemplateID: UUID?, fillMode: FillMode,
    images: [ImageRef], crops: [String: CropAnchor] = [:], createdAt: Date, updatedAt: Date
  ) {
    self.id = id
    self.name = name
    self.geometry = geometry
    self.sourceTemplateID = sourceTemplateID
    self.fillMode = fillMode
    self.images = images
    self.crops = crops
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }

  /// One entry per slot; `nil` for an empty slot at the end of a list sheet.
  public func slotContents() throws(LayoutError) -> [ImageRef?] {
    let capacity = try GridLayout.make(geometry).capacity
    switch fillMode {
    case .duplicated:
      return Array(repeating: images.first, count: capacity)
    case .list:
      let placed = images.prefix(capacity).map(Optional.some)
      return placed + Array(repeating: nil, count: capacity - placed.count)
    }
  }

  public func crop(for image: ImageRef) -> CropAnchor {
    crops[image.sha256] ?? .centered
  }

  public mutating func setCrop(_ anchor: CropAnchor, for image: ImageRef) {
    crops[image.sha256] = anchor
  }

  public func cloneCount(of image: ImageRef) -> Int {
    let contents = (try? slotContents()) ?? images.map(Optional.some)
    return contents.filter { $0 == image }.count
  }
}
