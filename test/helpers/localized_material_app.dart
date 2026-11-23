import 'package:material_ui/material_ui.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';
import 'package:novel_viewer/l10n/app_localization_delegates.dart';

class LocalizedMaterialApp extends StatelessWidget {
  final Widget home;
  final Locale locale;

  const LocalizedMaterialApp({
    super.key,
    required this.home,
    this.locale = const Locale('ja'),
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: locale,
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );
  }
}
