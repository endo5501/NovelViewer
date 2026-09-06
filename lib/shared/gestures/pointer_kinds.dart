import 'package:flutter/gestures.dart';

/// The pointer kinds that have no secondary button.
///
/// A context menu whose only trigger is a secondary tap is unreachable from
/// these, so they are the ones a touch trigger exists for — and, conversely,
/// the only ones it should apply to. A mouse already has the secondary button,
/// so extending a long press or a tap to it takes an existing meaning away
/// (activating the tile, clearing the selection) without adding any reach.
///
/// `PointerDeviceKind.trackpad` is absent because a trackpad's clicks arrive
/// as `mouse`; the kind itself is only used for trackpad pan and zoom
/// gestures. `PointerDeviceKind.unknown` is absent because a platform
/// reporting a real mouse that way would silently lose the behaviour being
/// replaced, and a mouse can always reach the menu with its secondary button.
const kNoSecondaryButtonPointerKinds = <PointerDeviceKind>{
  PointerDeviceKind.touch,
  PointerDeviceKind.stylus,
  PointerDeviceKind.invertedStylus,
};
