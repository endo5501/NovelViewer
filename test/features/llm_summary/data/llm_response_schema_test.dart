import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_response_schema.dart';

void main() {
  group('LlmResponseSchema.singleStringField', () {
    test('preserves the field name it was built with', () {
      const schema = LlmResponseSchema.singleStringField('facts');

      expect(schema.fieldName, 'facts');
    });

    test('two schemas for the same field are equal and share a hashCode', () {
      const a = LlmResponseSchema.singleStringField('summary');
      const b = LlmResponseSchema.singleStringField('summary');

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('schemas for different fields are not equal', () {
      const facts = LlmResponseSchema.singleStringField('facts');
      const summary = LlmResponseSchema.singleStringField('summary');

      expect(facts, isNot(summary));
    });
  });
}
