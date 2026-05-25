import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/file_browser/data/file_system_service.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/llm_summary/domain/llm_summary_result.dart';
import 'package:novel_viewer/features/llm_summary/presentation/hover_popup_host.dart';
import 'package:novel_viewer/features/llm_summary/presentation/hover_popup_widget.dart';
import 'package:novel_viewer/features/llm_summary/providers/hover_popup_cache_provider.dart';
import 'package:novel_viewer/features/llm_summary/providers/hover_popup_provider.dart';
import 'package:novel_viewer/features/llm_summary/providers/llm_summary_providers.dart';
import 'package:novel_viewer/features/settings/data/text_display_mode.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';

class _MockDisplayMode extends DisplayModeNotifier {
  _MockDisplayMode(this._initial);
  final TextDisplayMode _initial;

  @override
  TextDisplayMode build() => _initial;

  void set(TextDisplayMode mode) => state = mode;
}

class _MockSelectedFile extends SelectedFileNotifier {
  _MockSelectedFile(this._initial);
  final FileEntry? _initial;

  @override
  FileEntry? build() => _initial;
}

WordSummary _snapshot(int episode, String text) => WordSummary(
      folderName: 'novel_a',
      word: 'アリス',
      coveredUpToEpisode: episode,
      summary: text,
      sourceFile: '${episode.toString().padLeft(3, '0')}.txt',
      createdAt: DateTime.parse('2026-05-24T10:00:00Z'),
      updatedAt: DateTime.parse('2026-05-24T10:00:00Z'),
    );

const _aliceKey = (folder: 'novel_a', word: 'アリス');

ProviderContainer _makeContainer({
  TextDisplayMode mode = TextDisplayMode.horizontal,
  String directory = '/library/novel_a',
  FileEntry? selectedFile,
}) {
  final container = ProviderContainer(overrides: [
    displayModeProvider.overrideWith(() => _MockDisplayMode(mode)),
    currentDirectoryProvider
        .overrideWith(() => CurrentDirectoryNotifier(directory)),
    selectedFileProvider.overrideWith(() => _MockSelectedFile(selectedFile)),
    hoverPopupCacheProvider(_aliceKey).overrideWith(
      (_) async => [_snapshot(1, 'なし本文')],
    ),
    llmSummaryRepositoryProvider.overrideWith(
      (_) async => throw UnsupportedError('not used in this test'),
    ),
  ]);
  return container;
}

Widget _wrap(ProviderContainer container, Widget child) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      locale: const Locale('ja'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  group('HoverPopupHost', () {
    testWidgets('initially shows no popup', (tester) async {
      final container = _makeContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(_wrap(
        container,
        const HoverPopupHost(child: SizedBox.expand()),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(HoverPopupWidget), findsNothing);
    });

    testWidgets('inserts popup into the overlay when the notifier shows it',
        (tester) async {
      final container = _makeContainer(
        selectedFile: const FileEntry(name: '001.txt', path: '/lib/001.txt'),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(_wrap(
        container,
        const HoverPopupHost(child: SizedBox.expand()),
      ));

      container.read(hoverPopupProvider.notifier).show(
            word: 'アリス',
            position: const Offset(100, 200),
            token: (start: 0, end: 3),
          );
      await tester.pumpAndSettle();

      expect(find.byType(HoverPopupWidget), findsOneWidget);
    });

    testWidgets('removes the popup when the notifier hides it', (tester) async {
      final container = _makeContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(_wrap(
        container,
        const HoverPopupHost(child: SizedBox.expand()),
      ));

      container.read(hoverPopupProvider.notifier).show(
            word: 'アリス',
            position: const Offset(100, 200),
            token: (start: 0, end: 3),
          );
      await tester.pumpAndSettle();
      expect(find.byType(HoverPopupWidget), findsOneWidget);

      container.read(hoverPopupProvider.notifier).hide();
      await tester.pumpAndSettle();
      expect(find.byType(HoverPopupWidget), findsNothing);
    });
  });
}
