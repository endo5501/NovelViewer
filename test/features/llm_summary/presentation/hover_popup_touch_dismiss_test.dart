import 'package:flutter/gestures.dart';
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

/// A pointer that does not hover never leaves the popup's `MouseRegion`, so
/// the popup a finger opens has no way out. These tests cover the way out:
/// a touch that lands anywhere else takes it down, without taking the touch
/// away from whatever it landed on.
class _MockDisplayMode extends DisplayModeNotifier {
  @override
  TextDisplayMode build() => TextDisplayMode.horizontal;
}

class _MockSelectedFile extends SelectedFileNotifier {
  @override
  FileEntry? build() => const FileEntry(name: '001.txt', path: '/lib/001.txt');
}

const _aliceKey = (folderPath: '/library/novel_a', word: 'アリス');

ProviderContainer _makeContainer() => ProviderContainer(
  overrides: [
    displayModeProvider.overrideWith(_MockDisplayMode.new),
    currentDirectoryProvider.overrideWith(
      () => CurrentDirectoryNotifier('/library/novel_a'),
    ),
    selectedFileProvider.overrideWith(_MockSelectedFile.new),
    hoverPopupCacheProvider(_aliceKey).overrideWith(
      (_) async => [
        WordSummary(
          word: 'アリス',
          coveredUpToEpisode: 1,
          summary: 'アリスは旅人です。',
          sourceFile: '001.txt',
          createdAt: DateTime.parse('2026-05-24T10:00:00Z'),
          updatedAt: DateTime.parse('2026-05-24T10:00:00Z'),
        ),
      ],
    ),
    llmSummaryRepositoryProvider.overrideWith(
      (ref, folderPath) async => throw UnsupportedError('not used here'),
    ),
  ],
);

void main() {
  late ProviderContainer container;
  late int buttonPresses;

  setUp(() {
    container = _makeContainer();
    buttonPresses = 0;
  });
  tearDown(() => container.dispose());

  Future<void> pumpHost(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('ja'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: HoverPopupHost(
              child: Align(
                alignment: Alignment.bottomLeft,
                child: ElevatedButton(
                  onPressed: () => buttonPresses++,
                  child: const Text('下のボタン'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> showPopup(WidgetTester tester) async {
    container
        .read(hoverPopupProvider.notifier)
        .show(
          word: 'アリス',
          position: const Offset(300, 200),
          token: (start: 0, end: 3),
        );
    await tester.pumpAndSettle();
    expect(find.byType(HoverPopupWidget), findsOneWidget);
  }

  testWidgets('a touch outside the popup dismisses it', (tester) async {
    await pumpHost(tester);
    await showPopup(tester);

    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    expect(container.read(hoverPopupProvider).isVisible, isFalse);
    expect(find.byType(HoverPopupWidget), findsNothing);
  });

  testWidgets('a touch inside the popup keeps it visible', (tester) async {
    await pumpHost(tester);
    await showPopup(tester);

    await tester.tap(find.text('アリスは旅人です。'));
    await tester.pumpAndSettle();

    expect(container.read(hoverPopupProvider).isVisible, isTrue);
  });

  testWidgets('the dismissing touch still reaches what it landed on', (
    tester,
  ) async {
    await pumpHost(tester);
    await showPopup(tester);

    await tester.tap(find.text('下のボタン'));
    await tester.pumpAndSettle();

    expect(buttonPresses, 1, reason: 'the barrier must not absorb the touch');
    expect(container.read(hoverPopupProvider).isVisible, isFalse);
  });

  testWidgets('a mouse press outside the popup does not dismiss it', (
    tester,
  ) async {
    // A mouse dismisses by leaving the popup, and a click that also dismissed
    // would take the popup down while the pointer was still inside it.
    await pumpHost(tester);
    await showPopup(tester);

    final mouse = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
      buttons: kPrimaryMouseButton,
    );
    await mouse.addPointer(location: const Offset(20, 20));
    addTearDown(mouse.removePointer);
    await tester.pump();
    await mouse.down(const Offset(20, 20));
    await mouse.up();
    await tester.pumpAndSettle();

    expect(container.read(hoverPopupProvider).isVisible, isTrue);
  });

  testWidgets('a touch does not dismiss while a child menu is open', (
    tester,
  ) async {
    // The re-analysis dropdown is a modal route of its own, so its own
    // barrier normally takes the touch first. Guarding here as well keeps
    // the popup from depending on the order of two overlays.
    await pumpHost(tester);
    await showPopup(tester);

    container.read(hoverPopupProvider.notifier).onChildMenuOpen();
    await tester.pump();

    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    expect(container.read(hoverPopupProvider).isVisible, isTrue);
  });
}
