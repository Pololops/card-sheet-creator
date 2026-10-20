import Domain

public struct Paper: Hashable, Sendable {
  public var id: String
  public var name: String

  public init(id: String, name: String) {
    self.id = id
    self.name = name
  }
}

/// Picks the driver's plain A4: its borderless variants enlarge the page by ~1 %, which would change
/// the printed card size.
enum PaperSelection {
  private static let borderlessMarkers = ["borderless", ".fb", "fullbleed", "sans marge"]

  static func standardA4(in papers: [Paper]) -> Paper? {
    papers.first { paper in
      let id = paper.id.lowercased()
      let name = paper.name.lowercased()
      let isA4 = id.contains("a4") || name == "a4"
      let isBorderless = borderlessMarkers.contains { id.contains($0) || name.contains($0) }
      return isA4 && !isBorderless
    }
  }
}

extension PrintQuality {
  /// IPP `print-quality` enum, understood by AirPrint and most CUPS drivers.
  var ippValue: String {
    switch self {
    case .draft: "3"
    case .best: "5"
    }
  }

  /// Legacy CUPS key used by some PPD-based drivers.
  var cupsValue: String {
    switch self {
    case .draft: "Draft"
    case .best: "High"
    }
  }
}
