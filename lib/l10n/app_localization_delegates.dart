import 'package:material_ui/material_ui.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';

/// The localization delegates every [MaterialApp] in the app (and in widget
/// tests) must use.
///
/// The list gen-l10n generates on [AppLocalizations] is not used: as of
/// Flutter 3.50 gen-l10n still emits the deprecated delegates from
/// `flutter_localizations`, which serve localization types that `material_ui`
/// widgets do not look up. `GlobalMaterialLocalizations.delegates` from
/// `material_ui` covers the Material, Cupertino and Widgets localizations.
const List<LocalizationsDelegate<dynamic>> appLocalizationsDelegates = [
  AppLocalizations.delegate,
  ...GlobalMaterialLocalizations.delegates,
];
