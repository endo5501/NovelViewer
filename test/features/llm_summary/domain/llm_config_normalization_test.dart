import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/llm_summary/domain/llm_config_normalization.dart';

void main() {
  group('normalizeEndpointUrl', () {
    test('drops surrounding whitespace', () {
      expect(
        normalizeEndpointUrl(' http://localhost:11434 '),
        'http://localhost:11434',
      );
    });

    test('drops a pasted trailing newline', () {
      expect(
        normalizeEndpointUrl('http://localhost:11434\n'),
        'http://localhost:11434',
      );
    });

    test('drops every trailing slash', () {
      expect(
        normalizeEndpointUrl('https://api.example.com/v1//'),
        'https://api.example.com/v1',
      );
    });

    test('drops trailing slashes left behind by the whitespace pass', () {
      expect(
        normalizeEndpointUrl('  http://localhost:11434/  '),
        'http://localhost:11434',
      );
    });

    test('leaves slashes inside the path alone', () {
      expect(
        normalizeEndpointUrl('https://api.example.com/v1/openai'),
        'https://api.example.com/v1/openai',
      );
    });

    test('turns an input of only whitespace into an empty value', () {
      expect(normalizeEndpointUrl('   '), '');
    });

    test('leaves an already normalized value untouched', () {
      expect(
        normalizeEndpointUrl('http://localhost:11434'),
        'http://localhost:11434',
      );
    });

    test('does not strip a lone slash into nothing surprising', () {
      // A value of only slashes is not a usable endpoint either way; the point
      // is that the pass terminates rather than looping.
      expect(normalizeEndpointUrl('///'), '');
    });
  });

  group('normalizeModelName', () {
    test('drops surrounding whitespace', () {
      expect(normalizeModelName('  llama3\n'), 'llama3');
    });

    test('keeps a slash inside the name', () {
      expect(normalizeModelName(' org/model '), 'org/model');
    });

    test('keeps a trailing slash, which is part of no endpoint here', () {
      expect(normalizeModelName('weird/'), 'weird/');
    });

    test('turns an input of only whitespace into an empty value', () {
      expect(normalizeModelName(' \t '), '');
    });
  });

  group('normalizeApiKey', () {
    test('drops the newline a paste leaves behind', () {
      // Left in place this reaches the Authorization header and breaks it.
      expect(normalizeApiKey('sk-example\n'), 'sk-example');
    });

    test('drops surrounding spaces', () {
      expect(normalizeApiKey('  sk-example  '), 'sk-example');
    });

    test('never touches the inside of the value', () {
      expect(normalizeApiKey(' sk-ex/am+ple= '), 'sk-ex/am+ple=');
    });

    test('turns an input of only whitespace into an empty value', () {
      expect(normalizeApiKey('  '), '');
    });
  });
}
