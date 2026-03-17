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
  });
}
