import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/llm_summary/data/ollama_client.dart';
import 'package:novel_viewer/features/llm_summary/domain/llm_config.dart';
import 'package:novel_viewer/features/settings/data/font_family.dart';
import 'package:novel_viewer/features/settings/data/settings_repository.dart';
import 'package:novel_viewer/features/settings/data/text_display_mode.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';
import 'package:novel_viewer/features/tts/providers/tts_model_download_providers.dart';
import 'package:novel_viewer/features/tts/providers/tts_settings_providers.dart';

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
  late TextEditingController _ttsModelDirController;
  List<String> _voiceFiles = [];
  bool _isDragging = false;

  List<String> _ollamaModels = [];
  bool _ollamaModelsLoading = false;
  String? _ollamaModelsError;
  String? _selectedOllamaModel;
  int _fetchGeneration = 0;

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
    _apiKeyController = TextEditingController(text: config.apiKey);
    _modelController = TextEditingController(text: config.model);
    _selectedOllamaModel = config.model.isEmpty ? null : config.model;

    _ttsModelDirController =
        TextEditingController(text: repo.getTtsModelDir());
    _loadVoiceFiles();

    if (_llmProvider == LlmProvider.ollama) {
      _fetchOllamaModels();
    }
  }

  @override
  void dispose() {
    _fetchGeneration++;
    _tabController.dispose();
    _baseUrlController.dispose();
    _apiKeyController.dispose();
    _modelController.dispose();
    _ttsModelDirController.dispose();
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
        _ollamaModelsError = 'モデル一覧の取得エラー: $e';
      });
    }
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
    ref.listen<String>(ttsModelDirProvider, (previous, next) {
      if (_ttsModelDirController.text != next) {
        _ttsModelDirController.text = next;
      }
    });

    return AlertDialog(
      title: const Text('設定'),
      content: SizedBox(
        width: 400,
        height: 500,
        child: Column(
          children: [
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: '一般'),
                Tab(text: '読み上げ'),
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
          child: const Text('閉じる'),
        ),
      ],
    );
  }

  Widget _buildGeneralTab() {
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
          SwitchListTile(
            title: const Text('ダークモード'),
            subtitle: Text(
              themeMode == ThemeMode.dark ? 'ダーク' : 'ライト',
            ),
            value: themeMode == ThemeMode.dark,
            onChanged: (value) {
              ref.read(themeModeProvider.notifier).setThemeMode(
                    value ? ThemeMode.dark : ThemeMode.light,
                  );
            },
          ),
          ListTile(
            title: const Text('フォントサイズ'),
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
            title: const Text('フォント種別'),
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
            title: const Text('列間隔'),
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
                if (value == LlmProvider.ollama) {
                  _fetchOllamaModels();
                }
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
            if (_llmProvider == LlmProvider.openai) ...[
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
            if (_llmProvider == LlmProvider.ollama) _buildOllamaModelSelector(),
          ],
        ],
      ),
    );
  }

  Widget _buildModelDownloadSection() {
    final downloadState = ref.watch(ttsModelDownloadProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: switch (downloadState) {
        TtsModelDownloadIdle() => ElevatedButton.icon(
            onPressed: () {
              ref.read(ttsModelDownloadProvider.notifier).startDownload();
            },
            icon: const Icon(Icons.download),
            label: const Text('モデルデータダウンロード'),
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
                  const Text('モデルダウンロード済み'),
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
                'エラー: $message',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () {
                  ref.read(ttsModelDownloadProvider.notifier).startDownload();
                },
                child: const Text('再試行'),
              ),
            ],
          ),
      },
    );
  }

  Widget _buildTtsTab() {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          _buildModelDownloadSection(),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _ttsModelDirController,
              decoration: InputDecoration(
                labelText: 'モデルディレクトリ',
                hintText: 'GGUFモデルファイルを含むフォルダ',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.folder_open),
                  onPressed: _pickTtsModelDir,
                ),
              ),
              onChanged: (value) {
                ref
                    .read(ttsModelDirProvider.notifier)
                    .setTtsModelDir(value);
              },
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildVoiceReferenceSelector(),
          ),
        ],
      ),
    );
  }

  Future<void> _pickTtsModelDir() async {
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'TTSモデルディレクトリを選択',
    );
    if (result != null) {
      _ttsModelDirController.text = result;
      ref.read(ttsModelDirProvider.notifier).setTtsModelDir(result);
    }
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
                      labelText: 'リファレンス音声ファイル',
                      hintText: hasFiles
                          ? null
                          : 'voicesフォルダに音声ファイルを配置してください',
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: '',
                        child: Text('なし（デフォルト音声）'),
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
                    tooltip: 'ファイル名を変更',
                    onPressed: () =>
                        _showRenameDialog(effectiveValue),
                  ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'ファイル一覧を更新',
                  onPressed: _loadVoiceFiles,
                ),
                IconButton(
                  icon: const Icon(Icons.folder_open),
                  tooltip: 'voicesフォルダを開く',
                  onPressed: () {
                    final service = ref.read(voiceReferenceServiceProvider);
                    service?.openVoicesDirectory();
                  },
                ),
              ],
            ),
            if (_isDragging)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('音声ファイルをここにドロップ'),
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
          const SnackBar(content: Text('先にライブラリを選択してください')),
        );
      }
      return;
    }

    final errors = <String>[];
    for (final xFile in details.files) {
      try {
        await service.addVoiceFile(xFile.path);
      } on ArgumentError catch (e) {
        errors.add('${e.message}');
      } on StateError catch (e) {
        errors.add(e.message);
      } on FileSystemException catch (e) {
        errors.add('ファイル操作エラー: ${e.osError?.message ?? e.message}');
      }
    }

    await _loadVoiceFiles();

    if (errors.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errors.join('\n'))),
      );
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
    if (_ollamaModelsLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 8),
            Text('モデル一覧を取得中...'),
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
                _ollamaModelsError!,
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
              hint: const Text('モデルを選択'),
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
      return '同名のファイルが既に存在します';
    }
    return null;
  }

  bool get _canConfirm =>
      _controller.text.isNotEmpty &&
      _errorText == null &&
      _newFileName != widget.currentFileName;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('ファイル名の変更'),
      content: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'ファイル名',
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
          child: const Text('キャンセル'),
        ),
        TextButton(
          onPressed: _canConfirm
              ? () => Navigator.of(context).pop(_newFileName)
              : null,
          child: const Text('変更'),
        ),
      ],
    );
  }
}
