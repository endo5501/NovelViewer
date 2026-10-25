import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/app_update/providers/update_providers.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/keyboard_shortcuts/data/shortcut_action.dart';
import 'package:novel_viewer/features/keyboard_shortcuts/data/shortcut_bindings.dart';
import 'package:novel_viewer/features/keyboard_shortcuts/providers/keyboard_shortcut_providers.dart';
import 'package:novel_viewer/features/settings/presentation/settings_dialog.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';
import 'package:novel_viewer/features/tts/providers/irodori_model_download_providers.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';
import 'package:novel_viewer/shared/platform/platform_capabilities.dart';
import 'package:novel_viewer/shared/providers/platform_capabilities_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/phone_display.dart';
import '../test_utils/flutter_secure_storage_mock.dart';

/// The dialogs the settings sections open, on the portrait display of an
/// iPhone 16 with the iOS configuration (spec adaptive-shell-layout: every
/// dialog fits, and its actions are reachable).
void main() {
  const iOS = PlatformCapabilities.forPlatform(isIOS: true, isMacOS: false);
  const longVoiceBase = '朗読用リファレンス音声_落ち着いた女性ナレーター_第三版_二〇二六年十月収録';
  const longVoiceFile = '$longVoiceBase.wav';

  late SharedPreferences prefs;
  late Directory tempDir;
  late FlutterSecureStorageMock secureStorageMock;
  late AppLocalizations ja;

  setUpAll(() async {
    ja = await AppLocalizations.delegate.load(const Locale('ja'));
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    tempDir = Directory.systemTemp.createTempSync('section_dialogs_phone_');
    Directory(p.join(tempDir.path, 'NovelViewer')).createSync();
    secureStorageMock = FlutterSecureStorageMock();
    secureStorageMock.install();
  });

  tearDown(() {
    secureStorageMock.uninstall();
    tempDir.deleteSync(recursive: true);
  });

  const reachable = Rect.fromLTRB(
    0,
    kPhoneTopInset,
    393,
    852 - kPhoneBottomInset,
  );

  void expectReachable(WidgetTester tester, Finder finder, String what) {
    expect(finder, findsOneWidget, reason: what);
    final rect = tester.getRect(finder);
    expect(
      reachable.contains(rect.topLeft) &&
          reachable.contains(rect.bottomRight - const Offset(0.01, 0.01)),
      isTrue,
      reason: '$what at $rect is outside $reachable',
    );
  }

  /// The topmost dialog, which the section opened over the settings dialog.
  Finder topDialog() => find.byType(AlertDialog).last;

  /// The dialog's card. The [AlertDialog] itself spans the whole route, its
  /// inset padding included, so its rect says nothing about where it shows.
  Finder topDialogCard() =>
      find.descendant(of: topDialog(), matching: find.byType(Material)).first;

  void expectDialogActionsReachable(WidgetTester tester) {
    expectReachable(tester, topDialogCard(), 'the dialog');
    final buttons = find.descendant(
      of: topDialog(),
      matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
    );
    for (final element in buttons.evaluate()) {
      final rect = tester.getRect(find.byWidget(element.widget));
      expect(
        reachable.contains(rect.topLeft) &&
            reachable.contains(rect.bottomRight - const Offset(0.01, 0.01)),
        isTrue,
        reason: 'an action at $rect is outside $reachable',
      );
    }
  }

  void expectNoCutOffText(Finder within) {
    final texts = find.descendant(of: within, matching: find.byType(Text));
    for (final element in texts.evaluate()) {
      final paragraph = element.renderObject! as RenderParagraph;
      expect(
        paragraph.debugHasOverflowShader,
        isFalse,
        reason: '"${(element.widget as Text).data}" is cut off',
      );
    }
  }

  Future<void> openSettings(
    WidgetTester tester, {
    IrodoriLegacyAssets? legacyAssets,
  }) async {
    usePhoneDisplay(tester);
    await tester.runAsync(() async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            libraryPathProvider.overrideWithValue(
              p.join(tempDir.path, 'NovelViewer'),
            ),
            platformCapabilitiesProvider.overrideWithValue(iOS),
            shortcutDefaultsProvider.overrideWithValue(
              defaultShortcutBindings(isApplePlatform: true),
            ),
            packageInfoProvider.overrideWithValue(
              PackageInfo(
                appName: 'NovelViewer',
                packageName: 'com.endo5501.novelViewer',
                version: '1.8.4',
                buildNumber: '19',
              ),
            ),
            if (legacyAssets != null)
              irodoriLegacyAssetsProvider.overrideWithValue(legacyAssets),
          ],
          child: MaterialApp(
            locale: const Locale('ja'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => SettingsDialog.show(context),
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    });
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  Future<void> openIrodoriSettings(WidgetTester tester) async {
    await tester.tap(
      find.descendant(
        of: find.byType(TabBar),
        matching: find.text(ja.settings_ttsTabLabel),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.text('Irodori-TTS'));
      await tester.pumpAndSettle();
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();
  }

  group('voice reference rename dialog', () {
    Future<void> openRenameDialog(WidgetTester tester) async {
      final voicesDir = Directory(p.join(tempDir.path, 'voices'))..createSync();
      File(p.join(voicesDir.path, longVoiceFile)).writeAsStringSync('');
      await prefs.setString('tts_ref_wav_path', longVoiceFile);

      await openSettings(tester);
      await openIrodoriSettings(tester);
      final rename = find.byTooltip(ja.settings_renameFileTooltip);
      await tester.ensureVisible(rename);
      await tester.pumpAndSettle();
      await tester.tap(rename);
      await tester.pumpAndSettle();
    }

    testWidgets('fits with a long Japanese file name', (tester) async {
      await openRenameDialog(tester);

      expect(find.text(ja.settings_renameFileTitle), findsOneWidget);
      expectDialogActionsReachable(tester);
      expectNoCutOffText(topDialog());
    });

    testWidgets('fits while showing the duplicate-name error', (tester) async {
      final voicesDir = Directory(p.join(tempDir.path, 'voices'))..createSync();
      const other = '別の朗読用リファレンス音声_低めの男性ナレーター_第二版.wav';
      File(p.join(voicesDir.path, other)).writeAsStringSync('');

      await openRenameDialog(tester);
      await tester.enterText(
        find.descendant(of: topDialog(), matching: find.byType(TextField)),
        p.basenameWithoutExtension(other),
      );
      await tester.pumpAndSettle();

      expect(find.text(ja.common_fileDuplicateError), findsOneWidget);
      expectDialogActionsReachable(tester);
    });

    testWidgets('fits with the keyboard up', (tester) async {
      await openRenameDialog(tester);
      showPhoneKeyboard(tester);
      await tester.pumpAndSettle();

      final dialog = tester.getRect(topDialogCard());
      expect(
        dialog.bottom,
        lessThanOrEqualTo(852 - kPhoneKeyboardHeight),
        reason: 'the dialog at $dialog sits under the keyboard',
      );
      expect(dialog.top, greaterThanOrEqualTo(kPhoneTopInset));
      final change = find.descendant(
        of: topDialog(),
        matching: find.widgetWithText(TextButton, ja.common_changeButton),
      );
      expect(
        tester.getRect(change).bottom,
        lessThanOrEqualTo(852 - kPhoneKeyboardHeight),
        reason: 'the change button sits under the keyboard',
      );
    });
  });

  group('Irodori-TTS legacy assets confirmation', () {
    testWidgets('fits', (tester) async {
      await openSettings(
        tester,
        legacyAssets: (present: true, bytes: 2904288926),
      );
      await openIrodoriSettings(tester);
      final delete = find.byKey(const Key('irodori_delete_legacy_assets'));
      await tester.ensureVisible(delete);
      await tester.pumpAndSettle();
      await tester.tap(delete);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('irodori_delete_legacy_confirm_dialog')),
        findsOneWidget,
      );
      expectDialogActionsReachable(tester);
      expectNoCutOffText(topDialog());
    });
  });

  group('shortcut capture dialog', () {
    testWidgets('fits', (tester) async {
      await openSettings(tester);
      final reassign = find.byKey(
        Key('shortcut_reassign_${ShortcutAction.toggleFileBrowser.name}'),
      );
      await tester.ensureVisible(reassign);
      await tester.pumpAndSettle();
      await tester.tap(reassign);
      await tester.pumpAndSettle();

      expect(find.text(ja.settings_shortcutPressKeys), findsOneWidget);
      expectReachable(tester, topDialogCard(), 'the capture dialog');
    });
  });
}
