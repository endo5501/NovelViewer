import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/app.dart';
import 'package:novel_viewer/app/selected_file_progress_title_provider.dart';
import 'package:novel_viewer/features/app_update/providers/update_providers.dart';
import 'package:novel_viewer/features/file_browser/data/file_system_service.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/reading_progress/providers/reading_progress_providers.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';
import 'package:novel_viewer/features/text_viewer/presentation/widgets/tts_controls_bar.dart';
import 'package:novel_viewer/features/text_viewer/providers/text_viewer_providers.dart';
import 'package:novel_viewer/features/tts/data/tts_audio_database.dart';
import 'package:novel_viewer/features/tts/data/tts_dictionary_database.dart';
import 'package:novel_viewer/features/tts/data/tts_dictionary_repository.dart';
import 'package:novel_viewer/features/tts/data/tts_engine_type.dart';
import 'package:novel_viewer/features/tts/presentation/tts_dictionary_dialog.dart';
import 'package:novel_viewer/features/tts/presentation/tts_edit_dialog.dart';
import 'package:novel_viewer/features/tts/presentation/tts_edit_segment_row.dart';
import 'package:novel_viewer/features/tts/providers/tts_audio_database_provider.dart';
import 'package:novel_viewer/features/tts/providers/tts_audio_state_provider.dart';
import 'package:novel_viewer/features/tts/providers/tts_availability_provider.dart';
import 'package:novel_viewer/features/tts/providers/tts_playback_providers.dart';
import 'package:novel_viewer/features/tts/providers/tts_settings_providers.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../helpers/phone_display.dart';

/// The read-aloud dialogs and the read-aloud controls on the portrait display
/// of an iPhone 16 (spec adaptive-shell-layout: every dialog the app presents
/// fits without layout overflow, and its actions are reachable).
void main() {
  late SharedPreferences prefs;
  late AppLocalizations l10n;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    l10n = await AppLocalizations.delegate.load(const Locale('ja'));
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  /// Fails unless [finder]'s widget lies wholly inside the part of the phone
  /// display the safe area leaves visible and tappable.
  void expectOnScreen(WidgetTester tester, Finder finder, String what) {
    expect(finder, findsOneWidget, reason: what);
    final rect = tester.getRect(finder);
    const visible = Rect.fromLTRB(
      0,
      kPhoneTopInset,
      393,
      852 - kPhoneBottomInset,
    );
    expect(
      rect.left >= visible.left &&
          rect.right <= visible.right &&
          rect.top >= visible.top &&
          rect.bottom <= visible.bottom,
      isTrue,
      reason: '$what at $rect is outside the visible area $visible',
    );
  }

  /// The button whose label is [label], inside [scope].
  Finder buttonLabelled(Finder scope, String label) => find.ancestor(
    of: find.descendant(of: scope, matching: find.text(label)),
    matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
  );

  Finder topDialog() => find.byType(AlertDialog).last;

  // ---------------------------------------------------------------------------
  // TTS edit dialog
  // ---------------------------------------------------------------------------

  group('TtsEditDialog', () {
    late Directory tempDir;
    late TtsAudioDatabase audioDb;
    late TtsDictionaryDatabase dictDb;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('tts_edit_phone_test_');
      audioDb = TtsAudioDatabase(tempDir.path);
      dictDb = TtsDictionaryDatabase(tempDir.path);
      // ensureTemporaryDirectory goes through path_provider.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (call) async => tempDir.path,
          );
    });

    tearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            null,
          );
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    const content =
        '　王都から馬車で三日、辺境伯領のさらに奥にあるトルネ村に、私は薬師として赴任することになった。'
        '「本当にこんな所でいいのかい、エリシア嬢ちゃん。魔の森まで歩いて半日もかからないんだよ」'
        '　御者のおじさんが心配そうに振り返ったけれど、私は笑って首を振った。'
        '　――のんびり暮らせるなら、それでいい。前世の私は、働きすぎて死んだのだから。';

    /// Opens the edit dialog the way the controls bar does, on the Piper
    /// engine iOS runs, and waits for its segments to load.
    Future<void> openEditDialog(
      WidgetTester tester, {
      TtsEngineType engine = TtsEngineType.piper,
    }) async {
      usePhoneDisplay(tester);
      SharedPreferences.setMockInitialValues({'tts_engine_type': engine.name});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            packageInfoProvider.overrideWithValue(
              PackageInfo(
                appName: 'NovelViewer',
                packageName: 'com.example.novelViewer',
                version: '1.8.2',
                buildNumber: '41',
              ),
            ),
            sharedPreferencesProvider.overrideWithValue(prefs),
            libraryPathProvider.overrideWithValue(tempDir.parent.path),
            supportedTtsEnginesProvider.overrideWithValue(const [
              TtsEngineType.piper,
              TtsEngineType.irodori,
            ]),
            ttsAudioDatabaseProvider.overrideWith((ref, _) => audioDb),
            ttsDictionaryDatabaseProvider.overrideWith((ref, _) => dictDb),
            voiceFilesProvider.overrideWith(
              (ref) async => const ['エリシア_落ち着いた語り口_長め.wav'],
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('ja'),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => TtsEditDialog.show(
                    context,
                    folderPath: tempDir.path,
                    fileName: '049-転生したら辺境の村の薬師だったので、のんびり暮らしたいと思います.txt',
                    content: content,
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      // Unmount the dialog while real async work can still run, so its
      // controller (audio player, temporary files) is disposed for real. The databases
      // stay open: their handles belong to this test's fake-async zone, and
      // closing them from outside it never completes.
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 300)),
        );
      });
      await tester.tap(find.text('open'));
      // The databases and the temporary directory do real I/O, which the
      // fake-async zone of a widget test never completes.
      for (var i = 0; i < 40; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
        final loading = find.descendant(
          of: find.byType(TtsEditDialog),
          matching: find.byType(CircularProgressIndicator),
        );
        if (loading.evaluate().isEmpty) break;
      }
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.descendant(
          of: find.byType(TtsEditDialog),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsNothing,
        reason: 'the edit dialog did not finish loading its segments',
      );
    }

    /// Presses the button labelled [label] in the edit dialog's toolbar
    /// without depending on it being on screen: whether it is, is what the
    /// edit dialog's own test checks.
    Future<void> pressToolbarButton(WidgetTester tester, String label) async {
      final button = buttonLabelled(find.byType(TtsEditDialog), label);
      tester.widget<ButtonStyleButton>(button.first).onPressed!();
      for (var i = 0; i < 10; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
      await tester.pump(const Duration(milliseconds: 300));
    }

    for (final engine in const [TtsEngineType.piper, TtsEngineType.irodori]) {
      testWidgets('fits, with its toolbar, rows and close button on screen '
          '(${engine.label})', (tester) async {
        await openEditDialog(tester, engine: engine);

        final dialog = find.byType(TtsEditDialog);
        for (final label in [
          l10n.ttsEdit_dictionaryButton,
          l10n.ttsEdit_playButton,
          l10n.ttsEdit_generateAllButton,
          l10n.ttsEdit_resetAllButton,
          l10n.common_closeButton,
        ]) {
          expectOnScreen(tester, buttonLabelled(dialog, label), label);
        }

        final firstRow = find.byType(TtsEditSegmentRow).first;
        expect(firstRow, findsOneWidget, reason: 'no segment rows built');
        for (final tooltip in [
          l10n.ttsEdit_playTooltip,
          l10n.ttsEdit_regenerateTooltip,
          l10n.ttsEdit_resetTooltip,
        ]) {
          expectOnScreen(
            tester,
            find.descendant(of: firstRow, matching: find.byTooltip(tooltip)),
            'first row: $tooltip',
          );
        }
      });
    }

    testWidgets('the reset-all confirmation fits, its actions on screen', (
      tester,
    ) async {
      await openEditDialog(tester);
      // The edit dialog's own overflow is reported by the test above.
      tester.takeException();

      await pressToolbarButton(tester, l10n.ttsEdit_resetAllButton);

      expect(find.text(l10n.ttsEdit_resetAllConfirmation), findsOneWidget);
      final confirm = topDialog();
      expectOnScreen(
        tester,
        buttonLabelled(confirm, l10n.common_cancelButton),
        'cancel',
      );
      expectOnScreen(
        tester,
        buttonLabelled(confirm, l10n.ttsEdit_resetButton),
        'reset',
      );
    });

    testWidgets('the dictionary opened from it fits, its actions on screen', (
      tester,
    ) async {
      await openEditDialog(tester);
      // The edit dialog's own overflow is reported by the first test.
      tester.takeException();

      await pressToolbarButton(tester, l10n.ttsEdit_dictionaryButton);

      final dictionary = find.byType(TtsDictionaryDialog);
      expect(dictionary, findsOneWidget);
      expectOnScreen(
        tester,
        buttonLabelled(dictionary, l10n.common_closeButton),
        'close',
      );
      expectOnScreen(
        tester,
        find.descendant(of: dictionary, matching: find.byIcon(Icons.add)),
        'add',
      );
    });
  });

  // ---------------------------------------------------------------------------
  // TTS dictionary dialog
  // ---------------------------------------------------------------------------

  group('TtsDictionaryDialog', () {
    Future<void> openDictionary(
      WidgetTester tester, {
      String? initialSurface,
    }) async {
      usePhoneDisplay(tester);
      final repository = _InMemoryDictionaryRepository()
        ..entries.addAll(const [
          TtsDictionaryEntry(
            id: 1,
            surface: 'エリシア・フォン・アーデルハイト＝トルネ辺境伯令嬢',
            reading: 'えりしあふぉんあーでるはいととるねへんきょうはくれいじょう',
          ),
          TtsDictionaryEntry(id: 2, surface: '――‐――‐――‐――', reading: ''),
          TtsDictionaryEntry(id: 3, surface: '魔の森', reading: 'まのもり'),
        ]);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('ja'),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => TtsDictionaryDialog.show(
                    context,
                    repository: repository,
                    initialSurface: initialSurface,
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    void expectActionsOnScreen(WidgetTester tester) {
      final dictionary = find.byType(TtsDictionaryDialog);
      expectOnScreen(
        tester,
        buttonLabelled(dictionary, l10n.common_closeButton),
        'close',
      );
      expectOnScreen(
        tester,
        find.descendant(of: dictionary, matching: find.byIcon(Icons.add)),
        'add',
      );
      expectOnScreen(
        tester,
        find.descendant(of: dictionary, matching: find.byType(Checkbox)),
        'no-reading checkbox',
      );
      for (final field
          in find
              .descendant(of: dictionary, matching: find.byType(TextField))
              .evaluate()) {
        expectOnScreen(
          tester,
          find.byWidget(field.widget),
          'text field "${(field.widget as TextField).decoration?.labelText}"',
        );
      }
    }

    testWidgets('fits with long entries, its actions on screen', (
      tester,
    ) async {
      await openDictionary(tester);

      expectActionsOnScreen(tester);
    });

    testWidgets('fits with a long surface prefilled from the text', (
      tester,
    ) async {
      await openDictionary(
        tester,
        initialSurface: 'アーデルハイト＝トルネ辺境伯領第三騎士団副団長代理補佐',
      );

      expectActionsOnScreen(tester);
    });

    testWidgets('fits while showing the both-fields-required error', (
      tester,
    ) async {
      await openDictionary(tester);

      await tester.tap(
        find.descendant(
          of: find.byType(TtsDictionaryDialog),
          matching: find.byIcon(Icons.add),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(l10n.ttsDictionary_bothFieldsRequired), findsOneWidget);
      expectActionsOnScreen(tester);
    });
  });

  // ---------------------------------------------------------------------------
  // TTS controls bar, in the home screen's text pane
  // ---------------------------------------------------------------------------

  group('TtsControlsBar', () {
    const longTitle = '転生したら辺境の村の薬師だったので、のんびり暮らしたいと思います — 049-戦闘.txt (49/200)';
    const episode = FileEntry(
      name: '049-戦闘.txt',
      path: '/library/n1234/049-戦闘.txt',
    );

    /// The whole app with a file open, the way the bar is placed over the text
    /// on iOS: TTS supported, MP3 export not.
    Future<ProviderContainer> pumpHomeWithBar(
      WidgetTester tester, {
      required TtsAudioState audioState,
      required TtsPlaybackState playbackState,
    }) async {
      usePhoneDisplay(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            libraryPathProvider.overrideWithValue('/library'),
            readingProgressStartupProvider.overrideWith(
              (ref) => Completer<void>().future,
            ),
            selectedFileProgressTitleProvider.overrideWithValue(longTitle),
            fileContentProvider.overrideWith(
              (ref) async => List.filled(40, '　吾輩は猫である。名前はまだ無い。').join('\n'),
            ),
            ttsSupportedProvider.overrideWithValue(true),
            ttsAudioExportSupportedProvider.overrideWithValue(false),
            ttsModelDirProvider.overrideWith((ref) => '/models/piper'),
            ttsAudioStateProvider.overrideWith((ref, _) async => audioState),
          ],
          child: const NovelViewerApp(),
        ),
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(NovelViewerApp)),
      );
      container.read(selectedFileProvider.notifier).rebase(episode);
      await tester.pump();
      await tester.pump();
      container.read(ttsPlaybackStateProvider.notifier).set(playbackState);
      // The waiting and generating states spin forever; settle by hand.
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(TtsControlsBar), findsOneWidget);
      return container;
    }

    void expectEveryButtonOnScreen(WidgetTester tester) {
      final buttons = find.descendant(
        of: find.byType(TtsControlsBar),
        matching: find.byType(FloatingActionButton),
      );
      expect(buttons, findsWidgets);
      for (final element in buttons.evaluate()) {
        final fab = element.widget as FloatingActionButton;
        expectOnScreen(tester, find.byWidget(fab), 'button "${fab.tooltip}"');
      }
    }

    for (final (audio, playback) in const [
      (TtsAudioState.none, TtsPlaybackState.stopped),
      (TtsAudioState.ready, TtsPlaybackState.stopped),
      (TtsAudioState.ready, TtsPlaybackState.waiting),
      (TtsAudioState.generating, TtsPlaybackState.waiting),
      (TtsAudioState.generating, TtsPlaybackState.paused),
    ]) {
      testWidgets('fits at the phone width with its buttons on screen '
          '(${audio.name}, ${playback.name})', (tester) async {
        await pumpHomeWithBar(
          tester,
          audioState: audio,
          playbackState: playback,
        );

        expectEveryButtonOnScreen(tester);
      });
    }

    testWidgets('the delete-audio confirmation fits, its actions on screen', (
      tester,
    ) async {
      await pumpHomeWithBar(
        tester,
        audioState: TtsAudioState.ready,
        playbackState: TtsPlaybackState.stopped,
      );

      tester
          .widget<FloatingActionButton>(
            find.ancestor(
              of: find.byIcon(Icons.delete_outline),
              matching: find.byType(FloatingActionButton),
            ),
          )
          .onPressed!();
      await tester.pumpAndSettle();

      expect(
        find.text(l10n.textViewer_deleteAudioConfirmation),
        findsOneWidget,
      );
      final confirm = topDialog();
      expectOnScreen(
        tester,
        buttonLabelled(confirm, l10n.common_cancelButton),
        'cancel',
      );
      expectOnScreen(
        tester,
        buttonLabelled(confirm, l10n.common_deleteButton),
        'delete',
      );
    });
  });
}

/// In-memory stand-in for the dictionary repository: the real one talks to
/// sqflite, whose futures never complete in a widget test's fake-async zone.
class _InMemoryDictionaryRepository implements TtsDictionaryRepository {
  final entries = <TtsDictionaryEntry>[];
  var _nextId = 100;

  @override
  Future<int> addEntry(String surface, String reading) async {
    if (entries.any((e) => e.surface == surface)) {
      throw StateError('duplicate surface');
    }
    final id = _nextId++;
    entries.add(TtsDictionaryEntry(id: id, surface: surface, reading: reading));
    return id;
  }

  @override
  Future<List<TtsDictionaryEntry>> getAllEntries() async => List.of(entries);

  @override
  Future<List<TtsDictionaryEntry>> getEntriesSortedByLength() async =>
      List.of(entries)
        ..sort((a, b) => b.surface.length.compareTo(a.surface.length));

  @override
  Future<void> updateEntry(int id, String surface, String reading) async {}

  @override
  Future<void> deleteEntry(int id) async {
    entries.removeWhere((e) => e.id == id);
  }

  @override
  Future<String> applyDictionary(String text) async =>
      TtsDictionaryRepository.applyDictionaryWithEntries(
        await getEntriesSortedByLength(),
        text,
      );
}
