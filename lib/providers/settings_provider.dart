import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider with ChangeNotifier {
  bool _suggestExistingApps = true;
  bool _allowGeolocation = false;
  bool _allowAccelerometer = false;
  bool _allowNotifications = false;
  bool _allowBackendDatabase = false;

  static const String _keySuggestExistingApps = 'suggest_existing_apps';
  static const String _keyAllowGeolocation = 'allow_geolocation';
  static const String _keyAllowAccelerometer = 'allow_accelerometer';
  static const String _keyAllowNotifications = 'allow_notifications';
  static const String _keyAllowBackendDatabase = 'allow_backend_database';

  bool get suggestExistingApps => _suggestExistingApps;
  bool get allowGeolocation => _allowGeolocation;
  bool get allowAccelerometer => _allowAccelerometer;
  bool get allowNotifications => _allowNotifications;
  bool get allowBackendDatabase => _allowBackendDatabase;

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _suggestExistingApps = prefs.getBool(_keySuggestExistingApps) ?? true;
    _allowGeolocation = prefs.getBool(_keyAllowGeolocation) ?? false;
    _allowAccelerometer = prefs.getBool(_keyAllowAccelerometer) ?? false;
    _allowNotifications = prefs.getBool(_keyAllowNotifications) ?? false;
    _allowBackendDatabase = prefs.getBool(_keyAllowBackendDatabase) ?? false;
    notifyListeners();
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
}
