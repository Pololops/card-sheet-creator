/// Where a two-finger scroll is in its life, whatever the device sent to say so.
enum ScrollPhase: Equatable {
  case began
  case changed
  case ended
  case cancelled
  /// The glide that follows a lifted gesture.
  case momentum
}

enum ScrollVerdict: Equatable {
  /// Not ours: the scroll view gets the event.
  case pass
  /// Ours: handle the event and keep it from the scroll view.
  case deliver
  /// Ours, but nothing left to handle: keep it from the scroll view.
  case swallow
}

/// Decides once, when the fingers land, whether a scroll gesture belongs to us, and keeps it that way until
/// the glide that follows it dies. Asking again mid-gesture would hand the page over to a slot, or a slot
/// back to the page, halfway through one swipe.
struct ScrollGestureGate {
  private var isOwning = false
  private var isSwallowingMomentum = false

  /// `claim` is only asked at `.began`.
  mutating func verdict(for phase: ScrollPhase, claim: () -> Bool) -> ScrollVerdict {
    switch phase {
    case .began:
      isSwallowingMomentum = false
      isOwning = claim()
      return isOwning ? .deliver : .pass
    case .changed:
      return isOwning ? .deliver : .pass
    case .ended:
      return release(swallowingMomentum: true)
    case .cancelled:
      return release(swallowingMomentum: false)
    case .momentum:
      return isSwallowingMomentum ? .swallow : .pass
    }
  }

  private mutating func release(swallowingMomentum: Bool) -> ScrollVerdict {
    defer {
      isSwallowingMomentum = isOwning && swallowingMomentum
      isOwning = false
    }
    return isOwning ? .deliver : .pass
  }
}
