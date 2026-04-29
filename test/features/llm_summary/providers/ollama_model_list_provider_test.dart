import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:novel_viewer/features/llm_summary/providers/ollama_model_list_provider.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';

void main() {
  http.Client makeClient({
    List<String> models = const ['gemma3', 'qwen3:8b'],
    int statusCode = 200,
  }) {
    return MockClient((request) async {
      if (request.url.path == '/api/tags') {
        if (statusCode != 200) {
          return http.Response('Server error', statusCode);
        }
        return http.Response(
          jsonEncode({
            'models':
                models.map((name) => {'name': name, 'size': 1000}).toList(),
          }),
          200,
        );
      }
      return http.Response('Not found', 404);
    });
  }

  ProviderContainer makeContainer({required http.Client client}) {
    return ProviderContainer(
      overrides: [httpClientProvider.overrideWithValue(client)],
    );
  }

  /// `autoDispose` drops a provider once nothing watches it, which can race
  /// with `read(future)` and surface as "disposed during loading". Test code
  /// keeps an explicit listener alive while the future settles.
  ProviderSubscription<AsyncValue<List<String>>> keepAlive(
    ProviderContainer container,
    String url,
  ) {
    return container.listen(ollamaModelListProvider(url), (_, _) {});
  }

  test('returns AsyncData with the fetched model names on success', () async {
    final container = makeContainer(client: makeClient());
    addTearDown(container.dispose);

    final sub = keepAlive(container, 'http://localhost:11434');
    addTearDown(sub.close);

    final result = await container
        .read(ollamaModelListProvider('http://localhost:11434').future);

    expect(result, ['gemma3', 'qwen3:8b']);
  });

  test('emits AsyncError when the fetch fails', () async {
    final container = makeContainer(client: makeClient(statusCode: 500));
    addTearDown(container.dispose);

    final provider = ollamaModelListProvider('http://localhost:11434');
    final completer = Completer<AsyncValue<List<String>>>();
    final sub = container.listen<AsyncValue<List<String>>>(
      provider,
      (_, next) {
        if (next.hasError && !completer.isCompleted) {
          completer.complete(next);
        }
      },
      fireImmediately: true,
    );
    addTearDown(sub.close);

    final state = await completer.future
        .timeout(const Duration(seconds: 2), onTimeout: () => sub.read());

    expect(state.hasError, isTrue);
    expect(state.error.toString(), contains('Ollama API error'));
  });

  test('changing the URL family key starts a fresh fetch', () async {
    int callCount = 0;
    final client = MockClient((request) async {
      callCount++;
      return http.Response(
        jsonEncode({
          'models': [
            {'name': 'm-${request.url.host}', 'size': 1}
          ],
        }),
        200,
      );
    });
    final container = makeContainer(client: client);
    addTearDown(container.dispose);

    final subA = keepAlive(container, 'http://a:11434');
    final subB = keepAlive(container, 'http://b:11434');
    addTearDown(subA.close);
    addTearDown(subB.close);

    await container.read(ollamaModelListProvider('http://a:11434').future);
    await container.read(ollamaModelListProvider('http://b:11434').future);

    expect(callCount, 2);
  });

  test('autoDispose drops the cached entry once nothing watches it', () async {
    final container = makeContainer(client: makeClient());
    addTearDown(container.dispose);

    final provider = ollamaModelListProvider('http://localhost:11434');
    final sub = container.listen<AsyncValue<List<String>>>(
      provider,
      (_, _) {},
    );
    await container.read(provider.future);

    sub.close();
    // Allow the autoDispose timer to fire.
    await Future<void>.delayed(Duration.zero);

    // After all listeners detach, the provider state is disposed; reading it
    // again starts a fresh fetch (back in loading state).
    final firstState = container.read(provider);
    expect(firstState, isA<AsyncLoading<List<String>>>());
  });

  test('invalidate causes a re-fetch and emits loading then data', () async {
    int callCount = 0;
    final client = MockClient((request) async {
      callCount++;
      return http.Response(
        jsonEncode({
          'models': [
            {'name': 'm$callCount', 'size': 1}
          ],
        }),
        200,
      );
    });
    final container = makeContainer(client: client);
    addTearDown(container.dispose);

    final provider = ollamaModelListProvider('http://localhost:11434');
    final sub = container.listen(provider, (_, _) {});
    addTearDown(sub.close);

    await container.read(provider.future);
    expect(callCount, 1);

    container.invalidate(provider);
    await container.read(provider.future);
    expect(callCount, 2);
  });
}
