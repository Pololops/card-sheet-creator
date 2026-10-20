public enum DisplayScale {
  /// Physical widths outside this range come from displays that misreport their size.
  private static let plausibleWidthMm = 100.0...2000.0

  /// Screen points per millimetre, for the "real size" zoom; `nil` when the display size can't be trusted.
  public static func pointsPerMillimetre(physicalWidthMm: Double, widthPoints: Double) -> Double? {
    guard plausibleWidthMm.contains(physicalWidthMm), widthPoints > 0 else { return nil }
    return widthPoints / physicalWidthMm
  }
}
