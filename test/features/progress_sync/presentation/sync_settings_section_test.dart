import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/progress_sync/data/oauth/progress_sync_auth.dart';
import 'package:novel_viewer/features/progress_sync/data/progress_sync_service.dart';
import 'package:novel_viewer/features/progress_sync/presentation/sync_settings_section.dart';
import 'package:novel_viewer/features/progress_sync/providers/progress_sync_settings_providers.dart';

import '../../../helpers/localized_material_app.dart';

class _RecordingActions implements SyncAccountActions {
  final List<String> calls = [];
  Completer<void>? signInGate;

  @override
  Future<void> signIn() async {
    calls.add('signIn');
    await signInGate?.future;
  }

  @override
  Future<void> signOut() async => calls.add('signOut');

  @override
  Future<void> syncNow() async => calls.add('syncNow');
}

void main() {
  late _RecordingActions actions;

  Future<void> pump(
    WidgetTester tester, {
    required SyncAccountState account,
    SyncRunStatus status = const SyncRunStatus(),
    Locale locale = const Locale('ja'),
  }) async {
    actions = _RecordingActions();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          syncAccountStateProvider.overrideWithValue(account),
          syncRunStatusProvider.overrideWithValue(status),
          syncAccountActionsProvider.overrideWithValue(actions),
        ],
        child: LocalizedMaterialApp(
          locale: locale,
          home: const Scaffold(body: SyncSettingsSection()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('signed out', () {
    testWidgets('offers only the sign-in', (tester) async {
      await pump(tester, account: const SyncAccountState.signedOut());

      expect(find.text('Google でログイン'), findsOneWidget);
      expect(find.text('今すぐ同期'), findsNothing);
      expect(find.text('ログアウト'), findsNothing);
    });

    testWidgets('signs in, and waits for the browser meanwhile', (
      tester,
    ) async {
      await pump(tester, account: const SyncAccountState.signedOut());
      actions.signInGate = Completer<void>();

      await tester.tap(find.text('Google でログイン'));
      await tester.pump();

      expect(actions.calls, ['signIn']);
      expect(find.textContaining('ブラウザ'), findsOneWidget);
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Google でログイン'),
      );
      expect(button.onPressed, isNull);

      actions.signInGate!.complete();
      await tester.pumpAndSettle();
      expect(find.textContaining('ブラウザ'), findsNothing);
    });
  });

  group('signed in', () {
    testWidgets('shows the account, the last sync and the actions', (
      tester,
    ) async {
      await pump(
        tester,
        account: const SyncAccountState.signedIn('reader@example.com'),
        status: SyncRunStatus(lastSuccessAt: DateTime(2026, 10, 18, 21, 5)),
      );

      expect(find.textContaining('reader@example.com'), findsOneWidget);
      expect(find.textContaining('21:05'), findsOneWidget);
      expect(find.text('今すぐ同期'), findsOneWidget);
      expect(find.text('ログアウト'), findsOneWidget);
    });

    testWidgets('says when it has not synced yet', (tester) async {
      await pump(
        tester,
        account: const SyncAccountState.signedIn('reader@example.com'),
      );

      expect(find.text('まだ同期していません'), findsOneWidget);
    });

    testWidgets('shows the last failure', (tester) async {
      await pump(
        tester,
        account: const SyncAccountState.signedIn('reader@example.com'),
        status: const SyncRunStatus(lastError: 'offline'),
      );

      expect(find.textContaining('offline'), findsOneWidget);
    });

    testWidgets('syncs now and signs out on request', (tester) async {
      await pump(
        tester,
        account: const SyncAccountState.signedIn('reader@example.com'),
      );

      await tester.tap(find.text('今すぐ同期'));
      await tester.tap(find.text('ログアウト'));
      await tester.pumpAndSettle();

      expect(actions.calls, ['syncNow', 'signOut']);
    });

    testWidgets('cannot sync again while a sync runs', (tester) async {
      await pump(
        tester,
        account: const SyncAccountState.signedIn('reader@example.com'),
        status: const SyncRunStatus(running: true),
      );

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
      expect(find.text('同期中…'), findsOneWidget);
    });
  });

  testWidgets('asks to sign in again when the grant lapsed', (tester) async {
    await pump(
      tester,
      account: const SyncAccountState.needsReauth('reader@example.com'),
    );

    expect(find.textContaining('reader@example.com'), findsOneWidget);
    await tester.tap(find.text('もう一度ログイン'));
    expect(actions.calls, ['signIn']);
  });

  testWidgets('labels come from the localizations', (tester) async {
    await pump(
      tester,
      account: const SyncAccountState.signedIn('reader@example.com'),
      locale: const Locale('en'),
    );

    expect(find.text('Sync now'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
  });
}
