/// Whether an answer still arriving should be let run, taken as it stands, or
/// ended as having run away.
///
/// Kept apart from the plugin, and free of any Flutter or model-framework
/// import, for the same reason `GenerationFailureWireCode` is: the plugin's
/// own package cannot be built outside a Flutter build, and this file can.
///
/// Each verdict is a function of the text so far. The framework's stream
/// delivers the whole text each time rather than what was added, so the
/// plugin can ask afresh on every delivery and act on the first verdict that
/// is not `continuing`.
///
/// Lengths are counted in UTF-16 code units, the unit the client counts its
/// response budget in.
enum AnswerCutoff {
  enum Verdict: Equatable {
    /// Nothing has been decided yet.
    case continuing

    /// An unconstrained answer's object closed; this is the object, without
    /// anything the model wrote before or after it.
    case complete(String)

    /// The answer has stopped being the one asked for.
    case ranAway
  }

  /// The verdict on a constrained answer, from the value its field holds so
  /// far.
  ///
  /// A closing brace in the field is the model believing it already closed
  /// the object: measured on iPhone 16 (iOS 27.0.1), every runaway answer
  /// wrote `」}` straight after the summary and went on inside the still-open
  /// string. A field past the budget has stopped being an answer produced as
  /// instructed, which the budget is sized never to reach. Either is a
  /// runaway. Nothing here says a constrained answer is complete; the
  /// framework says that, by ending the stream.
  static func constrained(fieldValue: String, budget: Int) -> Verdict {
    if fieldValue.contains("}") || fieldValue.utf16.count > budget {
      return .ranAway
    }
    return .continuing
  }

  /// The verdict on an unconstrained answer, from its text so far.
  ///
  /// The answer is complete when its first top-level object closes, judged as
  /// JSON reads it: braces inside a string, and a quotation mark escaped
  /// inside one, neither open nor close anything. It has run away when the
  /// text passes the budget before that, counted from the start of the answer
  /// so that a preface — the fence the model opens, or anything longer — is
  /// counted too, and the verdict on the whole text is the one a stream
  /// reached on the way.
  static func unconstrained(text: String, budget: Int) -> Verdict {
    var length = 0
    var objectStart: String.Index?
    var depth = 0
    var inString = false
    var escaped = false

    var index = text.startIndex
    while index < text.endIndex {
      let character = text[index]
      length += character.utf16.count
      if length > budget {
        return .ranAway
      }

      if let start = objectStart {
        if inString {
          if escaped {
            escaped = false
          } else if character == "\\" {
            escaped = true
          } else if character == "\"" {
            inString = false
          }
        } else if character == "\"" {
          inString = true
        } else if character == "{" {
          depth += 1
        } else if character == "}" {
          depth -= 1
          if depth == 0 {
            return .complete(String(text[start...index]))
          }
        }
      } else if character == "{" {
        objectStart = index
        depth = 1
      }
      index = text.index(after: index)
    }
    return .continuing
  }
}
