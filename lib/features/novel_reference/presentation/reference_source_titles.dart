import 'package:novel_viewer/l10n/app_localizations.dart';

/// [titles] quoted and joined the way the display language writes a list of
/// work titles (『A』、『B』 in Japanese, “A”, “B” in English).
String formatReferenceSourceTitles(
  AppLocalizations l10n,
  Iterable<String> titles,
) => titles
    .map(l10n.referenceSources_quotedTitle)
    .join(l10n.referenceSources_listSeparator);
