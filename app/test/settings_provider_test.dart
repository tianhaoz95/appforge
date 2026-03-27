import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:appforge/providers/settings_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsProvider', () {
    late SettingsProvider settingsProvider;

    setUp(() {
      const MethodChannel('plugins.flutter.io/path_provider')
          .setMockMethodCallHandler((MethodCall methodCall) async {
        if (methodCall.method == 'getApplicationDocumentsDirectory') {
          return '.';
        }
        return null;
      });
      SharedPreferences.setMockInitialValues({});
      settingsProvider = SettingsProvider();
    });

    test('initial themeMode should be system', () async {
      await settingsProvider.loadSettings();
      expect(settingsProvider.themeMode, ThemeMode.system);
    });

    test('setThemeMode updates themeMode and notifies listeners', () async {
      bool notified = false;
      settingsProvider.addListener(() {
        notified = true;
      });

      await settingsProvider.setThemeMode(ThemeMode.dark);
      expect(settingsProvider.themeMode, ThemeMode.dark);
      expect(notified, isTrue);
    });

    test('themeMode persists across loadSettings', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('theme_mode', ThemeMode.light.index);
      
      final newProvider = SettingsProvider();
      await newProvider.loadSettings();
      expect(newProvider.themeMode, ThemeMode.light);
    });

    test('rememberMe persists across loadSettings', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('remember_me', true);
      
      final newProvider = SettingsProvider();
      await newProvider.loadSettings();
      expect(newProvider.rememberMe, isTrue);
    });

    test('rememberedEmail persists across loadSettings', () async {
      const email = 'test@example.com';
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('remembered_email', email);
      
      final newProvider = SettingsProvider();
      await newProvider.loadSettings();
      expect(newProvider.rememberedEmail, email);
    });

    test('localAvatarPath persists across loadSettings', () async {
      const path = '/path/to/avatar.png';
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('local_avatar_path', path);
      
      final newProvider = SettingsProvider();
      await newProvider.loadSettings();
      expect(newProvider.localAvatarPath, path);
    });

    test('halMode persists across loadSettings', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('hal_mode', true);
      
      final newProvider = SettingsProvider();
      await newProvider.loadSettings();
      expect(newProvider.halMode, isTrue);

      await prefs.setBool('hal_mode', false);
      final thirdProvider = SettingsProvider();
      await thirdProvider.loadSettings();
      expect(thirdProvider.halMode, isFalse);
    });

    test('token usage persists across loadSettings', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('total_prompt_tokens', 100);
      await prefs.setInt('total_candidate_tokens', 200);
      await prefs.setInt('total_total_tokens', 300);
      await prefs.setInt('total_thoughts_tokens', 10);
      await prefs.setInt('total_cached_tokens', 20);
      await prefs.setInt('total_tool_use_tokens', 30);
      
      final newProvider = SettingsProvider();
      await newProvider.loadSettings();
      expect(newProvider.totalPromptTokens, 100);
      expect(newProvider.totalCandidateTokens, 200);
      expect(newProvider.totalTotalTokens, 300);
      expect(newProvider.totalThoughtsTokens, 10);
      expect(newProvider.totalCachedTokens, 20);
      expect(newProvider.totalToolUseTokens, 30);
    });
  });
}
