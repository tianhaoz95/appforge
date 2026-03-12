import 'package:flutter/foundation.dart';

class SettingsProvider with ChangeNotifier {
  bool _suggestExistingApps = true;
  bool _allowGeolocation = false;

  bool get suggestExistingApps => _suggestExistingApps;
  bool get allowGeolocation => _allowGeolocation;

  void setSuggestExistingApps(bool value) {
    if (_suggestExistingApps != value) {
      _suggestExistingApps = value;
      notifyListeners();
    }
  }

  void setAllowGeolocation(bool value) {
    if (_allowGeolocation != value) {
      _allowGeolocation = value;
      notifyListeners();
    }
  }
}
