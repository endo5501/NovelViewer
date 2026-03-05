import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/file_browser/presentation/rename_title_dialog.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';

void main() {
  group('RenameTitleDialog', () {
    testWidgets('shows current title prefilled in text field',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
              locale: Locale('ja'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: RenameTitleDialog(currentTitle: 'テスト小説'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, 'テスト小説');
    });

    testWidgets('submit button is enabled when text is non-empty',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
              locale: Locale('ja'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: RenameTitleDialog(currentTitle: 'テスト小説'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final button = tester.widget<TextButton>(
        find.widgetWithText(TextButton, '変更'),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('submit button is disabled when text is empty',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
              locale: Locale('ja'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: RenameTitleDialog(currentTitle: 'テスト小説'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Clear the text field
      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();

      final button = tester.widget<TextButton>(
        find.widgetWithText(TextButton, '変更'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('submit button is disabled when text is whitespace only',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
              locale: Locale('ja'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: RenameTitleDialog(currentTitle: 'テスト小説'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '   ');
      await tester.pumpAndSettle();

      final button = tester.widget<TextButton>(
        find.widgetWithText(TextButton, '変更'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('submit returns trimmed title',
        (WidgetTester tester) async {
      String? result;

      await tester.pumpWidget(
        MaterialApp(
              locale: const Locale('ja'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  result = await showDialog<String>(
                    context: context,
                    builder: (_) =>
                        const RenameTitleDialog(currentTitle: 'テスト小説'),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '  新しいタイトル  ');
      await tester.pumpAndSettle();

      await tester.tap(find.text('変更'));
      await tester.pumpAndSettle();

      expect(result, '新しいタイトル');
    });

    testWidgets('cancel button closes dialog and returns null',
        (WidgetTester tester) async {
      String? result = 'initial';

      await tester.pumpWidget(
        MaterialApp(
              locale: const Locale('ja'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  result = await showDialog<String>(
                    context: context,
                    builder: (_) =>
                        const RenameTitleDialog(currentTitle: 'テスト小説'),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('キャンセル'));
      await tester.pumpAndSettle();

      expect(result, isNull);
    });

    testWidgets('submit returns new title',
        (WidgetTester tester) async {
      String? result;

      await tester.pumpWidget(
        MaterialApp(
              locale: const Locale('ja'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  result = await showDialog<String>(
                    context: context,
                    builder: (_) =>
                        const RenameTitleDialog(currentTitle: 'テスト小説'),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '新しいタイトル');
      await tester.pumpAndSettle();

      await tester.tap(find.text('変更'));
      await tester.pumpAndSettle();

      expect(result, '新しいタイトル');
    });
  });
}
