/// Which part of an overflowing image shows in its slot: 0 aligns the left/top edges, 1 the right/bottom
/// edges. Normalized so the framing survives a slot resize without ever uncovering the slot.
public struct CropAnchor: Hashable, Sendable, Codable {
  public static let centered = CropAnchor(x: 0.5, y: 0.5)

  public var x: Double
  public var y: Double

  public init(x: Double, y: Double) {
    self.x = x
    self.y = y
  }
}

/// Framing math shared by the on-screen editor and the print renderer, so both always agree.
public enum Crop {
  /// Within this distance of the center, a dragged image snaps to it.
  public static let snapDistance = Millimeters(tenths: 10)
  /// Below this overflow (mm), the image already fits the slot's ratio and has nothing to reveal.
  private static let overflowTolerance = 0.0001

  /// The image rect in slot coordinates (mm): it covers the whole slot and overflows on one axis.
  public static func coverRect(image: PixelSize, slot: SlotSize, anchor: CropAnchor) -> MMRect {
    let (width, height) = coveredSize(image: image, slot: slot)
    return MMRect(
      x: -(width - slot.width.mm) * anchor.x, y: -(height - slot.height.mm) * anchor.y, width: width,
      height: height)
  }

  /// Dragging the image right or down reveals more of its left or top part.
  public static func anchor(
    _ anchor: CropAnchor, afterDragBy offset: MMOffset, image: PixelSize, slot: SlotSize
  ) -> CropAnchor {
    let size = coveredSize(image: image, slot: slot)
    return CropAnchor(
      x: moved(anchor.x, by: offset.dx, overflow: size.width - slot.width.mm),
      y: moved(anchor.y, by: offset.dy, overflow: size.height - slot.height.mm))
  }

  /// Whether dragging can reveal another part of the image: false when it has exactly the slot's ratio.
  public static func canReframe(image: PixelSize, slot: SlotSize) -> Bool {
    let size = coveredSize(image: image, slot: slot)
    return size.width - slot.width.mm > overflowTolerance || size.height - slot.height.mm > overflowTolerance
  }

  public static func isCentered(_ anchor: CropAnchor) -> Bool {
    anchor == .centered
  }

  private static func coveredSize(image: PixelSize, slot: SlotSize) -> (width: Double, height: Double) {
    let scale = max(slot.width.mm / Double(image.width), slot.height.mm / Double(image.height))
    return (Double(image.width) * scale, Double(image.height) * scale)
  }

  private static func moved(_ position: Double, by delta: Double, overflow: Double) -> Double {
    guard overflow > overflowTolerance else { return position }
    let next = min(max(position - delta / overflow, 0), 1)
    let distanceFromCenter = abs(next - 0.5) * overflow
    return distanceFromCenter <= snapDistance.mm ? 0.5 : next
  }
}
