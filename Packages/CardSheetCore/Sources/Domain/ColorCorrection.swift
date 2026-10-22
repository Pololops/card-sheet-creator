/// How a printer's output is nudged so paper looks like the screen. Each axis is a signed number of
/// steps; the rendering layer decides what one step means.
public struct ColorCorrection: Hashable, Sendable, Codable {
  public static let neutral = ColorCorrection()
  /// Brightness, contrast and saturation stay within this many steps.
  public static let levelLimit = 6
  /// Warmth and tint stay within this many steps: a colour cast is more visible than a level shift.
  public static let dominantLimit = 2

  public var brightness: Int
  public var contrast: Int
  public var saturation: Int
  /// Positive is warmer (more red, less blue).
  public var warmth: Int
  /// Positive is more magenta (less green).
  public var tint: Int

  public init(brightness: Int = 0, contrast: Int = 0, saturation: Int = 0, warmth: Int = 0, tint: Int = 0) {
    self.brightness = brightness
    self.contrast = contrast
    self.saturation = saturation
    self.warmth = warmth
    self.tint = tint
  }

  public var isNeutral: Bool { self == .neutral }

  public func clamped(levelLimit: Int = Self.levelLimit, dominantLimit: Int = Self.dominantLimit)
    -> ColorCorrection
  {
    ColorCorrection(
      brightness: brightness.clamped(toMagnitude: levelLimit),
      contrast: contrast.clamped(toMagnitude: levelLimit),
      saturation: saturation.clamped(toMagnitude: levelLimit),
      warmth: warmth.clamped(toMagnitude: dominantLimit),
      tint: tint.clamped(toMagnitude: dominantLimit))
  }

  public func adding(_ other: ColorCorrection) -> ColorCorrection {
    ColorCorrection(
      brightness: brightness + other.brightness, contrast: contrast + other.contrast,
      saturation: saturation + other.saturation, warmth: warmth + other.warmth, tint: tint + other.tint
    ).clamped()
  }
}

extension Int {
  fileprivate func clamped(toMagnitude limit: Int) -> Int {
    Swift.min(Swift.max(self, -limit), limit)
  }
}
