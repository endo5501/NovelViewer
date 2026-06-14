import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:novel_viewer/features/app_update/data/installer_downloader.dart';
import 'package:novel_viewer/features/app_update/data/installer_updater.dart';
import 'package:novel_viewer/features/app_update/data/installer_verifier.dart';
import 'package:novel_viewer/features/app_update/data/process_starter.dart';
import 'package:novel_viewer/features/app_update/data/release_info.dart';
import 'package:novel_viewer/features/app_update/domain/distribution_type.dart';
import 'package:novel_viewer/features/app_update/presentation/update_dialog.dart';
import 'package:novel_viewer/features/app_update/providers/update_providers.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../helpers/localized_material_app.dart';

class _NoopDownloader implements InstallerDownloader {
  @override
  Future<DownloadedInstaller> download(
    ReleaseInfo info, {
    void Function(double progress)? onProgress,
  }) async =>
      const DownloadedInstaller(exePath: 'x', sha256Path: 'y');
}

class _NoopStarter implements ProcessStarter {
  @override
  Future<void> start(String executable, List<String> arguments) async {}
}

/// Returns a pre-set [UpdateResult] without performing any real work.
class _StubUpdater extends InstallerUpdater {
  _StubUpdater(this._result)
      : super(
          downloader: _NoopDownloader(),
          verifier: const InstallerVerifier(),
          processStarter: _NoopStarter(),
          onExit: (_) {},
        );

  final UpdateResult _result;

  @override
  Future<UpdateResult> apply(
    ReleaseInfo info, {
    void Function(double progress)? onProgress,
  }) async =>
      _result;
}

ReleaseInfo _release() => const ReleaseInfo(
      tagName: 'v1.3.0',
      body: 'notes',
      assets: [],
    );

PackageInfo _packageInfo() => PackageInfo(
      appName: 'NovelViewer',
      packageName: 'com.example.novelviewer',
      version: '1.0.0',
      buildNumber: '1',
    );

Future<void> _openDialog(WidgetTester tester) async {
  await tester.tap(find.text('open-dialog'));
  await tester.pumpAndSettle();
}

Widget _host() => LocalizedMaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => UpdateDialog.show(context, _release()),
              child: const Text('open-dialog'),
            ),
          ),
        ),
      ),
    );

void main() {
  testWidgets(
      'logs a WARNING and closes the dialog when opening the release page fails',
      (tester) async {
    final records = <LogRecord>[];
    final sub = Logger.root.onRecord.listen(records.add);
    addTearDown(sub.cancel);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        packageInfoProvider.overrideWithValue(_packageInfo()),
        distributionTypeProvider.overrideWithValue(DistributionType.portable),
      ],
      child: _host(),
    ));
    await _openDialog(tester);

    expect(find.byType(UpdateDialog), findsOneWidget);

    // url_launcher has no platform handler in tests, so launchUrl throws and
    // the dialog's catch must log the failure, then close. runAsync lets the
    // real plugin call reject; poll (rather than a fixed sleep) until the catch
    // has logged, so the test is not timing-fragile on a loaded runner.
    await tester.runAsync(() async {
      await tester.tap(find.text('リリースページを開く'));
      for (var i = 0;
          i < 200 &&
              !records.any((r) => r.loggerName == 'app_update.dialog');
          i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pumpAndSettle();

    expect(find.byType(UpdateDialog), findsNothing);
    expect(
      records.any((r) =>
          r.loggerName == 'app_update.dialog' && r.level == Level.WARNING),
      isTrue,
    );
  });

  testWidgets(
      'logs a WARNING including the UpdateResult message when an update fails',
      (tester) async {
    final records = <LogRecord>[];
    final sub = Logger.root.onRecord.listen(records.add);
    addTearDown(sub.cancel);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        packageInfoProvider.overrideWithValue(_packageInfo()),
        distributionTypeProvider.overrideWithValue(DistributionType.installer),
        installerUpdaterProvider.overrideWithValue(
          _StubUpdater(
            const UpdateResult(UpdateOutcome.downloadFailed, 'boom-detail'),
          ),
        ),
      ],
      child: _host(),
    ));
    await _openDialog(tester);

    await tester.tap(find.text('更新する'));
    await tester.pumpAndSettle();

    expect(
      records.any((r) =>
          r.loggerName == 'app_update.dialog' &&
          r.level == Level.WARNING &&
          r.message.contains('boom-detail')),
      isTrue,
    );
  });
}
