import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:appforge/providers/settings_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsProvider', () {
    late SettingsProvider settingsProvider;

    setUp(() {
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
      await settingsProvider.setThemeMode(ThemeMode.light);

      final newProvider = SettingsProvider();
      await newProvider.loadSettings();
      expect(newProvider.themeMode, ThemeMode.light);
    });

    test('rememberMe persists across loadSettings', () async {
      await settingsProvider.setRememberMe(true);

      final newProvider = SettingsProvider();
      await newProvider.loadSettings();
      expect(newProvider.rememberMe, isTrue);
    });

    test('rememberedEmail persists across loadSettings', () async {
      const email = 'test@example.com';
      await settingsProvider.setRememberedEmail(email);

      final newProvider = SettingsProvider();
      await newProvider.loadSettings();
      expect(newProvider.rememberedEmail, email);
    });

    test('localAvatarPath persists across loadSettings', () async {
      const path = '/path/to/avatar.png';
      await settingsProvider.setLocalAvatarPath(path);

      final newProvider = SettingsProvider();
      await newProvider.loadSettings();
      expect(newProvider.localAvatarPath, path);
    });

    test('token usage persists across loadSettings', () async {
      await settingsProvider.addTokenUsage(100, 200, 300, thoughts: 10, cached: 20, toolUse: 30);
      expect(settingsProvider.totalPromptTokens, 100);
      expect(settingsProvider.totalCandidateTokens, 200);
      expect(settingsProvider.totalTotalTokens, 300);
      expect(settingsProvider.totalThoughtsTokens, 10);
      expect(settingsProvider.totalCachedTokens, 20);
      expect(settingsProvider.totalToolUseTokens, 30);

      final newProvider = SettingsProvider();
      await newProvider.loadSettings();
      expect(newProvider.totalPromptTokens, 100);
      expect(newProvider.totalCandidateTokens, 200);
      expect(newProvider.totalTotalTokens, 300);
      expect(newProvider.totalThoughtsTokens, 10);
      expect(newProvider.totalCachedTokens, 20);
      expect(newProvider.totalToolUseTokens, 30);

      await newProvider.addTokenUsage(50, 50, 100, thoughts: 5);
      expect(newProvider.totalTotalTokens, 400);
      expect(newProvider.totalThoughtsTokens, 15);
    });
  });
}
