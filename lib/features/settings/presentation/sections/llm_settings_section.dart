import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/llm_summary/data/ollama_client.dart';
import 'package:novel_viewer/features/llm_summary/domain/llm_config.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';

class LlmSettingsSection extends ConsumerStatefulWidget {
  const LlmSettingsSection({super.key});

  @override
  ConsumerState<LlmSettingsSection> createState() =>
      _LlmSettingsSectionState();
}

class _LlmSettingsSectionState extends ConsumerState<LlmSettingsSection> {
  late LlmProvider _llmProvider;
  late TextEditingController _baseUrlController;
  late TextEditingController _apiKeyController;
  late TextEditingController _modelController;

  String? _selectedOllamaModel;
  String _persistedApiKey = '';

  List<String> _ollamaModels = [];
  bool _ollamaModelsLoading = false;
  String? _ollamaModelsError;
  int _fetchGeneration = 0;

  @override
  void initState() {
    super.initState();
    final repo = ref.read(settingsRepositoryProvider);
    final config = repo.getLlmConfig();
    _llmProvider = config.provider;
    _baseUrlController = TextEditingController(
      text: config.baseUrl.isEmpty && config.provider == LlmProvider.ollama
          ? 'http://localhost:11434'
          : config.baseUrl,
    );
    _apiKeyController = TextEditingController();
    _modelController = TextEditingController(text: config.model);
    _selectedOllamaModel = config.model.isEmpty ? null : config.model;

    _loadApiKey();
    if (_llmProvider == LlmProvider.ollama) {
      _fetchOllamaModels();
    }
  }

  @override
  void dispose() {
    _fetchGeneration++;
    _baseUrlController.dispose();
    _apiKeyController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  Future<void> _loadApiKey() async {
    final repo = ref.read(settingsRepositoryProvider);
    final apiKey = await repo.getApiKey();
    if (!mounted) return;
    if (_apiKeyController.text.isNotEmpty) return;
    _apiKeyController.text = apiKey;
    _persistedApiKey = apiKey;
  }

  Future<void> _fetchOllamaModels() async {
    final generation = ++_fetchGeneration;

    setState(() {
      _ollamaModelsLoading = true;
      _ollamaModelsError = null;
    });

    try {
      final httpClient = ref.read(httpClientProvider);
      final models = await OllamaClient.fetchModels(
        baseUrl: _baseUrlController.text,
        httpClient: httpClient,
      );

      if (!mounted || generation != _fetchGeneration) return;

      final shouldClearSelection = _selectedOllamaModel != null &&
          !models.contains(_selectedOllamaModel);

      setState(() {
        _ollamaModels = models;
        _ollamaModelsLoading = false;
        if (shouldClearSelection) {
          _selectedOllamaModel = null;
          _modelController.text = '';
        }
      });

      if (shouldClearSelection) {
        _saveLlmConfig();
      }
    } catch (e) {
      if (!mounted || generation != _fetchGeneration) return;
      setState(() {
        _ollamaModelsLoading = false;
        _ollamaModelsError = e.toString();
      });
    }
  }

  Future<void> _saveLlmConfig() async {
    final repo = ref.read(settingsRepositoryProvider);
    await repo.setLlmConfig(LlmConfig(
      provider: _llmProvider,
      baseUrl: _baseUrlController.text,
      model: _modelController.text,
    ));
    if (_apiKeyController.text != _persistedApiKey) {
      await repo.setApiKey(_apiKeyController.text);
      _persistedApiKey = _apiKeyController.text;
    }
    ref.invalidate(settingsRepositoryProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          title: Text(l10n.settings_llmProviderTitle),
          subtitle: DropdownButton<LlmProvider>(
            value: _llmProvider,
            isExpanded: true,
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                _llmProvider = value;
                if (value == LlmProvider.ollama &&
                    _baseUrlController.text.isEmpty) {
                  _baseUrlController.text = 'http://localhost:11434';
                }
              });
              _saveLlmConfig();
              if (value == LlmProvider.ollama) {
                _fetchOllamaModels();
              }
            },
            items: [
              DropdownMenuItem(
                value: LlmProvider.none,
                child: Text(l10n.settings_llmProviderNone),
              ),
              DropdownMenuItem(
                value: LlmProvider.openai,
                child: Text(l10n.settings_llmProviderOpenai),
              ),
              DropdownMenuItem(
                value: LlmProvider.ollama,
                child: Text(l10n.settings_llmProviderOllama),
              ),
            ],
          ),
        ),
        if (_llmProvider != LlmProvider.none) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _baseUrlController,
              decoration: InputDecoration(
                labelText: l10n.settings_endpointUrlLabel,
              ),
              onChanged: (_) => _saveLlmConfig(),
            ),
          ),
          if (_llmProvider == LlmProvider.openai) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _apiKeyController,
                decoration: InputDecoration(
                  labelText: l10n.settings_apiKeyLabel,
                ),
                obscureText: true,
                onChanged: (_) => _saveLlmConfig(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _modelController,
                decoration: InputDecoration(
                  labelText: l10n.settings_modelNameLabel,
                ),
                onChanged: (_) => _saveLlmConfig(),
              ),
            ),
          ],
          if (_llmProvider == LlmProvider.ollama) _buildOllamaModelSelector(),
        ],
      ],
    );
  }

  Widget _buildOllamaModelSelector() {
    final l10n = AppLocalizations.of(context)!;
    if (_ollamaModelsLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 8),
            Text(l10n.settings_modelListFetching),
          ],
        ),
      );
    }

    if (_ollamaModelsError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                l10n.settings_modelListFetchError(_ollamaModelsError!),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _fetchOllamaModels,
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: DropdownButton<String>(
              value: _selectedOllamaModel,
              isExpanded: true,
              hint: Text(l10n.settings_selectModelHint),
              onChanged: (value) {
                setState(() {
                  _selectedOllamaModel = value;
                  _modelController.text = value ?? '';
                });
                _saveLlmConfig();
              },
              items: _ollamaModels.map((model) {
                return DropdownMenuItem<String>(
                  value: model,
                  child: Text(model),
                );
              }).toList(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchOllamaModels,
          ),
        ],
      ),
    );
  }
}
