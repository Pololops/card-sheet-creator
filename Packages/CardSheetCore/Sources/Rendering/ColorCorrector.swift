import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins
import Domain

/// Applies a `ColorCorrection` to bitmaps with one pass through a 3D lookup table baked from
/// `CorrectionCurve`, so every pixel gets exactly the curve's result whatever the image's size.
struct ColorCorrector {
  private static let cubeDimension = 33

  private let cubeData: Data
  /// Local rather than shared: a float working format keeps white from rounding to 254 between stages.
  private let context = CIContext(options: [.workingFormat: CIFormat.RGBAf])

  init(correction: ColorCorrection) {
    cubeData = Self.bakeCube(for: correction)
  }

  /// The corrected bitmap, in the source's colour space (sRGB when the source isn't RGB).
  func apply(to image: CGImage) throws(RenderError) -> CGImage {
    let colorSpace = Self.rgbColorSpace(of: image)
    let filter = CIFilter.colorCubeWithColorSpace()
    filter.inputImage = CIImage(cgImage: image)
    filter.cubeDimension = Float(Self.cubeDimension)
    filter.cubeData = cubeData
    filter.colorSpace = colorSpace
    guard let output = filter.outputImage,
      let corrected = context.createCGImage(
        output, from: output.extent, format: .RGBA8, colorSpace: colorSpace)
    else { throw .cannotCreateDocument }
    return corrected
  }

  /// Float32 RGBA entries with red varying fastest, as Core Image expects.
  private static func bakeCube(for correction: ColorCorrection) -> Data {
    let size = cubeDimension
    let lastIndex = Double(size - 1)
    let entries = (0..<size * size * size).flatMap { index -> [Float] in
      let input = SIMD3(Double(index % size), Double(index / size % size), Double(index / (size * size)))
      let output = CorrectionCurve.apply(input / lastIndex, correction)
      return [Float(output.x), Float(output.y), Float(output.z), 1]
    }
    return entries.withUnsafeBytes { Data($0) }
  }

  private static func rgbColorSpace(of image: CGImage) -> CGColorSpace {
    if let space = image.colorSpace, space.model == .rgb { return space }
    return CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
  }
}
