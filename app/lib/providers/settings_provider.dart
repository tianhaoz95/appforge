import 'package:flutter/material.dart';
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
  bool _rememberMe = false;
  bool _halMode = false;
  String _rememberedEmail = '';
  String _localAvatarPath = '';
  String _systemPrompt = '';
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
  static const String _keyRememberMe = 'remember_me';
  static const String _keyHalMode = 'hal_mode';
  static const String _keyRememberedEmail = 'remembered_email';
  static const String _keyLocalAvatarPath = 'local_avatar_path';
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
  bool get rememberMe => _rememberMe;
  bool get halMode => _halMode;
  String get rememberedEmail => _rememberedEmail;
  String get localAvatarPath => _localAvatarPath;
  String get systemPrompt => _systemPrompt;
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
    _rememberMe = prefs.getBool(_keyRememberMe) ?? false;
    _halMode = prefs.getBool(_keyHalMode) ?? false;
    _rememberedEmail = prefs.getString(_keyRememberedEmail) ?? '';
    _localAvatarPath = prefs.getString(_keyLocalAvatarPath) ?? '';
    _totalPromptTokens = prefs.getInt(_keyTotalPromptTokens) ?? 0;
    _totalCandidateTokens = prefs.getInt(_keyTotalCandidateTokens) ?? 0;
    _totalTotalTokens = prefs.getInt(_keyTotalTotalTokens) ?? 0;
    _totalThoughtsTokens = prefs.getInt(_keyTotalThoughtsTokens) ?? 0;
    _totalCachedTokens = prefs.getInt(_keyTotalCachedTokens) ?? 0;
    _totalToolUseTokens = prefs.getInt(_keyTotalToolUseTokens) ?? 0;
    
    final themeIndex = prefs.getInt(_keyThemeMode) ?? ThemeMode.system.index;
    _themeMode = ThemeMode.values[themeIndex];

    final modeIndex = prefs.getInt(_keyDefaultForgeMode) ?? ForgeMode.build.index;
    _defaultForgeMode = ForgeMode.values[modeIndex];
    
    notifyListeners();
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

  void setSystemPrompt(String value) {
    if (_systemPrompt != value) {
      _systemPrompt = value;
      notifyListeners();
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

  Future<void> setHalMode(bool value) async {
    if (_halMode != value) {
      _halMode = value;
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyHalMode, value);
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
