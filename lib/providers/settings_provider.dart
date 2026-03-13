import 'package:flutter/foundation.dart';

class SettingsProvider with ChangeNotifier {
  bool _suggestExistingApps = true;
  bool _allowGeolocation = false;
  bool _allowAccelerometer = false;
  bool _allowNotifications = false;
  bool _allowBackendDatabase = false;

  bool get suggestExistingApps => _suggestExistingApps;
  bool get allowGeolocation => _allowGeolocation;
  bool get allowAccelerometer => _allowAccelerometer;
  bool get allowNotifications => _allowNotifications;
  bool get allowBackendDatabase => _allowBackendDatabase;

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

  void setAllowAccelerometer(bool value) {
    if (_allowAccelerometer != value) {
      _allowAccelerometer = value;
      notifyListeners();
    }
  }

  void setAllowNotifications(bool value) {
    if (_allowNotifications != value) {
      _allowNotifications = value;
      notifyListeners();
    }
  }

  void setAllowBackendDatabase(bool value) {
    if (_allowBackendDatabase != value) {
      _allowBackendDatabase = value;
      notifyListeners();
    }
  }
}
