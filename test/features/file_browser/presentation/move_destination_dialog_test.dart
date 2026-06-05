import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/file_browser/domain/move_destination.dart';
import 'package:novel_viewer/features/file_browser/presentation/move_destination_dialog.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';

void main() {
  const destinations = [
    MoveDestination(path: '/library', name: 'library', depth: 0),
    MoveDestination(path: '/library/完結済み', name: '完結済み', depth: 1),
    MoveDestination(path: '/library/完結済み/2024', name: '2024', depth: 2),
  ];

  Future<String?> showDialogAndGet(WidgetTester tester) async {
    String? result;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ja'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  result = await showDialog<String>(
                    context: context,
                    builder: (_) => const MoveDestinationDialog(
                      destinations: destinations,
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('shows the library root and organizational folders',
      (tester) async {
    await showDialogAndGet(tester);

    expect(find.text('ライブラリ（最上位）'), findsOneWidget);
    expect(find.text('完結済み'), findsOneWidget);
    expect(find.text('2024'), findsOneWidget);
  });

  testWidgets('returns the selected destination path', (tester) async {
    String? result;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ja'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  result = await showDialog<String>(
                    context: context,
                    builder: (_) => const MoveDestinationDialog(
                      destinations: destinations,
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('完結済み'));
    await tester.pumpAndSettle();

    expect(result, '/library/完結済み');
  });
}
