sealed class AnalysisProgress {
  const AnalysisProgress();
}

class AnalysisExtractingFacts extends AnalysisProgress {
  final int round;
  final int current;
  final int total;

  const AnalysisExtractingFacts({
    required this.round,
    required this.current,
    required this.total,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AnalysisExtractingFacts &&
          runtimeType == other.runtimeType &&
          round == other.round &&
          current == other.current &&
          total == other.total;

  @override
  int get hashCode => Object.hash(round, current, total);
}

class AnalysisGeneratingFinalSummary extends AnalysisProgress {
  const AnalysisGeneratingFinalSummary();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AnalysisGeneratingFinalSummary &&
          runtimeType == other.runtimeType;

  @override
  int get hashCode => runtimeType.hashCode;
}
