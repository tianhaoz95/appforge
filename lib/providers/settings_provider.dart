import 'package:flutter/material.dart';
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
  ThemeMode _themeMode = ThemeMode.system;

  static const String _keySuggestExistingApps = 'suggest_existing_apps';
  static const String _keyAllowGeolocation = 'allow_geolocation';
  static const String _keyAllowAccelerometer = 'allow_accelerometer';
  static const String _keyAllowNotifications = 'allow_notifications';
  static const String _keyAllowBackendDatabase = 'allow_backend_database';
  static const String _keyAllowBackgroundExecution = 'allow_background_execution';
  static const String _keyAllowBackgroundNotifications = 'allow_background_notifications';
  static const String _keyAllowBackgroundDatabase = 'allow_background_database';
  static const String _keyThemeMode = 'theme_mode';

  bool get suggestExistingApps => _suggestExistingApps;
  bool get allowGeolocation => _allowGeolocation;
  bool get allowAccelerometer => _allowAccelerometer;
  bool get allowNotifications => _allowNotifications;
  bool get allowBackendDatabase => _allowBackendDatabase;
  bool get allowBackgroundExecution => _allowBackgroundExecution;
  bool get allowBackgroundNotifications => _allowBackgroundNotifications;
  bool get allowBackgroundDatabase => _allowBackgroundDatabase;
  ThemeMode get themeMode => _themeMode;

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
    
    final themeIndex = prefs.getInt(_keyThemeMode) ?? ThemeMode.system.index;
    _themeMode = ThemeMode.values[themeIndex];
    
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode value) async {
    if (_themeMode != value) {
      _themeMode = value;
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyThemeMode, value.index);
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
