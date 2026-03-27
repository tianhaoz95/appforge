import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:snowglobe_openai/snowglobe_openai.dart';
import 'llm_abstraction/openai_handler.dart';
import 'forge_mode.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider with ChangeNotifier {
  bool _suggestExistingApps = true;
  bool _allowGeolocation = false;
  bool _allowAccelerometer = false;
  bool _allowNotifications = false;
  bool _allowBackendDatabase = false;
  bool _allowBackgroundExecution = false;
  bool _allowBackgroundNotifications = false;
  bool _allowBackgroundDatabase = false;
  bool _useLocalOpenAi = false;
  bool _useSnowglobeLocalModel = false;
  bool _isDownloadingModel = false;
  double _modelDownloadProgress = 0.0;
  bool _isModelDownloaded = false;
  bool _isEngineInitialized = false;
  String _localOpenAiUrl = '';
  bool _rememberMe = false;
  bool _halMode = false;
  String _rememberedEmail = '';
  String _localAvatarPath = '';
  String _systemPrompt = '';
  String _customSystemPrompt = '';
  String _defaultSystemPrompt = '';
  String _compactSystemPrompt = '';
  Map<String, String> _savedSystemPrompts = {};
  bool _useCompactPrompt = false;
  ThemeMode _themeMode = ThemeMode.system;
  ForgeMode _defaultForgeMode = ForgeMode.build;
  int _totalPromptTokens = 0;
  int _totalCandidateTokens = 0;
  int _totalTotalTokens = 0;
  int _totalThoughtsTokens = 0;
  int _totalCachedTokens = 0;
  int _totalToolUseTokens = 0;

  static const String _keySuggestExistingApps = 'suggest_existing_apps';
  static const String _keyAllowGeolocation = 'allow_geolocation';
  static const String _keyAllowAccelerometer = 'allow_accelerometer';
  static const String _keyAllowNotifications = 'allow_notifications';
  static const String _keyAllowBackendDatabase = 'allow_backend_database';
  static const String _keyAllowBackgroundExecution = 'allow_background_execution';
  static const String _keyAllowBackgroundNotifications = 'allow_background_notifications';
  static const String _keyAllowBackgroundDatabase = 'allow_background_database';
  static const String _keyUseLocalOpenAi = 'use_local_openai';
  static const String _keyUseSnowglobeLocalModel = 'use_snowglobe_local_model';
  static const String _keyLocalOpenAiUrl = 'local_openai_url';
  static const String _keyRememberMe = 'remember_me';
  static const String _keyHalMode = 'hal_mode';
  static const String _keyRememberedEmail = 'remembered_email';
  static const String _keyLocalAvatarPath = 'local_avatar_path';
  static const String _keyCustomSystemPrompt = 'custom_system_prompt';
  static const String _keySavedSystemPrompts = 'saved_system_prompts';
  static const String _keyUseCompactPrompt = 'use_compact_prompt';
  static const String _keyThemeMode = 'theme_mode';
  static const String _keyDefaultForgeMode = 'default_forge_mode';
  static const String _keyTotalPromptTokens = 'total_prompt_tokens';
  static const String _keyTotalCandidateTokens = 'total_candidate_tokens';
  static const String _keyTotalTotalTokens = 'total_total_tokens';
  static const String _keyTotalThoughtsTokens = 'total_thoughts_tokens';
  static const String _keyTotalCachedTokens = 'total_cached_tokens';
  static const String _keyTotalToolUseTokens = 'total_tool_use_tokens';

  bool get suggestExistingApps => _suggestExistingApps;
  bool get allowGeolocation => _allowGeolocation;
  bool get allowAccelerometer => _allowAccelerometer;
  bool get allowNotifications => _allowNotifications;
  bool get allowBackendDatabase => _allowBackendDatabase;
  bool get allowBackgroundExecution => _allowBackgroundExecution;
  bool get allowBackgroundNotifications => _allowBackgroundNotifications;
  bool get allowBackgroundDatabase => _allowBackgroundDatabase;
  bool get useLocalOpenAi => _useLocalOpenAi;
  bool get useSnowglobeLocalModel => _useSnowglobeLocalModel;
  bool get isDownloadingModel => _isDownloadingModel;
  double get modelDownloadProgress => _modelDownloadProgress;
  bool get isModelDownloaded => _isModelDownloaded;
  bool get isEngineInitialized => _isEngineInitialized;
  String get localOpenAiUrl => _localOpenAiUrl;
  bool get rememberMe => _rememberMe;
  bool get halMode => _halMode;
  String get rememberedEmail => _rememberedEmail;
  String get localAvatarPath => _localAvatarPath;
  String get systemPrompt => _systemPrompt;
  String get customSystemPrompt => _customSystemPrompt;
  String get defaultSystemPrompt => _defaultSystemPrompt;
  String get compactSystemPrompt => _compactSystemPrompt;
  Map<String, String> get savedSystemPrompts => _savedSystemPrompts;
  bool get useCompactPrompt => _useCompactPrompt;
  ThemeMode get themeMode => _themeMode;
  ForgeMode get defaultForgeMode => _defaultForgeMode;
  int get totalPromptTokens => _totalPromptTokens;
  int get totalCandidateTokens => _totalCandidateTokens;
  int get totalTotalTokens => _totalTotalTokens;
  int get totalThoughtsTokens => _totalThoughtsTokens;
  int get totalCachedTokens => _totalCachedTokens;
  int get totalToolUseTokens => _totalToolUseTokens;

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _suggestExistingApps = prefs.getBool(_keySuggestExistingApps) ?? true;
    _allowGeolocation = prefs.getBool(_keyAllowGeolocation) ?? false;
    _allowAccelerometer = prefs.getBool(_keyAllowAccelerometer) ?? false;
    _allowNotifications = prefs.getBool(_keyAllowNotifications) ?? false;
    _allowBackendDatabase = prefs.getBool(_keyAllowBackendDatabase) ?? false;
    _allowBackgroundExecution = prefs.getBool(_keyAllowBackgroundExecution) ?? false;
    _allowBackgroundNotifications = prefs.getBool(_keyAllowBackgroundNotifications) ?? false;
    _allowBackgroundDatabase = prefs.getBool(_keyAllowBackgroundDatabase) ?? false;
    _useLocalOpenAi = prefs.getBool(_keyUseLocalOpenAi) ?? false;
    _useSnowglobeLocalModel = prefs.getBool(_keyUseSnowglobeLocalModel) ?? false;
    _localOpenAiUrl = prefs.getString(_keyLocalOpenAiUrl) ?? '';
    _rememberMe = prefs.getBool(_keyRememberMe) ?? false;
    _halMode = prefs.getBool(_keyHalMode) ?? false;
    _rememberedEmail = prefs.getString(_keyRememberedEmail) ?? '';
    _localAvatarPath = prefs.getString(_keyLocalAvatarPath) ?? '';
    _customSystemPrompt = prefs.getString(_keyCustomSystemPrompt) ?? '';
    _useCompactPrompt = prefs.getBool(_keyUseCompactPrompt) ?? false;
    
    final savedPromptsJson = prefs.getString(_keySavedSystemPrompts);
    if (savedPromptsJson != null) {
      try {
        final decoded = json.decode(savedPromptsJson) as Map<String, dynamic>;
        _savedSystemPrompts = decoded.map((key, value) => MapEntry(key, value as String));
      } catch (e) {
        debugPrint('Error decoding saved system prompts: $e');
        _savedSystemPrompts = {};
      }
    }

    _totalPromptTokens = prefs.getInt(_keyTotalPromptTokens) ?? 0;
    _totalCandidateTokens = prefs.getInt(_keyTotalCandidateTokens) ?? 0;
    _totalTotalTokens = prefs.getInt(_keyTotalTotalTokens) ?? 0;
    _totalThoughtsTokens = prefs.getInt(_keyTotalThoughtsTokens) ?? 0;
    _totalCachedTokens = prefs.getInt(_keyTotalCachedTokens) ?? 0;
    _totalToolUseTokens = prefs.getInt(_keyTotalToolUseTokens) ?? 0;
    
    final modeIndex = prefs.getInt(_keyDefaultForgeMode) ?? ForgeMode.build.index;
    _defaultForgeMode = ForgeMode.values[modeIndex];
    
    // Check if model file exists
    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      try {
        final appDocDir = await getApplicationDocumentsDirectory();
        final modelFile = File('${appDocDir.path}/model.gguf');
        final tokenizerFile = File('${appDocDir.path}/tokenizer.json');
        debugPrint('Checking for model at: ${modelFile.path}');
        _isModelDownloaded = await modelFile.exists() && await tokenizerFile.exists();
        
        // Try to see if engine is already initialized
        if (_isModelDownloaded) {
          final modelInfo = await SnowglobeOpenAI.getModelInfo();
          if (modelInfo != null) {
            _isEngineInitialized = true;
            debugPrint("Snowglobe engine already initialized (found model info)");
          }
        }
      } catch (e) {
        debugPrint("Error checking model file/engine: $e");
        _isModelDownloaded = false;
      }
    }

    notifyListeners();
  }

  Future<void> downloadModel() async {
    if (_isDownloadingModel) return;

    _isDownloadingModel = true;
    _modelDownloadProgress = 0.0;
    notifyListeners();

    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      final modelFile = File('${appDocDir.path}/model.gguf');
      final tokenizerFile = File('${appDocDir.path}/tokenizer.json');
      
      final client = http.Client();
      
      // Download Model
      debugPrint("Downloading model...");
      final modelRequest = http.Request('GET', Uri.parse('https://huggingface.co/unsloth/Qwen3.5-0.8B-GGUF/resolve/main/Qwen3.5-0.8B-Q4_K_M.gguf'));
      final modelResponse = await client.send(modelRequest);

      if (modelResponse.statusCode != 200) {
        throw Exception('Failed to download model: ${modelResponse.statusCode}');
      }

      final totalModelBytes = modelResponse.contentLength ?? 0;
      int receivedModelBytes = 0;

      final IOSink modelSink = modelFile.openWrite();
      await modelResponse.stream.forEach((List<int> chunk) {
        modelSink.add(chunk);
        receivedModelBytes += chunk.length;
        if (totalModelBytes > 0) {
          _modelDownloadProgress = (receivedModelBytes / totalModelBytes) * 0.9; // 90% for model
          notifyListeners();
        }
      });
      await modelSink.close();

      // Download Tokenizer
      debugPrint("Downloading tokenizer...");
      final tokenizerRequest = http.Request('GET', Uri.parse('https://huggingface.co/unsloth/Qwen3.5-0.8B-GGUF/resolve/main/tokenizer.json'));
      final tokenizerResponse = await client.send(tokenizerRequest);

      // If not in GGUF repo, try the base repo
      var finalTokenizerResponse = tokenizerResponse;
      if (tokenizerResponse.statusCode != 200) {
        debugPrint("Tokenizer not found in GGUF repo, trying base repo...");
        final baseTokenizerRequest = http.Request('GET', Uri.parse('https://huggingface.co/unsloth/Qwen3.5-0.8B/resolve/main/tokenizer.json'));
        finalTokenizerResponse = await client.send(baseTokenizerRequest);
      }

      if (finalTokenizerResponse.statusCode == 200) {
        final totalTokenizerBytes = finalTokenizerResponse.contentLength ?? 0;
        int receivedTokenizerBytes = 0;
        final IOSink tokenizerSink = tokenizerFile.openWrite();
        await finalTokenizerResponse.stream.forEach((List<int> chunk) {
          tokenizerSink.add(chunk);
          receivedTokenizerBytes += chunk.length;
          if (totalTokenizerBytes > 0) {
            _modelDownloadProgress = 0.9 + (receivedTokenizerBytes / totalTokenizerBytes) * 0.1; // last 10%
            notifyListeners();
          }
        });
        await tokenizerSink.close();
      } else {
        debugPrint("Warning: Could not download tokenizer.json (Status: ${finalTokenizerResponse.statusCode})");
      }

      client.close();

      _isModelDownloaded = true;
      
      // Initialize engine after download
      try {
        await ensureSnowglobeInitialized();
      } catch (e) {
        debugPrint("Snowglobe Rust bridge init during download: $e");
      }
      
      debugPrint("Initializing Snowglobe engine after download...");
      final result = await SnowglobeOpenAI.initEngine(
        cacheDir: appDocDir.path,
        config: const InitConfig(
          vocabShards: 1,
          maxGenLen: 2048,
          useExecutorch: false,
          backend: BackendType.llamaCpp,
          speculateTokens: 0,
        ),
      );
      debugPrint("Snowglobe engine initialization result after download: $result");
      _isEngineInitialized = true;
      notifyListeners();
      
    } catch (e) {
      debugPrint("Error downloading model: $e");
      rethrow;
    } finally {
      _isDownloadingModel = false;
      notifyListeners();
    }
  }

  Future<void> addTokenUsage(int prompt, int candidate, int total, {int thoughts = 0, int cached = 0, int toolUse = 0}) async {
    _totalPromptTokens += prompt;
    _totalCandidateTokens += candidate;
    _totalTotalTokens += total;
    _totalThoughtsTokens += thoughts;
    _totalCachedTokens += cached;
    _totalToolUseTokens += toolUse;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyTotalPromptTokens, _totalPromptTokens);
    await prefs.setInt(_keyTotalCandidateTokens, _totalCandidateTokens);
    await prefs.setInt(_keyTotalTotalTokens, _totalTotalTokens);
    await prefs.setInt(_keyTotalThoughtsTokens, _totalThoughtsTokens);
    await prefs.setInt(_keyTotalCachedTokens, _totalCachedTokens);
    await prefs.setInt(_keyTotalToolUseTokens, _totalToolUseTokens);
  }

  void setEngineInitialized(bool value) {
    if (_isEngineInitialized != value) {
      _isEngineInitialized = value;
      notifyListeners();
    }
  }

  void setSystemPrompt(String value) {
    if (_systemPrompt != value) {
      _systemPrompt = value;
      notifyListeners();
    }
  }

  void setDefaultSystemPrompt(String value) {
    _defaultSystemPrompt = value;
  }

  void setCompactSystemPrompt(String value) {
    _compactSystemPrompt = value;
  }

  Future<void> saveNamedSystemPrompt(String name, String prompt) async {
    _savedSystemPrompts[name] = prompt;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySavedSystemPrompts, json.encode(_savedSystemPrompts));
  }

  Future<void> deleteNamedSystemPrompt(String name) async {
    if (_savedSystemPrompts.containsKey(name)) {
      _savedSystemPrompts.remove(name);
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keySavedSystemPrompts, json.encode(_savedSystemPrompts));
    }
  }

  Future<void> setCustomSystemPrompt(String value) async {
    if (_customSystemPrompt != value) {
      _customSystemPrompt = value;
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyCustomSystemPrompt, value);
    }
  }

  Future<void> setUseCompactPrompt(bool value) async {
    if (_useCompactPrompt != value) {
      _useCompactPrompt = value;
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyUseCompactPrompt, value);
    }
  }

  Future<void> setHalMode(bool value) async {
    if (_halMode != value) {
      _halMode = value;
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyHalMode, value);
    }
  }

  Future<void> setLocalAvatarPath(String value) async {
    if (_localAvatarPath != value) {
      _localAvatarPath = value;
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyLocalAvatarPath, value);
    }
  }

  Future<void> setThemeMode(ThemeMode value) async {
    if (_themeMode != value) {
      _themeMode = value;
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyThemeMode, value.index);
    }
  }

  Future<void> setDefaultForgeMode(ForgeMode value) async {
    if (_defaultForgeMode != value) {
      _defaultForgeMode = value;
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyDefaultForgeMode, value.index);
    }
  }

  Future<void> setRememberMe(bool value) async {
    if (_rememberMe != value) {
      _rememberMe = value;
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyRememberMe, value);
    }
  }

  Future<void> setRememberedEmail(String value) async {
    if (_rememberedEmail != value) {
      _rememberedEmail = value;
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyRememberedEmail, value);
    }
  }

  Future<void> setSuggestExistingApps(bool value) async {
    if (_suggestExistingApps != value) {
      _suggestExistingApps = value;
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keySuggestExistingApps, value);
    }
  }

  Future<void> setUseLocalOpenAi(bool value) async {
    if (_useLocalOpenAi != value) {
      _useLocalOpenAi = value;
      if (value) {
        _useSnowglobeLocalModel = false;
      }
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyUseLocalOpenAi, value);
      if (value) {
        await prefs.setBool(_keyUseSnowglobeLocalModel, false);
      }
    }
  }

  Future<void> setUseSnowglobeLocalModel(bool value) async {
    if (_useSnowglobeLocalModel != value) {
      _useSnowglobeLocalModel = value;
      if (value) {
        _useLocalOpenAi = false;
        
        // Initialize engine if model is already downloaded
        if (_isModelDownloaded) {
          try {
            await ensureSnowglobeInitialized();
            final appDocDir = await getApplicationDocumentsDirectory();
            final modelFile = File('${appDocDir.path}/model.gguf');
            final tokenizerFile = File('${appDocDir.path}/tokenizer.json');
            if (await modelFile.exists() && await tokenizerFile.exists()) {
              debugPrint("Initializing Snowglobe engine via toggle...");
              final result = await SnowglobeOpenAI.initEngine(
                cacheDir: appDocDir.path,
                config: const InitConfig(
                  vocabShards: 1,
                  maxGenLen: 2048,
                  useExecutorch: false,
                  backend: BackendType.llamaCpp,
                  speculateTokens: 0,
                ),
              );
              debugPrint("Snowglobe engine initialization result via toggle: $result");
              _isEngineInitialized = true;
              notifyListeners();
            }
          } catch (e) {
            debugPrint("Failed to initialize Snowglobe engine via toggle: $e");
          }
        }
      }
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyUseSnowglobeLocalModel, value);
      if (value) {
        await prefs.setBool(_keyUseLocalOpenAi, false);
      }
    }
  }

  Future<void> setLocalOpenAiUrl(String value) async {
    if (_localOpenAiUrl != value) {
      _localOpenAiUrl = value;
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyLocalOpenAiUrl, value);
    }
  }

  Future<void> setAllowGeolocation(bool value) async {
    if (_allowGeolocation != value) {
      _allowGeolocation = value;
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyAllowGeolocation, value);
    }
  }

  Future<void> setAllowAccelerometer(bool value) async {
    if (_allowAccelerometer != value) {
      _allowAccelerometer = value;
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyAllowAccelerometer, value);
    }
  }

  Future<void> setAllowNotifications(bool value) async {
    if (_allowNotifications != value) {
      _allowNotifications = value;
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyAllowNotifications, value);
    }
  }

  Future<void> setAllowBackendDatabase(bool value) async {
    if (_allowBackendDatabase != value) {
      _allowBackendDatabase = value;
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyAllowBackendDatabase, value);
    }
  }

  Future<void> setAllowBackgroundExecution(bool value) async {
    if (_allowBackgroundExecution != value) {
      _allowBackgroundExecution = value;
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyAllowBackgroundExecution, value);
    }
  }

  Future<void> setAllowBackgroundNotifications(bool value) async {
    if (_allowBackgroundNotifications != value) {
      _allowBackgroundNotifications = value;
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyAllowBackgroundNotifications, value);
    }
  }

  Future<void> setAllowBackgroundDatabase(bool value) async {
    if (_allowBackgroundDatabase != value) {
      _allowBackgroundDatabase = value;
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyAllowBackgroundDatabase, value);
    }
  }
}
