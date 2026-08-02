/// The shape an LLM response is required to take, expressed independently of
/// any provider's wire format. The pipeline knows which field it will read back
/// (`facts` / `summary`); translating that into a provider-specific request
/// field is each client's job.
class LlmResponseSchema {
  /// A JSON object carrying exactly one required field of type string.
  const LlmResponseSchema.singleStringField(this.fieldName);

  /// Name of the single required string field.
  final String fieldName;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LlmResponseSchema && other.fieldName == fieldName;

  @override
  int get hashCode => fieldName.hashCode;

  @override
  String toString() => 'LlmResponseSchema.singleStringField($fieldName)';
}
