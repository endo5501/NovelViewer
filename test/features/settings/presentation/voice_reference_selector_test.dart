import 'dart:io';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/settings/presentation/settings_dialog.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';
import 'package:path/path.dart' as p;

void main() {
  late SharedPreferences prefs;
  late Directory tempDir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    tempDir = Directory.systemTemp.createTempSync('voice_ref_ui_test_');
    Directory(p.join(tempDir.path, 'NovelViewer')).createSync();
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  Widget buildTestWidget() {
    final libraryPath = p.join(tempDir.path, 'NovelViewer');
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        libraryPathProvider.overrideWithValue(libraryPath),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 600,
            child: SettingsDialog(),
          ),
        ),
      ),
    );
  }

  Future<void> navigateToTtsTab(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.runAsync(() async {
      await tester.pumpWidget(buildTestWidget());
    });
    await tester.pumpAndSettle();
    await tester.tap(find.text('読み上げ'));
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 200)));
    await tester.pumpAndSettle();
  }

  group('Voice reference selector', () {
    testWidgets('displays voice reference dropdown on TTS tab', (tester) async {
      await navigateToTtsTab(tester);

      expect(find.text('リファレンス音声ファイル'), findsOneWidget);
      expect(find.text('なし（デフォルト音声）'), findsOneWidget);
    });

    testWidgets('shows hint when voices directory is empty', (tester) async {
      await navigateToTtsTab(tester);

      expect(find.text('なし（デフォルト音声）'), findsOneWidget);
    });

    testWidgets('lists audio files from voices directory', (tester) async {
      final voicesDir = Directory(p.join(tempDir.path, 'voices'));
      voicesDir.createSync();
      File(p.join(voicesDir.path, 'narrator.mp3')).writeAsStringSync('');
      File(p.join(voicesDir.path, 'sample.wav')).writeAsStringSync('');

      await navigateToTtsTab(tester);

      // Open dropdown - tap the current value text to open
      final dropdown = find.byType(DropdownButtonFormField<String>);
      expect(dropdown, findsOneWidget);
      await tester.tap(dropdown);
      await tester.pumpAndSettle();

      // Dropdown items appear in an overlay
      expect(find.text('narrator.mp3'), findsWidgets);
      expect(find.text('sample.wav'), findsWidgets);
    });

    testWidgets('displays folder open and refresh buttons', (tester) async {
      await navigateToTtsTab(tester);

      expect(find.byTooltip('voicesフォルダを開く'), findsOneWidget);
      expect(find.byTooltip('ファイル一覧を更新'), findsOneWidget);
    });

    testWidgets('refresh button rescans voices directory', (tester) async {
      await navigateToTtsTab(tester);

      // Add a file to voices dir
      final voicesDir = Directory(p.join(tempDir.path, 'voices'));
      if (!voicesDir.existsSync()) voicesDir.createSync();
      File(p.join(voicesDir.path, 'test_voice.wav')).writeAsStringSync('');

      // Tap refresh inside runAsync so file I/O completes
      await tester.runAsync(() async {
        await tester.tap(find.byTooltip('ファイル一覧を更新'));
        await tester.pump();
        await Future.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();

      // Open dropdown
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();

      expect(find.text('test_voice.wav'), findsWidgets);
    });

    testWidgets('selecting a file persists the file name', (tester) async {
      final voicesDir = Directory(p.join(tempDir.path, 'voices'));
      voicesDir.createSync();
      File(p.join(voicesDir.path, 'my_voice.wav')).writeAsStringSync('');

      await navigateToTtsTab(tester);

      // Open dropdown and select file
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('my_voice.wav').last);
      await tester.pumpAndSettle();

      expect(prefs.getString('tts_ref_wav_path'), 'my_voice.wav');
    });

    testWidgets('shows default when saved file no longer exists',
        (tester) async {
      await prefs.setString('tts_ref_wav_path', 'deleted_file.wav');
      Directory(p.join(tempDir.path, 'voices')).createSync();

      await navigateToTtsTab(tester);

      expect(find.text('なし（デフォルト音声）'), findsOneWidget);
    });
  });

  group('Drop zone', () {
    testWidgets('voice reference selector is wrapped in DropTarget',
        (tester) async {
      await navigateToTtsTab(tester);

      expect(find.byType(DropTarget), findsOneWidget);
    });
  });

  group('Rename button', () {
    testWidgets('rename button is hidden when no file is selected',
        (tester) async {
      final voicesDir = Directory(p.join(tempDir.path, 'voices'));
      voicesDir.createSync();

      await navigateToTtsTab(tester);

      expect(find.byTooltip('ファイル名を変更'), findsNothing);
    });

    testWidgets('rename button is shown when a file is selected',
        (tester) async {
      final voicesDir = Directory(p.join(tempDir.path, 'voices'));
      voicesDir.createSync();
      File(p.join(voicesDir.path, 'my_voice.wav')).writeAsStringSync('');

      await prefs.setString('tts_ref_wav_path', 'my_voice.wav');

      await navigateToTtsTab(tester);

      expect(find.byTooltip('ファイル名を変更'), findsOneWidget);
    });
  });

  group('Rename dialog', () {
    Future<void> openRenameDialog(WidgetTester tester) async {
      final voicesDir = Directory(p.join(tempDir.path, 'voices'));
      voicesDir.createSync();
      File(p.join(voicesDir.path, 'my_voice.wav')).writeAsStringSync('');
      await prefs.setString('tts_ref_wav_path', 'my_voice.wav');

      await navigateToTtsTab(tester);
      await tester.tap(find.byTooltip('ファイル名を変更'));
      await tester.pumpAndSettle();
    }

    testWidgets('rename dialog shows current file name without extension',
        (tester) async {
      await openRenameDialog(tester);

      expect(find.text('ファイル名の変更'), findsOneWidget);
      // Text field should contain the name without extension
      final textField = tester.widget<TextField>(find.byType(TextField).last);
      expect(textField.controller?.text, 'my_voice');
      // Extension label should be visible
      expect(find.text('.wav'), findsOneWidget);
    });

    testWidgets('rename dialog cancel does not rename file',
        (tester) async {
      await openRenameDialog(tester);

      await tester.tap(find.text('キャンセル'));
      await tester.pumpAndSettle();

      // Dialog should be closed
      expect(find.text('ファイル名の変更'), findsNothing);
      // File should still exist with original name
      final voicesDir = Directory(p.join(tempDir.path, 'voices'));
      expect(File(p.join(voicesDir.path, 'my_voice.wav')).existsSync(), isTrue);
    });

    testWidgets('rename dialog confirms and renames file',
        (tester) async {
      await openRenameDialog(tester);

      // Clear and type new name
      final textField = find.byType(TextField).last;
      await tester.enterText(textField, 'renamed_voice');
      await tester.pumpAndSettle();

      await tester.runAsync(() async {
        await tester.tap(find.text('変更'));
        await tester.pump();
        await Future.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();

      // File should be renamed
      final voicesDir = Directory(p.join(tempDir.path, 'voices'));
      expect(File(p.join(voicesDir.path, 'my_voice.wav')).existsSync(), isFalse);
      expect(
          File(p.join(voicesDir.path, 'renamed_voice.wav')).existsSync(), isTrue);
      // Setting should be updated
      expect(prefs.getString('tts_ref_wav_path'), 'renamed_voice.wav');
    });

    testWidgets('rename dialog disables confirm when name already exists',
        (tester) async {
      final voicesDir = Directory(p.join(tempDir.path, 'voices'));
      voicesDir.createSync();
      File(p.join(voicesDir.path, 'existing.wav')).writeAsStringSync('');

      await openRenameDialog(tester);

      // Type a name that already exists (without extension)
      final textField = find.byType(TextField).last;
      await tester.enterText(textField, 'existing');
      await tester.pumpAndSettle();

      // Error message should be visible
      expect(find.text('同名のファイルが既に存在します'), findsOneWidget);
    });

    testWidgets('rename dialog disables confirm when name is empty',
        (tester) async {
      await openRenameDialog(tester);

      // Clear the text field
      final textField = find.byType(TextField).last;
      await tester.enterText(textField, '');
      await tester.pumpAndSettle();

      // Confirm button should be disabled (find it and check onPressed)
      final confirmButton = tester.widget<TextButton>(
          find.widgetWithText(TextButton, '変更'));
      expect(confirmButton.onPressed, isNull);
    });
  });
}
