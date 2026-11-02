import Domain
import SwiftUI

/// What a pinch acts on, decided once, where the fingers land.
enum PinchTarget: Equatable {
  case view
  case slots

  /// `pagePoint` is in points from the page's top-left corner. Only a slot resizes the template: the
  /// gutters, the hatched band and the grey canvas zoom the view.
  static func at(_ pagePoint: CGPoint, layout: Domain.GridLayout?, scale: Double) -> PinchTarget {
    guard let layout, layout.slots.contains(where: { $0.scaled(scale).contains(pagePoint) }) else {
      return .view
    }
    return .slots
  }
}

/// Pinching zooms the page between the zoom limits, or, when it starts on a slot of a template, resizes
/// every slot with its ratio kept. The gesture sits on the scrolling content, so it covers the gutters, the
/// hatched band, the grey canvas and every sheet.
struct CanvasPinch: ViewModifier {
  let model: LibraryModel
  let zoom: CanvasZoom
  let available: CGSize
  /// Where the page sits in the content, to turn the pinch's start into page coordinates.
  let pageFrame: CGRect
  let scale: Double

  @GestureState private var active: ActivePinch?
  @State private var isAtLimit = false

  struct ActivePinch: Equatable {
    var startPercent: Int
    /// `nil` while the pinch zooms the view.
    var slotResize: SlotResize?
  }

  struct SlotResize: Equatable {
    var templateID: UUID
    var startGeometry: SheetGeometry
  }

  func body(content: Content) -> some View {
    content
      .gesture(pinch)
      // A cancelled pinch never reaches `onEnded`, but its state still resets: that discards the preview.
      .onChange(of: active == nil) { _, isIdle in
        if isIdle { model.discardGeometryPreview() }
      }
      // Only the edge into a limit taps the trackpad: holding at the limit stays silent.
      .sensoryFeedback(.levelChange, trigger: isAtLimit) { wasAtLimit, isNowAtLimit in
        !wasAtLimit && isNowAtLimit
      }
  }

  private var pinch: some Gesture {
    MagnifyGesture()
      .updating($active) { value, active, _ in
        let pinch = active ?? beginPinch(at: value.startLocation)
        active = pinch
        isAtLimit = update(pinch, magnification: value.magnification)
      }
      .onEnded { _ in
        model.commitGeometryPreview()
        isAtLimit = false
      }
  }

  private func beginPinch(at startLocation: CGPoint) -> ActivePinch {
    let startPercent = zoom.percent(fitting: available)
    guard let template = model.selectedTemplate else { return ActivePinch(startPercent: startPercent) }
    let pagePoint = CGPoint(x: startLocation.x - pageFrame.minX, y: startLocation.y - pageFrame.minY)
    let layout = try? Domain.GridLayout.make(template.geometry)
    guard PinchTarget.at(pagePoint, layout: layout, scale: scale) == .slots else {
      return ActivePinch(startPercent: startPercent)
    }
    model.beginGeometryPreview(ofTemplate: template.id)
    return ActivePinch(
      startPercent: startPercent,
      slotResize: SlotResize(templateID: template.id, startGeometry: template.geometry))
  }

  /// Returns true when the pinch is held at a limit.
  private func update(_ pinch: ActivePinch, magnification: Double) -> Bool {
    guard let resize = pinch.slotResize else {
      return zoom.magnify(from: pinch.startPercent, by: magnification)
    }
    guard
      let scaled = ProportionLock.scaled(
        resize.startGeometry.slot, by: magnification, minimum: Domain.GridLayout.minimumSlotSide,
        maximum: Page.usableArea)
    else { return false }
    var geometry = resize.startGeometry
    geometry.slot = scaled.slot
    model.previewGeometry(ofTemplate: resize.templateID, to: geometry)
    return scaled.isAtLimit
  }
}
