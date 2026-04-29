enum TtsEpisodeStatus {
  generating,
  partial,
  completed;

  String toDb() => name;

  static TtsEpisodeStatus fromDb(String value) {
    try {
      return TtsEpisodeStatus.values.byName(value);
    } on ArgumentError {
      throw FormatException('Unknown TtsEpisodeStatus DB value: "$value"');
    }
  }
}
