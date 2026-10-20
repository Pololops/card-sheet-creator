import Foundation

public struct Template: Identifiable, Hashable, Sendable, Codable {
  public var id: UUID
  public var name: String
  public var geometry: SheetGeometry
  public var createdAt: Date
  public var updatedAt: Date

  public init(id: UUID, name: String, geometry: SheetGeometry, createdAt: Date, updatedAt: Date) {
    self.id = id
    self.name = name
    self.geometry = geometry
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }

  /// Seeded on first launch so the first sheet is one drop away.
  public static func standardDefault(id: UUID, now: Date) -> Template {
    Template(
      id: id, name: "Carte standard", geometry: SheetGeometry(slot: .standardCard), createdAt: now,
      updatedAt: now)
  }
}
