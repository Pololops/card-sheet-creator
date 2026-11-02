import Domain
import SwiftUI

/// While dragging: the overflowing part of the image in transparency, plus centre guides once centered.
struct DragOverlay: View {
  let drag: SheetCanvas.ActiveDrag
  let frame: CGRect
  let slotSize: SlotSize
  let scale: Double
  let images: ImageCache

  var body: some View {
    let isCentered = Crop.isCentered(drag.anchor)
    ZStack(alignment: .topLeading) {
      SlotView(
        image: drag.image, anchor: drag.anchor, slotSize: slotSize, scale: scale, images: images,
        isDraggable: false
      )
      .opacity(0.3)
      .offset(x: frame.minX, y: frame.minY)
      Rectangle()
        .strokeBorder(Color.accentColor, lineWidth: 2)
        .overlay {
          if isCentered { CenterGuides() }
        }
        .frame(width: frame.width, height: frame.height)
        .offset(x: frame.minX, y: frame.minY)
      if isCentered {
        Text("Centrée")
          .font(.system(size: 10, weight: .bold))
          .foregroundStyle(.white)
          .padding(.horizontal, 8)
          .padding(.vertical, 2)
          .background(Design.Palette.centerGuide, in: Capsule())
          .frame(width: frame.width)
          .offset(x: frame.minX, y: frame.minY - 28)
      }
    }
    .allowsHitTesting(false)
    .accessibilityHidden(true)
  }
}

struct CenterGuides: View {
  var body: some View {
    ZStack {
      Rectangle().fill(Design.Palette.centerGuide).frame(width: 1.5).shadow(color: .white, radius: 0, x: 1)
        .shadow(color: .white, radius: 0, x: -1)
      Rectangle().fill(Design.Palette.centerGuide).frame(height: 1.5).shadow(color: .white, radius: 0, y: 1)
        .shadow(color: .white, radius: 0, y: -1)
    }
  }
}
