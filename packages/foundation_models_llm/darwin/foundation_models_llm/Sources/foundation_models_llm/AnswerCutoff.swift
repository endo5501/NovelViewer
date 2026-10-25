/// Placeholder: the verdicts are written test-first (openspec change
/// on-device-retry-runaway, task 3.1).
enum AnswerCutoff {
  enum Verdict: Equatable {
    case continuing
    case complete(String)
    case ranAway
  }

  static func constrained(fieldValue: String, budget: Int) -> Verdict {
    .continuing
  }

  static func unconstrained(text: String, budget: Int) -> Verdict {
    .continuing
  }
}
