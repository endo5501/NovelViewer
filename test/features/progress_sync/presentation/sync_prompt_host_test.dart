import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/progress_sync/domain/device_progress.dart';
import 'package:novel_viewer/features/progress_sync/domain/sync_progress_record.dart';
import 'package:novel_viewer/features/progress_sync/presentation/sync_prompt_host.dart';
import 'package:novel_viewer/features/progress_sync/providers/progress_sync_entry_providers.dart';
import 'package:novel_viewer/features/progress_sync/providers/progress_sync_prompt_actions.dart';

import '../../../helpers/localized_material_app.dart';

class _RecordingActions implements SyncPromptActions {
  final List<(SyncPromptRequest, bool)> answers = [];

  @override
  Future<void> answer(SyncPromptRequest request, {required bool move}) async {
    answers.add((request, move));
  }
}

final _request = SyncPromptRequest(
  novelId: 'narou_a',
  directory: '/library/narou_a',
  fileName: '005_t.txt',
  remote: RemoteProgress(
    deviceId: 'win',
    deviceName: 'Windows (desk)',
    record: SyncProgressRecord(
      novelId: 'narou_a',
      episode: 5,
      fileName: '05_t.txt',
      bodyOffset: 10,
      bodyHash: 'h',
      readAt: DateTime(2026, 10, 18, 21, 5),
    ),
  ),
);

void main() {
  late _RecordingActions actions;
  late ProviderContainer container;

  Future<void> pumpHost(WidgetTester tester) async {
    actions = _RecordingActions();
    container = ProviderContainer(
      overrides: [
        syncPromptActionsProvider.overrideWithValue(actions),
        currentDirectoryProvider.overrideWith(
          () => CurrentDirectoryNotifier('/library/narou_a'),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const LocalizedMaterialApp(
          home: SyncPromptHost(child: Scaffold(body: Text('reader'))),
        ),
      ),
    );
  }

  testWidgets('asks with the device, the episode and when', (tester) async {
    await pumpHost(tester);

    container.read(syncPromptProvider.notifier).show(_request);
    await tester.pumpAndSettle();

    expect(find.textContaining('Windows (desk)'), findsOneWidget);
    expect(find.textContaining('5 話'), findsOneWidget);
    expect(find.textContaining('2026'), findsOneWidget);
    expect(find.textContaining('21:05'), findsOneWidget);
    expect(find.text('移動する'), findsOneWidget);
    expect(find.text('このまま'), findsOneWidget);
    expect(container.read(syncPromptProvider), isNull);
  });

  testWidgets('moving answers yes', (tester) async {
    await pumpHost(tester);
    container.read(syncPromptProvider.notifier).show(_request);
    await tester.pumpAndSettle();

    await tester.tap(find.text('移動する'));
    await tester.pumpAndSettle();

    expect(actions.answers, hasLength(1));
    expect(actions.answers.single.$1, same(_request));
    expect(actions.answers.single.$2, isTrue);
    expect(find.text('移動する'), findsNothing);
  });

  testWidgets('staying answers no', (tester) async {
    await pumpHost(tester);
    container.read(syncPromptProvider.notifier).show(_request);
    await tester.pumpAndSettle();

    await tester.tap(find.text('このまま'));
    await tester.pumpAndSettle();

    expect(actions.answers.single.$2, isFalse);
  });

  testWidgets('closing the dialog counts as staying', (tester) async {
    await pumpHost(tester);
    container.read(syncPromptProvider.notifier).show(_request);
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    expect(find.text('移動する'), findsNothing);
    expect(actions.answers.single.$2, isFalse);
  });

  testWidgets('asks once even when the question is raised again', (
    tester,
  ) async {
    await pumpHost(tester);
    container.read(syncPromptProvider.notifier).show(_request);
    await tester.pumpAndSettle();
    container.read(syncPromptProvider.notifier).show(_request);
    await tester.pumpAndSettle();

    expect(find.text('移動する'), findsOneWidget);
    await tester.tap(find.text('このまま'));
    await tester.pumpAndSettle();
    expect(find.text('移動する'), findsNothing);
    expect(actions.answers, hasLength(1));
  });

  testWidgets('does not ask about a novel the reader has left', (tester) async {
    await pumpHost(tester);
    container.read(currentDirectoryProvider.notifier).setDirectory('/library');

    container.read(syncPromptProvider.notifier).show(_request);
    await tester.pumpAndSettle();

    expect(find.text('移動する'), findsNothing);
    expect(actions.answers, isEmpty);
  });
}
