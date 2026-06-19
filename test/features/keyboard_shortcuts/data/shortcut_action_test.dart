import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/keyboard_shortcuts/data/shortcut_action.dart';
import 'package:novel_viewer/features/keyboard_shortcuts/data/shortcut_intents.dart';

void main() {
  group('ShortcutAction', () {
    test('contains exactly the customizable actions', () {
      expect(
        ShortcutAction.values,
        [
          ShortcutAction.search,
          ShortcutAction.bookmark,
          ShortcutAction.ttsToggle,
          ShortcutAction.switchPane,
        ],
      );
    });

    test('does not include page-navigation (fixed, not customizable)', () {
      final names = ShortcutAction.values.map((a) => a.name).toList();
      expect(names, isNot(contains('nextPage')));
      expect(names, isNot(contains('prevPage')));
    });
  });

  group('Shortcut intents', () {
    test('customizable-action intents are const Intents', () {
      const intents = <Intent>[
        SearchIntent(),
        BookmarkIntent(),
        TtsToggleIntent(),
        SwitchPaneIntent(),
      ];
      expect(intents, everyElement(isA<Intent>()));
    });

    test('page-navigation intents are const Intents', () {
      const intents = <Intent>[
        NextPageIntent(),
        PrevPageIntent(),
      ];
      expect(intents, everyElement(isA<Intent>()));
    });

    test('intentFor maps each ShortcutAction to its Intent', () {
      expect(intentFor(ShortcutAction.search), isA<SearchIntent>());
      expect(intentFor(ShortcutAction.bookmark), isA<BookmarkIntent>());
      expect(intentFor(ShortcutAction.ttsToggle), isA<TtsToggleIntent>());
      expect(intentFor(ShortcutAction.switchPane), isA<SwitchPaneIntent>());
    });
  });
}
