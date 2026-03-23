import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _user;

  User? get user => _user;
  bool get isAuthenticated => _user != null;

  AuthProvider() {
    _auth.authStateChanges().listen((User? user) {
      _user = user;
      notifyListeners();
    });
  }

  Future<void> signIn(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> signUp(String email, String password, String displayName) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      await credential.user?.updateDisplayName(displayName);
      await credential.user?.reload();
      _user = _auth.currentUser;
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteAccount() async {
    try {
      await _user?.delete();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateDisplayName(String name) async {
    try {
      await _user?.updateDisplayName(name);
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> changePassword(String oldPassword, String newPassword) async {
    try {
      final email = _user?.email;
      if (email == null) throw Exception('User email not found');
      
      // Re-authenticate user
      AuthCredential credential = EmailAuthProvider.credential(email: email, password: oldPassword);
      await _user?.reauthenticateWithCredential(credential);
      
      // Update password
      await _user?.updatePassword(newPassword);
    } catch (e) {
      rethrow;
    }
  }
}
