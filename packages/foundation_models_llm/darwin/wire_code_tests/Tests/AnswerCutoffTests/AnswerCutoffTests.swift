import XCTest

@testable import AnswerCutoff

/// The decisions the plugin makes while an answer is still arriving: whether
/// a constrained field has run away, and where an unconstrained answer's
/// object ends. Each is a function of the text so far, so a stream that
/// delivers the whole text each time can ask it afresh.
final class ConstrainedCutoffTests: XCTestCase {
  private let budget = 1300

  func testAFieldWithinTheBudgetContinues() {
    XCTAssertEqual(
      AnswerCutoff.constrained(
        fieldValue: "〈記憶人〉は人口が少ない非生殖性の別種である。", budget: budget),
      .continuing)
  }

  func testAClosingBraceInTheFieldIsARunaway() {
    XCTAssertEqual(
      AnswerCutoff.constrained(
        fieldValue: "〈記憶人〉は人口が少ない。」}", budget: budget),
      .ranAway)
  }

  func testAFieldPastTheBudgetIsARunaway() {
    let value = String(repeating: "支援者: Appleです。", count: 100)
    XCTAssertGreaterThan(value.count, budget)
    XCTAssertEqual(
      AnswerCutoff.constrained(fieldValue: value, budget: budget), .ranAway)
  }

  func testAFieldExactlyAtTheBudgetContinues() {
    let value = String(repeating: "あ", count: budget)
    XCTAssertEqual(
      AnswerCutoff.constrained(fieldValue: value, budget: budget), .continuing)
  }

  /// The heads of the answers measured on iPhone 16 (iOS 27.0.1): every one
  /// is caught at the brace, within the first hundred characters.
  func testEveryMeasuredRunawayIsCaughtAtItsBrace() {
    let measured = [
      "〈記憶人〉は〈記憶人シィー〉という別種名を持ち、非生殖性の別種で、人口が少なく、生まれがロンドンである。」} 支援者: Apple。 AI。",
      "〈記憶人〉は〈記憶人シィー〉という別種名を持ち、非生殖性の別種で、人口が少ない。」} 2つ目の情報と重複する情報を統合しました。",
      "〈記憶人〉は〈記憶人シィー〉という別種名を持つ非生殖性の別種で、生まれがロンドンであり、人口が少ない。」} 支援者: Appleです。",
    ]
    for value in measured {
      let cut = value.range(of: "}")!.upperBound
      XCTAssertEqual(
        AnswerCutoff.constrained(
          fieldValue: String(value[..<cut]), budget: budget),
        .ranAway, value)
      let before = value.range(of: "}")!.lowerBound
      XCTAssertEqual(
        AnswerCutoff.constrained(
          fieldValue: String(value[..<before]), budget: budget),
        .continuing, value)
    }
  }
}

final class UnconstrainedCutoffTests: XCTestCase {
  private let budget = 1300

  func testAnOpenObjectContinues() {
    XCTAssertEqual(
      AnswerCutoff.unconstrained(
        text: #"{"summary": "〈記憶人〉は人口が"#, budget: budget),
      .continuing)
  }

  func testTextBeforeAnyObjectContinues() {
    XCTAssertEqual(
      AnswerCutoff.unconstrained(text: "```json\n", budget: budget),
      .continuing)
  }

  func testAClosedObjectIsCompleteWithNothingAfterIt() {
    XCTAssertEqual(
      AnswerCutoff.unconstrained(
        text: #"{"summary": "人口が少ない。"} 支援者: Appleです。"#,
        budget: budget),
      .complete(#"{"summary": "人口が少ない。"}"#))
  }

  func testAFenceAroundTheObjectIsDropped() {
    XCTAssertEqual(
      AnswerCutoff.unconstrained(
        text: "```json\n{\n  \"summary\": \"人口が少ない。\"\n}\n```",
        budget: budget),
      .complete("{\n  \"summary\": \"人口が少ない。\"\n}"))
  }

  func testABraceInsideAStringDoesNotCloseTheObject() {
    XCTAssertEqual(
      AnswerCutoff.unconstrained(
        text: #"{"summary": "記号 } を含む"#, budget: budget),
      .continuing)
    XCTAssertEqual(
      AnswerCutoff.unconstrained(
        text: #"{"summary": "記号 } を含む"} 続き"#, budget: budget),
      .complete(#"{"summary": "記号 } を含む"}"#))
  }

  func testAnEscapedQuotationMarkDoesNotEndTheString() {
    XCTAssertEqual(
      AnswerCutoff.unconstrained(
        text: #"{"summary": "引用 \"}\" の"#, budget: budget),
      .continuing)
    XCTAssertEqual(
      AnswerCutoff.unconstrained(
        text: #"{"summary": "引用 \"}\" の"}"#, budget: budget),
      .complete(#"{"summary": "引用 \"}\" の"}"#))
  }

  func testAnEscapedBackslashBeforeAQuotationMarkEndsTheString() {
    XCTAssertEqual(
      AnswerCutoff.unconstrained(
        text: #"{"summary": "末尾 \\"} 続き"#, budget: budget),
      .complete(#"{"summary": "末尾 \\"}"#))
  }

  func testANestedObjectClosesWithTheOuterOne() {
    XCTAssertEqual(
      AnswerCutoff.unconstrained(
        text: #"{"facts": {"a": "x"}"#, budget: budget),
      .continuing)
    XCTAssertEqual(
      AnswerCutoff.unconstrained(
        text: #"{"facts": {"a": "x"}} 後"#, budget: budget),
      .complete(#"{"facts": {"a": "x"}}"#))
  }

  func testAListValueClosesWithTheObject() {
    XCTAssertEqual(
      AnswerCutoff.unconstrained(
        text: #"{"facts": ["- a", "- b"]}"#, budget: budget),
      .complete(#"{"facts": ["- a", "- b"]}"#))
  }

  func testAnObjectLeftOpenPastTheBudgetIsARunaway() {
    let text = #"{"summary": ""# + String(repeating: "支援者: Appleです。", count: 100)
    XCTAssertEqual(
      AnswerCutoff.unconstrained(text: text, budget: budget), .ranAway)
  }

  func testTextWithNoObjectPastTheBudgetIsARunaway() {
    let text = String(repeating: "支援者: Appleです。", count: 100)
    XCTAssertEqual(
      AnswerCutoff.unconstrained(text: text, budget: budget), .ranAway)
  }

  /// Counted from the start of the answer rather than from its object, so the
  /// verdict on the whole text is the one the stream reached on the way: a
  /// preface that passes the budget has run away before any object opens.
  func testTextBeforeTheObjectCountsAgainstTheBudget() {
    let preface = String(repeating: "前置き。", count: 400)
    XCTAssertGreaterThan(preface.count, budget)
    XCTAssertEqual(
      AnswerCutoff.unconstrained(
        text: preface + #"{"summary": "短い"}"#, budget: budget),
      .ranAway)
  }

  /// A stream delivers the whole text each time. Asking afresh at every
  /// length gives no verdict before the one the whole text gives, and the
  /// first verdict is the one the plugin acts on.
  func testTheVerdictDoesNotDependOnHowTheTextArrived() {
    let text = "```json\n{\"summary\": \"記号 } と \\\"引用\\\"。\"}\n```\n続き"
    var first: AnswerCutoff.Verdict?
    for end in text.indices {
      let verdict = AnswerCutoff.unconstrained(
        text: String(text[..<end]), budget: budget)
      if verdict != .continuing {
        first = verdict
        break
      }
    }
    XCTAssertEqual(first, .complete("{\"summary\": \"記号 } と \\\"引用\\\"。\"}"))
  }
}
