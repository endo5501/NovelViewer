import 'package:flutter/material.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';

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
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );
  }
}
