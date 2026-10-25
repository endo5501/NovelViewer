import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// The portrait display of an iPhone 16, in logical pixels.
const Size kPhoneDisplaySize = Size(393, 852);

/// The safe-area insets an iPhone 16 reports in portrait: the status bar and
/// Dynamic Island above, the home indicator below.
const double kPhoneTopInset = 59;
const double kPhoneBottomInset = 34;

const double _phoneDevicePixelRatio = 3;

/// Makes the test view the portrait display of an iPhone 16, with its
/// safe-area insets, and puts the view back when the test ends.
///
/// The view is sized in physical pixels at the phone's own pixel ratio, so the
/// layout sees the same logical size and insets the phone gives it. A layout
/// overflow is reported as an exception by the test framework, so a test only
/// has to pump the surface under this display to find one.
void usePhoneDisplay(WidgetTester tester) {
  tester.view.devicePixelRatio = _phoneDevicePixelRatio;
  tester.view.physicalSize = kPhoneDisplaySize * _phoneDevicePixelRatio;
  const padding = FakeViewPadding(
    top: kPhoneTopInset * _phoneDevicePixelRatio,
    bottom: kPhoneBottomInset * _phoneDevicePixelRatio,
  );
  tester.view.padding = padding;
  tester.view.viewPadding = padding;
  addTearDown(tester.view.reset);
}

/// The height of the iPhone 16's software keyboard in portrait, with its
/// predictive-text bar, in logical pixels.
const double kPhoneKeyboardHeight = 336;

/// Raises the software keyboard on the phone display, as iOS reports it: the
/// keyboard is a bottom view inset, and the home-indicator inset it covers is
/// no longer padding.
void showPhoneKeyboard(WidgetTester tester) {
  tester.view.viewInsets = const FakeViewPadding(
    bottom: kPhoneKeyboardHeight * _phoneDevicePixelRatio,
  );
  tester.view.padding = const FakeViewPadding(
    top: kPhoneTopInset * _phoneDevicePixelRatio,
  );
}
