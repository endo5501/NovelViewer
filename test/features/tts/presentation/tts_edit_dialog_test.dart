import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/tts/presentation/tts_edit_dialog.dart';

void main() {
  group('ttsEditDialogContentWidth', () {
    test('caps at 1400 on an ultrawide window', () {
      // 3440 * 0.9 - 48 = 3048, well above the cap.
      expect(ttsEditDialogContentWidth(3440), 1400);
    });

    test('caps at 1400 on a typical half-ultrawide working window', () {
      // 1720 * 0.9 - 48 = 1500, still above the cap.
      expect(ttsEditDialogContentWidth(1720), 1400);
    });

    test('follows the window width once below the cap', () {
      // 1200 * 0.9 - 48 = 1032.
      expect(ttsEditDialogContentWidth(1200), 1032);
    });

    test('shrinks on a narrow window so the dialog stays on screen', () {
      // 900 * 0.9 - 48 = 762.
      expect(ttsEditDialogContentWidth(900), 762);
    });

    test('stays just below the cap at the boundary window width', () {
      // The cap starts to apply at (1400 + 48) / 0.9 = 1608.888...
      expect(ttsEditDialogContentWidth(1608), lessThan(1400));
      expect(ttsEditDialogContentWidth(1609), 1400);
    });
  });
}
