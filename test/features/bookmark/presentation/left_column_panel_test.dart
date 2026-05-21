import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/bookmark/presentation/left_column_panel.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/llm_summary/domain/history_entry.dart';
import 'package:novel_viewer/features/llm_summary/providers/llm_summary_history_provider.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';

class _TestCurrentDirectoryNotifier extends CurrentDirectoryNotifier {
  final String? _initialValue;
  _TestCurrentDirectoryNotifier(this._initialValue);

  @override
  String? build() => _initialValue;
}

class _EmptyHistoryNotifier extends LlmSummaryHistoryNotifier {
  @override
  Future<List<HistoryEntry>> build() async => const [];
}

void main() {
  group('LeftColumnPanel', () {
    testWidgets('shows three tabs: ファイル, ブックマーク, 解析履歴',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            libraryPathProvider.overrideWithValue('/library'),
          ],
          child: const MaterialApp(
                locale: Locale('ja'),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(body: LeftColumnPanel())),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ファイル'), findsOneWidget);
      expect(find.text('ブックマーク'), findsOneWidget);
      expect(find.text('解析履歴'), findsOneWidget);
    });

    testWidgets('switching to 解析履歴 tab shows history panel',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            libraryPathProvider.overrideWithValue('/library'),
            currentDirectoryProvider.overrideWith(
                () => _TestCurrentDirectoryNotifier('/library/my_novel')),
            directoryContentsProvider.overrideWith((ref) async {
              return DirectoryContents.empty();
            }),
            llmSummaryHistoryProvider.overrideWith(_EmptyHistoryNotifier.new),
          ],
          child: const MaterialApp(
                locale: Locale('ja'),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(body: LeftColumnPanel())),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('解析履歴'));
      await tester.pumpAndSettle();

      // History panel renders the empty state message because the active
      // folder has no cached summaries in this test setup.
      expect(find.text('解析履歴がありません'), findsOneWidget);
    });

    testWidgets('ファイル tab is selected by default',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            libraryPathProvider.overrideWithValue('/library'),
          ],
          child: const MaterialApp(
                locale: Locale('ja'),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(body: LeftColumnPanel())),
        ),
      );
      await tester.pumpAndSettle();

      // FileBrowserPanel content should be visible
      expect(find.text('フォルダを選択してください'), findsOneWidget);
    });

    testWidgets('switching to ブックマーク tab shows bookmark panel',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            libraryPathProvider.overrideWithValue('/library'),
            currentDirectoryProvider
                .overrideWith(() => _TestCurrentDirectoryNotifier('/library')),
            directoryContentsProvider.overrideWith((ref) async {
              return DirectoryContents.empty();
            }),
          ],
          child: const MaterialApp(
                locale: Locale('ja'),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(body: LeftColumnPanel())),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('ブックマーク'));
      await tester.pumpAndSettle();

      // Should show the bookmark panel placeholder since at library root
      expect(find.text('作品フォルダを選択してください'), findsOneWidget);
    });

    testWidgets(
        'switching back to ファイル tab preserves file browser',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            libraryPathProvider.overrideWithValue('/library'),
          ],
          child: const MaterialApp(
                locale: Locale('ja'),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(body: LeftColumnPanel())),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to bookmark tab
      await tester.tap(find.text('ブックマーク'));
      await tester.pumpAndSettle();

      // Switch back to file tab
      await tester.tap(find.text('ファイル'));
      await tester.pumpAndSettle();

      expect(find.text('フォルダを選択してください'), findsOneWidget);
    });
  });
}
