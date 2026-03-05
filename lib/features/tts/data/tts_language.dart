enum TtsLanguage {
  en(languageId: 2050, displayName: 'English'),
  ru(languageId: 2069, displayName: 'Русский'),
  zh(languageId: 2055, displayName: '中文'),
  ja(languageId: 2058, displayName: '日本語'),
  ko(languageId: 2064, displayName: '한국어'),
  de(languageId: 2053, displayName: 'Deutsch'),
  fr(languageId: 2061, displayName: 'Français'),
  es(languageId: 2054, displayName: 'Español'),
  it(languageId: 2070, displayName: 'Italiano'),
  pt(languageId: 2071, displayName: 'Português');

  const TtsLanguage({
    required this.languageId,
    required this.displayName,
  });

  final int languageId;
  final String displayName;

  static const int defaultLanguageId = 2058; // ja
}
