import Foundation
import PDFKit

/// What a PDF looks like once drawn. Raw bytes differ between two renders of the same sheet
/// (`/CreationDate`), so tests compare appearances.
enum PrintedPDF {
  private static let thumbnailSize = CGSize(width: 300, height: 424)

  static func pageAppearance(_ pdf: Data) -> Data? {
    PDFDocument(data: pdf)?.page(at: 0)?
      .thumbnail(of: thumbnailSize, for: .mediaBox)
      .tiffRepresentation
  }
}
