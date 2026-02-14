import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/llm_summary/domain/llm_config.dart';
import 'package:novel_viewer/features/settings/data/font_family.dart';
import 'package:novel_viewer/features/settings/data/settings_repository.dart';
import 'package:novel_viewer/features/settings/data/text_display_mode.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';

class SettingsDialog extends ConsumerStatefulWidget {
  const SettingsDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => const SettingsDialog(),
    );
  }

  @override
  ConsumerState<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends ConsumerState<SettingsDialog> {
  late LlmProvider _llmProvider;
  late TextEditingController _baseUrlController;
  late TextEditingController _apiKeyController;
  late TextEditingController _modelController;

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
    _apiKeyController = TextEditingController(text: config.apiKey);
    _modelController = TextEditingController(text: config.model);
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _apiKeyController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  Future<void> _saveLlmConfig() async {
    final repo = ref.read(settingsRepositoryProvider);
    await repo.setLlmConfig(LlmConfig(
      provider: _llmProvider,
      baseUrl: _baseUrlController.text,
      apiKey: _apiKeyController.text,
      model: _modelController.text,
    ));
    ref.invalidate(settingsRepositoryProvider);
  }

  @override
  Widget build(BuildContext context) {
    final displayMode = ref.watch(displayModeProvider);
    final fontSize = ref.watch(fontSizeProvider);
    final fontFamily = ref.watch(fontFamilyProvider);

    return AlertDialog(
      title: const Text('設定'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                title: const Text('縦書き表示'),
                subtitle: Text(
                  displayMode == TextDisplayMode.vertical ? '縦書き' : '横書き',
                ),
                value: displayMode == TextDisplayMode.vertical,
                onChanged: (value) {
                  ref.read(displayModeProvider.notifier).setMode(
                        value
                            ? TextDisplayMode.vertical
                            : TextDisplayMode.horizontal,
                      );
                },
              ),
              ListTile(
                title: const Text('フォントサイズ'),
                subtitle: Slider(
                  value: fontSize,
                  min: SettingsRepository.minFontSize,
                  max: SettingsRepository.maxFontSize,
                  divisions:
                      (SettingsRepository.maxFontSize - SettingsRepository.minFontSize).toInt(),
                  label: fontSize.toStringAsFixed(1),
                  onChanged: (value) {
                    ref.read(fontSizeProvider.notifier).previewFontSize(value);
                  },
                  onChangeEnd: (_) {
                    ref.read(fontSizeProvider.notifier).persistFontSize();
                  },
                ),
                trailing: Text(fontSize.toStringAsFixed(1)),
              ),
              ListTile(
                title: const Text('フォント種別'),
                subtitle: DropdownButton<FontFamily>(
                  value: fontFamily,
                  isExpanded: true,
                  onChanged: (value) {
                    if (value != null) {
                      ref
                          .read(fontFamilyProvider.notifier)
                          .setFontFamily(value);
                    }
                  },
                  items: FontFamily.values.map((family) {
                    return DropdownMenuItem<FontFamily>(
                      value: family,
                      child: Text(family.displayName),
                    );
                  }).toList(),
                ),
              ),
              const Divider(),
              ListTile(
                title: const Text('LLMプロバイダ'),
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
                  items: const [
                    DropdownMenuItem(
                      value: LlmProvider.none,
                      child: Text('未設定'),
                    ),
                    DropdownMenuItem(
                      value: LlmProvider.openai,
                      child: Text('OpenAI互換API'),
                    ),
                    DropdownMenuItem(
                      value: LlmProvider.ollama,
                      child: Text('Ollama'),
                    ),
                  ],
                ),
              ),
              if (_llmProvider != LlmProvider.none) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: _baseUrlController,
                    decoration: const InputDecoration(
                      labelText: 'エンドポイントURL',
                    ),
                    onChanged: (_) => _saveLlmConfig(),
                  ),
                ),
                if (_llmProvider == LlmProvider.openai)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _apiKeyController,
                      decoration: const InputDecoration(
                        labelText: 'APIキー',
                      ),
                      obscureText: true,
                      onChanged: (_) => _saveLlmConfig(),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: _modelController,
                    decoration: const InputDecoration(
                      labelText: 'モデル名',
                    ),
                    onChanged: (_) => _saveLlmConfig(),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('閉じる'),
        ),
      ],
    );
  }
}
