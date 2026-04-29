import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/llm_summary/data/ollama_client.dart';
import 'package:novel_viewer/features/llm_summary/domain/llm_config.dart';
import 'package:novel_viewer/features/settings/data/font_family.dart';
import 'package:novel_viewer/features/settings/data/settings_repository.dart';
import 'package:novel_viewer/features/settings/data/text_display_mode.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';
import 'package:novel_viewer/features/tts/data/piper_model_download_service.dart';
import 'package:novel_viewer/features/tts/data/tts_engine_type.dart';
import 'package:novel_viewer/features/tts/data/tts_language.dart';
import 'package:novel_viewer/features/tts/data/tts_model_size.dart';
import 'package:novel_viewer/features/tts/presentation/voice_recording_dialog.dart';
import 'package:novel_viewer/features/tts/providers/piper_model_download_providers.dart';
import 'package:novel_viewer/features/tts/providers/tts_model_download_providers.dart';
import 'package:novel_viewer/features/tts/providers/tts_settings_providers.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';

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

class _SettingsDialogState extends ConsumerState<SettingsDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late LlmProvider _llmProvider;
  late TextEditingController _baseUrlController;
  late TextEditingController _apiKeyController;
  late TextEditingController _modelController;
  List<String> _voiceFiles = [];
  bool _isDragging = false;

  List<String> _ollamaModels = [];
  bool _ollamaModelsLoading = false;
  String? _ollamaModelsError;
  String? _selectedOllamaModel;
  int _fetchGeneration = 0;
  String _persistedApiKey = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

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
    _loadVoiceFiles();

    if (_llmProvider == LlmProvider.ollama) {
      _fetchOllamaModels();
    }
  }

  Future<void> _loadApiKey() async {
    final repo = ref.read(settingsRepositoryProvider);
    final apiKey = await repo.getApiKey();
    if (!mounted) return;
    // If the user has already started typing before secure storage returned,
    // do not clobber their input with the stored value.
    if (_apiKeyController.text.isNotEmpty) return;
    _apiKeyController.text = apiKey;
    _persistedApiKey = apiKey;
  }

  @override
  void dispose() {
    _fetchGeneration++;
    _tabController.dispose();
    _baseUrlController.dispose();
    _apiKeyController.dispose();
    _modelController.dispose();
    super.dispose();
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
    // Avoid hitting the OS keychain on every keystroke when only the URL or
    // model field changed.
    if (_apiKeyController.text != _persistedApiKey) {
      await repo.setApiKey(_apiKeyController.text);
      _persistedApiKey = _apiKeyController.text;
    }
    ref.invalidate(settingsRepositoryProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.settings_title),
      content: SizedBox(
        width: 400,
        height: 500,
        child: Column(
          children: [
            TabBar(
              controller: _tabController,
              tabs: [
                Tab(text: l10n.settings_generalTabLabel),
                Tab(text: l10n.settings_ttsTabLabel),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildGeneralTab(),
                  _buildTtsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.common_closeButton),
        ),
      ],
    );
  }

  Widget _buildGeneralTab() {
    final l10n = AppLocalizations.of(context)!;
    final locale = ref.watch(localeProvider);
    final displayMode = ref.watch(displayModeProvider);
    final themeMode = ref.watch(themeModeProvider);
    final fontSize = ref.watch(fontSizeProvider);
    final fontFamily = ref.watch(fontFamilyProvider);
    final columnSpacing = ref.watch(columnSpacingProvider);

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            title: Text(l10n.settings_languageTitle),
            subtitle: DropdownButton<Locale>(
              value: locale,
              isExpanded: true,
              onChanged: (value) {
                if (value != null) {
                  ref.read(localeProvider.notifier).setLocale(value);
                }
              },
              items: const [
                DropdownMenuItem(
                  value: Locale('ja'),
                  child: Text('日本語'),
                ),
                DropdownMenuItem(
                  value: Locale('en'),
                  child: Text('English'),
                ),
                DropdownMenuItem(
                  value: Locale('zh'),
                  child: Text('中文'),
                ),
              ],
            ),
          ),
          SwitchListTile(
            title: Text(l10n.settings_verticalDisplayTitle),
            subtitle: Text(
              displayMode == TextDisplayMode.vertical
                  ? l10n.settings_verticalDisplayVertical
                  : l10n.settings_verticalDisplayHorizontal,
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
          SwitchListTile(
            title: Text(l10n.settings_darkModeTitle),
            subtitle: Text(
              themeMode == ThemeMode.dark
                  ? l10n.settings_darkModeDark
                  : l10n.settings_darkModeLight,
            ),
            value: themeMode == ThemeMode.dark,
            onChanged: (value) {
              ref.read(themeModeProvider.notifier).setThemeMode(
                    value ? ThemeMode.dark : ThemeMode.light,
                  );
            },
          ),
          ListTile(
            title: Text(l10n.settings_fontSizeTitle),
            subtitle: Slider(
              value: fontSize,
              min: SettingsRepository.minFontSize,
              max: SettingsRepository.maxFontSize,
              divisions: (SettingsRepository.maxFontSize -
                      SettingsRepository.minFontSize)
                  .toInt(),
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
            title: Text(l10n.settings_fontFamilyTitle),
            subtitle: DropdownButton<FontFamily>(
              value: fontFamily,
              isExpanded: true,
              onChanged: (value) {
                if (value != null) {
                  ref.read(fontFamilyProvider.notifier).setFontFamily(value);
                }
              },
              items: FontFamily.availableFonts.map((family) {
                return DropdownMenuItem<FontFamily>(
                  value: family,
                  child: Text(family.displayName),
                );
              }).toList(),
            ),
          ),
          ListTile(
            title: Text(l10n.settings_columnSpacingTitle),
            subtitle: Slider(
              value: columnSpacing,
              min: SettingsRepository.minColumnSpacing,
              max: SettingsRepository.maxColumnSpacing,
              divisions: (SettingsRepository.maxColumnSpacing -
                      SettingsRepository.minColumnSpacing)
                  .toInt(),
              label: columnSpacing.toStringAsFixed(1),
              onChanged: (value) {
                ref
                    .read(columnSpacingProvider.notifier)
                    .previewColumnSpacing(value);
              },
              onChangeEnd: (_) {
                ref
                    .read(columnSpacingProvider.notifier)
                    .persistColumnSpacing();
              },
            ),
            trailing: Text(columnSpacing.toStringAsFixed(1)),
          ),
          const Divider(),
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
      ),
    );
  }

  Widget _buildModelDownloadSection() {
    final l10n = AppLocalizations.of(context)!;
    final downloadState = ref.watch(ttsModelDownloadProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: switch (downloadState) {
        TtsModelDownloadIdle() => ElevatedButton.icon(
            onPressed: () {
              ref.read(ttsModelDownloadProvider.notifier).startDownload();
            },
            icon: const Icon(Icons.download),
            label: Text(l10n.settings_modelDataDownload),
          ),
        TtsModelDownloadDownloading(:final currentFile, :final progress) =>
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (currentFile.isNotEmpty)
                Text(currentFile, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 4),
              LinearProgressIndicator(value: progress),
              if (progress != null)
                Text(
                  '${(progress * 100).toStringAsFixed(0)}%',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
        TtsModelDownloadCompleted(:final modelsDir) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.check_circle,
                      color: Theme.of(context).colorScheme.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(l10n.settings_modelDownloadCompleted),
                ],
              ),
              if (modelsDir != null) ...[
                const SizedBox(height: 4),
                Text(
                  modelsDir,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        TtsModelDownloadError(:final message) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.common_errorPrefix(message),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () {
                  ref.read(ttsModelDownloadProvider.notifier).startDownload();
                },
                child: Text(l10n.settings_retryButton),
              ),
            ],
          ),
      },
    );
  }

  Widget _buildModelSizeSelector() {
    final l10n = AppLocalizations.of(context)!;
    final modelSize = ref.watch(ttsModelSizeProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.settings_voiceModelTitle, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<TtsModelSize>(
              segments: [
                ButtonSegment(
                  value: TtsModelSize.small,
                  label: Text(l10n.settings_voiceModelSmall),
                ),
                ButtonSegment(
                  value: TtsModelSize.large,
                  label: Text(l10n.settings_voiceModelLarge),
                ),
              ],
              selected: {modelSize},
              onSelectionChanged: (selected) {
                ref
                    .read(ttsModelSizeProvider.notifier)
                    .setTtsModelSize(selected.first);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageSelector() {
    final l10n = AppLocalizations.of(context)!;
    final language = ref.watch(ttsLanguageProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: DropdownButtonFormField<TtsLanguage>(
        initialValue: language,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: l10n.settings_ttsLanguageLabel,
        ),
        items: TtsLanguage.values.map((lang) {
          return DropdownMenuItem(
            value: lang,
            child: Text(lang.displayName),
          );
        }).toList(),
        onChanged: (value) {
          if (value != null) {
            ref.read(ttsLanguageProvider.notifier).setLanguage(value);
          }
        },
      ),
    );
  }

  Widget _buildTtsTab() {
    final engineType = ref.watch(ttsEngineTypeProvider);

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          _buildEngineSelector(),
          const SizedBox(height: 16),
          if (engineType == TtsEngineType.qwen3) ...[
            _buildLanguageSelector(),
            const SizedBox(height: 16),
            _buildModelSizeSelector(),
            const SizedBox(height: 16),
            _buildModelDownloadSection(),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildVoiceReferenceSelector(),
            ),
          ],
          if (engineType == TtsEngineType.piper) ...[
            _buildPiperModelSelector(),
            const SizedBox(height: 16),
            _buildPiperModelDownloadSection(),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            _buildPiperSynthesisParams(),
          ],
        ],
      ),
    );
  }

  Widget _buildEngineSelector() {
    final l10n = AppLocalizations.of(context)!;
    final engineType = ref.watch(ttsEngineTypeProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.settings_ttsEngine,
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<TtsEngineType>(
              segments: TtsEngineType.values
                  .map((e) => ButtonSegment(value: e, label: Text(e.label)))
                  .toList(),
              selected: {engineType},
              onSelectionChanged: (selected) {
                ref
                    .read(ttsEngineTypeProvider.notifier)
                    .setEngineType(selected.first);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPiperModelSelector() {
    final l10n = AppLocalizations.of(context)!;
    final modelName = ref.watch(piperModelNameProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: DropdownButtonFormField<String>(
        initialValue: modelName,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: l10n.settings_modelLabel,
        ),
        items: const [
          DropdownMenuItem(
            value: PiperModelDownloadService.defaultModelName,
            child: Text(PiperModelDownloadService.defaultModelName),
          ),
        ],
        onChanged: (value) {
          if (value != null) {
            ref
                .read(piperModelNameProvider.notifier)
                .setPiperModelName(value);
          }
        },
      ),
    );
  }

  Widget _buildPiperModelDownloadSection() {
    final l10n = AppLocalizations.of(context)!;
    final downloadState = ref.watch(piperModelDownloadProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: switch (downloadState) {
        PiperModelDownloadIdle() => ElevatedButton.icon(
            icon: const Icon(Icons.download),
            label: Text(l10n.settings_modelDataDownload),
            onPressed: () {
              ref
                  .read(piperModelDownloadProvider.notifier)
                  .startDownload();
            },
          ),
        PiperModelDownloadDownloading(:final currentFile, :final progress) =>
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(currentFile),
              const SizedBox(height: 8),
              LinearProgressIndicator(value: progress),
              if (progress != null)
                Text('${(progress * 100).toStringAsFixed(1)}%'),
            ],
          ),
        PiperModelDownloadCompleted(:final modelsDir) => Row(
            children: [
              Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${l10n.settings_piperDownloaded}${modelsDir != null ? '\n$modelsDir' : ''}',
                ),
              ),
            ],
          ),
        PiperModelDownloadError(:final message) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () {
                  ref
                      .read(piperModelDownloadProvider.notifier)
                      .startDownload();
                },
                child: Text(l10n.settings_retryButton),
              ),
            ],
          ),
      },
    );
  }

  Widget _buildPiperSynthesisParams() {
    final l10n = AppLocalizations.of(context)!;
    final lengthScale = ref.watch(piperLengthScaleProvider);
    final noiseScale = ref.watch(piperNoiseScaleProvider);
    final noiseW = ref.watch(piperNoiseWProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${l10n.settings_piperLengthScale}: ${lengthScale.toStringAsFixed(1)}'),
          Slider(
            value: lengthScale,
            min: 0.5,
            max: 2.0,
            divisions: 15,
            label: lengthScale.toStringAsFixed(1),
            onChanged: (value) {
              ref.read(piperLengthScaleProvider.notifier).setValue(value);
            },
          ),
          const SizedBox(height: 8),
          Text('${l10n.settings_piperNoiseScale}: ${noiseScale.toStringAsFixed(3)}'),
          Slider(
            value: noiseScale,
            min: 0.0,
            max: 1.0,
            divisions: 20,
            label: noiseScale.toStringAsFixed(3),
            onChanged: (value) {
              ref.read(piperNoiseScaleProvider.notifier).setValue(value);
            },
          ),
          const SizedBox(height: 8),
          Text('${l10n.settings_piperNoiseW}: ${noiseW.toStringAsFixed(3)}'),
          Slider(
            value: noiseW,
            min: 0.0,
            max: 1.0,
            divisions: 20,
            label: noiseW.toStringAsFixed(3),
            onChanged: (value) {
              ref.read(piperNoiseWProvider.notifier).setValue(value);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _loadVoiceFiles() async {
    final service = ref.read(voiceReferenceServiceProvider);
    if (service == null) return;
    final files = await service.listVoiceFiles();
    if (mounted) {
      setState(() {
        _voiceFiles = files;
      });
    }
  }

  Widget _buildVoiceReferenceSelector() {
    final l10n = AppLocalizations.of(context)!;
    final currentFileName = ref.watch(ttsRefWavPathProvider);
    final hasFiles = _voiceFiles.isNotEmpty;

    // If saved file no longer exists in the list, treat as unselected
    final effectiveValue =
        _voiceFiles.contains(currentFileName) ? currentFileName : '';

    return DropTarget(
      onDragEntered: (_) => setState(() => _isDragging = true),
      onDragExited: (_) => setState(() => _isDragging = false),
      onDragDone: (details) async {
        setState(() => _isDragging = false);
        await _handleFileDrop(details);
      },
      child: Container(
        decoration: BoxDecoration(
          border: _isDragging
              ? Border.all(
                  color: Theme.of(context).colorScheme.primary, width: 2)
              : null,
          borderRadius: BorderRadius.circular(8),
        ),
        padding: _isDragging ? const EdgeInsets.all(8) : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    // ignore: deprecated_member_use
                    value: effectiveValue,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: l10n.settings_referenceAudioLabel,
                      hintText: hasFiles
                          ? null
                          : l10n.settings_voicesPlacementHint,
                    ),
                    items: [
                      DropdownMenuItem(
                        value: '',
                        child: Text(l10n.settings_referenceAudioNone),
                      ),
                      ..._voiceFiles.map(
                        (file) =>
                            DropdownMenuItem(value: file, child: Text(file)),
                      ),
                    ],
                    onChanged: (value) {
                      ref
                          .read(ttsRefWavPathProvider.notifier)
                          .setTtsRefWavPath(value ?? '');
                    },
                  ),
                ),
                if (effectiveValue.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.edit),
                    tooltip: l10n.settings_renameFileTooltip,
                    onPressed: () =>
                        _showRenameDialog(effectiveValue),
                  ),
                IconButton(
                  icon: const Icon(Icons.mic),
                  tooltip: l10n.settings_recordVoiceTooltip,
                  onPressed: ref.read(voiceReferenceServiceProvider) != null
                      ? _showRecordingDialog
                      : null,
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: l10n.settings_refreshFileListTooltip,
                  onPressed: _loadVoiceFiles,
                ),
                IconButton(
                  icon: const Icon(Icons.folder_open),
                  tooltip: l10n.settings_openVoicesFolderTooltip,
                  onPressed: () {
                    final service = ref.read(voiceReferenceServiceProvider);
                    service?.openVoicesDirectory();
                  },
                ),
              ],
            ),
            if (_isDragging)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(l10n.settings_dragAudioFilesHere),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleFileDrop(DropDoneDetails details) async {
    final service = ref.read(voiceReferenceServiceProvider);
    if (service == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.settings_selectLibraryFirst)),
        );
      }
      return;
    }

    final l10n = AppLocalizations.of(context)!;
    final errors = <String>[];
    for (final xFile in details.files) {
      try {
        await service.addVoiceFile(xFile.path);
      } on ArgumentError catch (e) {
        errors.add('${e.message}');
      } on StateError catch (e) {
        errors.add(e.message);
      } on FileSystemException catch (e) {
        errors.add(l10n.settings_fileOperationError(e.osError?.message ?? e.message));
      }
    }

    await _loadVoiceFiles();

    if (errors.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errors.join('\n'))),
      );
    }
  }

  Future<void> _showRecordingDialog() async {
    final savedFileName = await VoiceRecordingDialog.show(
      context,
      existingFiles: _voiceFiles,
    );
    if (savedFileName != null) {
      await _loadVoiceFiles();
      ref.read(ttsRefWavPathProvider.notifier).setTtsRefWavPath(savedFileName);
    }
  }

  Future<void> _showRenameDialog(String currentFileName) async {
    final service = ref.read(voiceReferenceServiceProvider);
    if (service == null) return;

    final ext = p.extension(currentFileName);
    final nameWithoutExt = p.basenameWithoutExtension(currentFileName);

    final result = await showDialog<String>(
      context: context,
      builder: (context) => _RenameDialog(
        initialName: nameWithoutExt,
        extension: ext,
        existingFiles: _voiceFiles,
        currentFileName: currentFileName,
      ),
    );

    if (result != null && result != currentFileName) {
      try {
        await service.renameVoiceFile(currentFileName, result);
        ref.read(ttsRefWavPathProvider.notifier).setTtsRefWavPath(result);
        await _loadVoiceFiles();
      } on StateError catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message)),
          );
        }
      }
    }
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

class _RenameDialog extends StatefulWidget {
  final String initialName;
  final String extension;
  final List<String> existingFiles;
  final String currentFileName;

  const _RenameDialog({
    required this.initialName,
    required this.extension,
    required this.existingFiles,
    required this.currentFileName,
  });

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _newFileName => '${_controller.text}${widget.extension}';

  String? get _errorText {
    if (_controller.text.isEmpty) return null;
    if (_newFileName != widget.currentFileName &&
        widget.existingFiles.contains(_newFileName)) {
      return AppLocalizations.of(context)!.common_fileDuplicateError;
    }
    return null;
  }

  bool get _canConfirm =>
      _controller.text.isNotEmpty &&
      _errorText == null &&
      _newFileName != widget.currentFileName;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.settings_renameFileTitle),
      content: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              autofocus: true,
              decoration: InputDecoration(
                labelText: l10n.common_fileNameLabel,
                errorText: _errorText,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 8, top: 16),
            child: Text(
              widget.extension,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.common_cancelButton),
        ),
        TextButton(
          onPressed: _canConfirm
              ? () => Navigator.of(context).pop(_newFileName)
              : null,
          child: Text(l10n.common_changeButton),
        ),
      ],
    );
  }
}
