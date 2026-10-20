import Domain
import SwiftUI

/// A blank template drawn as an A4 page with its slot outlines.
struct TemplateThumbnail: View {
  let geometry: SheetGeometry
  let size: CGSize

  var body: some View {
    Canvas { context, canvasSize in
      let scale = canvasSize.width / Page.a4.width.mm
      guard let layout = try? Domain.GridLayout.make(geometry) else { return }
      for slot in layout.slots {
        context.stroke(Path(slot.scaled(scale)), with: .color(.secondary), lineWidth: 0.75)
      }
    }
    .frame(width: size.width, height: size.height)
    .background(Design.Palette.paper)
    .clipShape(RoundedRectangle(cornerRadius: 3))
    .shadow(color: .black.opacity(0.2), radius: 0.5)
    .shadow(color: .black.opacity(0.14), radius: 1.5, y: 1)
    .accessibilityHidden(true)
  }
}

/// A sheet rendered small with its real images; a neutral page shows while it renders.
struct SheetThumbnail: View {
  let sheet: Sheet
  let images: ImageCache
  let size: CGSize

  @Environment(\.displayScale) private var displayScale
  @State private var rendered: CGImage?

  var body: some View {
    ZStack {
      Design.Palette.paper
      if let rendered {
        Image(decorative: rendered, scale: displayScale).resizable()
      } else {
        Rectangle().fill(.quaternary)
      }
    }
    .frame(width: size.width, height: size.height)
    .clipShape(RoundedRectangle(cornerRadius: 3))
    .shadow(color: .black.opacity(0.2), radius: 0.5)
    .shadow(color: .black.opacity(0.14), radius: 1.5, y: 1)
    .task(id: sheet) {
      rendered = await images.pageThumbnail(of: sheet, widthPixels: Int(size.width * displayScale))
    }
    .accessibilityHidden(true)
  }
}
