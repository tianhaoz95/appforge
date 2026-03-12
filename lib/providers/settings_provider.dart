import 'package:flutter/foundation.dart';

class SettingsProvider with ChangeNotifier {
  bool _suggestExistingApps = true;

  bool get suggestExistingApps => _suggestExistingApps;

  void setSuggestExistingApps(bool value) {
    if (_suggestExistingApps != value) {
      _suggestExistingApps = value;
      notifyListeners();
    }
  }
}
