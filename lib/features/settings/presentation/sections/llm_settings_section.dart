import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/llm_summary/domain/llm_config.dart';
import 'package:novel_viewer/features/llm_summary/providers/ollama_model_list_provider.dart';
import 'package:novel_viewer/features/llm_summary/providers/on_device_llm_providers.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';

class LlmSettingsSection extends ConsumerStatefulWidget {
  const LlmSettingsSection({super.key});

  @override
  ConsumerState<LlmSettingsSection> createState() => _LlmSettingsSectionState();
}

class _LlmSettingsSectionState extends ConsumerState<LlmSettingsSection> {
  late LlmProvider _llmProvider;
  late TextEditingController _baseUrlController;
  late TextEditingController _apiKeyController;
  late TextEditingController _modelController;

  String _persistedApiKey = '';

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

    _loadApiKey();
  }

  String? get _selectedOllamaModel =>
      _modelController.text.isEmpty ? null : _modelController.text;

  @override
  void dispose() {
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

  Future<void> _saveLlmConfig() async {
    final repo = ref.read(settingsRepositoryProvider);
    await repo.setLlmConfig(
      LlmConfig(
        provider: _llmProvider,
        baseUrl: _baseUrlController.text,
        model: _modelController.text,
      ),
    );
    if (_apiKeyController.text != _persistedApiKey) {
      await repo.setApiKey(_apiKeyController.text);
      _persistedApiKey = _apiKeyController.text;
    }
    ref.invalidate(settingsRepositoryProvider);
  }

  void _onSavedModelMissing() {
    if (_modelController.text.isEmpty) return;
    setState(() {
      _modelController.text = '';
    });
    _saveLlmConfig();
  }

  /// The current selection as a config, so the section can ask it whether a
  /// provider is addressed by an endpoint rather than listing providers here.
  LlmConfig get _config => LlmConfig(provider: _llmProvider);

  /// Why the on-device model cannot be picked, or null when it can.
  ///
  /// Reads as null while the availability query is still in flight: the option
  /// is then briefly enabled, and selecting it in that window yields no client
  /// until the answer lands, which is the same state as the model going away
  /// a moment later.
  String? _onDeviceUnavailableReason(AppLocalizations l10n) {
    final availability = ref.watch(onDeviceModelAvailabilityProvider).value;
    return switch (availability) {
      null || OnDeviceModelAvailability.available => null,
      OnDeviceModelAvailability.deviceNotEligible =>
        l10n.settings_llmOnDeviceUnavailableDeviceNotEligible,
      OnDeviceModelAvailability.intelligenceNotEnabled =>
        l10n.settings_llmOnDeviceUnavailableIntelligenceOff,
      OnDeviceModelAvailability.modelNotReady =>
        l10n.settings_llmOnDeviceUnavailableModelNotReady,
      OnDeviceModelAvailability.unsupportedPlatform ||
      OnDeviceModelAvailability.unknown =>
        l10n.settings_llmOnDeviceUnavailableUnknown,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final platformCanHost = ref.watch(onDeviceLlmSupportedProvider);
    final onDeviceReason = platformCanHost
        ? _onDeviceUnavailableReason(l10n)
        : null;

    if (_llmProvider == LlmProvider.ollama) {
      ref.listen<AsyncValue<List<String>>>(
        ollamaModelListProvider(_baseUrlController.text),
        (_, next) {
          if (next case AsyncData(value: final models)) {
            if (_selectedOllamaModel != null &&
                !models.contains(_selectedOllamaModel)) {
              _onSavedModelMissing();
            }
          }
        },
      );
    }

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
              // Offered only where the platform could host the model. There it
              // stays visible even when it cannot be used, because two of the
              // three reasons are states the reader can leave and this is the
              // only place the app could say so.
              if (platformCanHost)
                DropdownMenuItem(
                  value: LlmProvider.appleOnDevice,
                  enabled: onDeviceReason == null,
                  child: Text(l10n.settings_llmProviderAppleOnDevice),
                ),
            ],
          ),
        ),
        // Outside the list, so it is readable without opening it.
        if (onDeviceReason != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              onDeviceReason,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        if (_config.needsServerSettings) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _baseUrlController,
              decoration: InputDecoration(
                labelText: l10n.settings_endpointUrlLabel,
              ),
              onChanged: (_) {
                // Rebuild so the watched ollamaModelListProvider family key
                // updates; autoDispose cancels the fetch for the old URL.
                setState(() {});
                _saveLlmConfig();
              },
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
    final url = _baseUrlController.text;
    final modelList = ref.watch(ollamaModelListProvider(url));

    if (modelList.hasError) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                l10n.settings_modelListFetchError(modelList.error.toString()),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => ref.invalidate(ollamaModelListProvider(url)),
            ),
          ],
        ),
      );
    }

    return modelList.when(
      data: (models) {
        // Saved model may not be in the fetched list (e.g., switching from
        // OpenAI carries a stale model name). Render unselected to avoid the
        // DropdownButton "value not in items" assertion; ref.listen clears
        // the persisted value on the next frame.
        final selected = models.contains(_selectedOllamaModel)
            ? _selectedOllamaModel
            : null;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: DropdownButton<String>(
                  value: selected,
                  isExpanded: true,
                  hint: Text(l10n.settings_selectModelHint),
                  onChanged: (value) {
                    setState(() {
                      _modelController.text = value ?? '';
                    });
                    _saveLlmConfig();
                  },
                  items: models
                      .map(
                        (model) => DropdownMenuItem<String>(
                          value: model,
                          child: Text(model),
                        ),
                      )
                      .toList(),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => ref.invalidate(ollamaModelListProvider(url)),
              ),
            ],
          ),
        );
      },
      loading: () => Padding(
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
      ),
      error: (error, _) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                l10n.settings_modelListFetchError(error.toString()),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => ref.invalidate(ollamaModelListProvider(url)),
            ),
          ],
        ),
      ),
    );
  }
}
