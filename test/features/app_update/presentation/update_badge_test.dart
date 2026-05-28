import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/app_update/data/release_info.dart';
import 'package:novel_viewer/features/app_update/domain/update_check_service.dart';
import 'package:novel_viewer/features/app_update/presentation/update_badge.dart';
import 'package:novel_viewer/features/app_update/providers/update_providers.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';

void main() {
  const release = ReleaseInfo(tagName: 'v1.3.0', body: '', assets: []);

  Widget host({required UpdateAvailable? available}) {
    return ProviderScope(
      overrides: [
        updateAvailableProvider.overrideWithValue(available),
      ],
      child: MaterialApp(
        locale: const Locale('ja'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          appBar: AppBar(actions: const [UpdateBadge()]),
        ),
      ),
    );
  }

  testWidgets('shows the badge button when an update is available',
      (tester) async {
    await tester.pumpWidget(host(available: const UpdateAvailable(release)));
    await tester.pump();

    expect(find.byKey(const Key('update_badge_button')), findsOneWidget);
  });

  testWidgets('hides the badge button when no update is available',
      (tester) async {
    await tester.pumpWidget(host(available: null));
    await tester.pump();

    expect(find.byKey(const Key('update_badge_button')), findsNothing);
  });
}
