import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoLocalizations;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/l10n/app_localization_delegates.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';

/// Framework widgets (dialog buttons, text selection menus) read their
/// built-in text from MaterialLocalizations / CupertinoLocalizations. Those
/// types must be served by delegates from the same library the app's
/// MaterialApp comes from; a MaterialApp wired to another library's delegates
/// leaves every framework label unresolved.
void main() {
  const expected = <String, ({String cancel, String ok, String copy})>{
    'ja': (cancel: 'キャンセル', ok: 'OK', copy: 'コピー'),
    'en': (cancel: 'Cancel', ok: 'OK', copy: 'Copy'),
    'zh': (cancel: '取消', ok: '确定', copy: '复制'),
  };

  expected.forEach((tag, labels) {
    testWidgets('$tag: framework labels resolve under the app delegates', (
      tester,
    ) async {
      late BuildContext captured;
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(tag),
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              captured = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final material = MaterialLocalizations.of(captured);
      expect(material.cancelButtonLabel, labels.cancel);
      expect(material.okButtonLabel, labels.ok);

      final cupertino = CupertinoLocalizations.of(captured);
      expect(cupertino.copyButtonLabel, labels.copy);

      expect(AppLocalizations.of(captured), isNotNull);
    });
  });
}
