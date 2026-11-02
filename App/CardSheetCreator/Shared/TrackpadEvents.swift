// ADR 0002 keeps the UI in SwiftUI, and this is its one AppKit bridge: SwiftUI reports neither the deltas of
// a two-finger scroll nor a two-finger double-tap (smart magnify). Everything else on the trackpad (pinch,
// swipe, haptics, press-and-hold) stays native SwiftUI.
import AppKit
import SwiftUI

enum TrackpadEvent: Equatable {
  /// `at` is in points from the probe's top-left corner.
  case panBegan(at: CGPoint)
  /// Points to move by, with the sign of the page scroll: the content follows the fingers when natural
  /// scrolling is on.
  case panChanged(by: CGVector)
  case panEnded
  case panCancelled
  case smartMagnify(at: CGPoint)
}

/// Reports trackpad events that land on the view it backs. It never takes part in hit-testing, so clicks,
/// drags and menus go through it untouched.
struct TrackpadProbe: NSViewRepresentable {
  enum Role {
    /// The sheet, inside the scroll view: gets the scroll and the smart magnify first.
    case page
    /// The whole canvas: gets the smart magnify the page did not take.
    case canvas
  }

  let role: Role
  /// Returns whether the event was taken. Only the first event of a scroll gesture is a claim.
  let onEvent: (TrackpadEvent) -> Bool

  func makeNSView(context: Context) -> TrackpadProbeView {
    let view = TrackpadProbeView(role: role)
    view.onEvent = onEvent
    return view
  }

  func updateNSView(_ view: TrackpadProbeView, context: Context) {
    view.onEvent = onEvent
  }

  static func dismantleNSView(_ view: TrackpadProbeView, coordinator: ()) {
    TrackpadEventRouter.shared.unregister(view)
  }
}

final class TrackpadProbeView: NSView {
  let role: TrackpadProbe.Role
  var onEvent: (TrackpadEvent) -> Bool = { _ in false }

  init(role: TrackpadProbe.Role) {
    self.role = role
    super.init(frame: .zero)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

  // Top-left origin, like SwiftUI, so a point here is a point in the content it backs.
  override var isFlipped: Bool { true }

  override func hitTest(_ point: NSPoint) -> NSView? { nil }

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    if window == nil {
      TrackpadEventRouter.shared.unregister(self)
    } else {
      TrackpadEventRouter.shared.register(self)
    }
  }

  func point(of event: NSEvent) -> CGPoint {
    convert(event.locationInWindow, from: nil)
  }

  /// Whether the event lands on this probe's own content, not on another window, a floating control or the
  /// area around it.
  func contains(_ event: NSEvent) -> Bool {
    guard let window, event.window === window, bounds.contains(point(of: event)) else { return false }
    guard role == .page else { return true }
    guard let document = enclosingScrollView?.documentView,
      let content = window.contentView,
      let hit = content.hitTest(content.superview?.convert(event.locationInWindow, from: nil) ?? .zero)
    else { return false }
    return hit.isDescendant(of: document)
  }
}

/// The app's single local event monitor: installed with the first probe, removed with the last one.
@MainActor
final class TrackpadEventRouter {
  static let shared = TrackpadEventRouter()

  private weak var page: TrackpadProbeView?
  private weak var canvas: TrackpadProbeView?
  private var monitor: Any?
  private var gate = ScrollGestureGate()

  func register(_ probe: TrackpadProbeView) {
    switch probe.role {
    case .page: page = probe
    case .canvas: canvas = probe
    }
    guard monitor == nil else { return }
    monitor = NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel, .smartMagnify]) { event in
      // The monitor is documented to run on the main thread, but its closure carries no isolation (ADR 0007
      // keeps the app on the main actor), so we assert what AppKit promises rather than hop to a task: a
      // hop would let the event reach the scroll view before we could keep it from there.
      let isSwallowed = MainActor.assumeIsolated { TrackpadEventRouter.shared.route(event) }
      return isSwallowed ? nil : event
    }
  }

  /// A replacement probe may register before the one it replaces goes away: only forget the same one.
  func unregister(_ probe: TrackpadProbeView) {
    if page === probe { page = nil }
    if canvas === probe { canvas = nil }
    guard page == nil, canvas == nil, let monitor else { return }
    NSEvent.removeMonitor(monitor)
    self.monitor = nil
  }

  /// Returns whether the event is ours and must not reach the view under the pointer.
  private func route(_ event: NSEvent) -> Bool {
    switch event.type {
    case .scrollWheel: routeScroll(event)
    case .smartMagnify: routeSmartMagnify(event)
    default: false
    }
  }

  private func routeScroll(_ event: NSEvent) -> Bool {
    guard event.hasPreciseScrollingDeltas, let phase = ScrollPhase(event), let page else { return false }
    let verdict = gate.verdict(for: phase) {
      page.contains(event) && page.onEvent(.panBegan(at: page.point(of: event)))
    }
    switch (verdict, phase) {
    case (.deliver, .changed):
      _ = page.onEvent(.panChanged(by: CGVector(dx: event.scrollingDeltaX, dy: event.scrollingDeltaY)))
    case (.deliver, .ended):
      _ = page.onEvent(.panEnded)
    case (.deliver, .cancelled):
      _ = page.onEvent(.panCancelled)
    default:
      break
    }
    return verdict != .pass
  }

  private func routeSmartMagnify(_ event: NSEvent) -> Bool {
    [page, canvas].compactMap { $0 }.contains { probe in
      probe.contains(event) && probe.onEvent(.smartMagnify(at: probe.point(of: event)))
    }
  }
}

extension ScrollPhase {
  /// `nil` for events that carry no gesture, such as a mouse wheel or a finger resting on the trackpad.
  init?(_ event: NSEvent) {
    switch event.phase {
    case .began: self = .began
    case .changed: self = .changed
    case .ended: self = .ended
    case .cancelled: self = .cancelled
    default:
      guard !event.momentumPhase.isEmpty else { return nil }
      self = .momentum
    }
  }
}
