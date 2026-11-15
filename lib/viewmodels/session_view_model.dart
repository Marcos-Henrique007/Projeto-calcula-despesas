import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../data/services/firebase_auth_service.dart';

class SessionViewModel extends ChangeNotifier {
  SessionViewModel(this._auth) : _user = _auth.currentUser {
    _subscription = _auth.authStateChanges.listen((user) {
      _user = user;
      _isLoading = false;
      _errorMessage = null;
      notifyListeners();
    });
  }

  final FirebaseAuthService _auth;
  StreamSubscription<User?>? _subscription;
  User? _user;
  bool _isLoading = true;
  bool _isBusy = false;
  String? _errorMessage;

  User? get user => _user;
  bool get isGuest => _user == null;
  bool get isLoading => _isLoading;
  bool get isBusy => _isBusy;
  String? get errorMessage => _errorMessage;
  String get actorId => _user?.uid ?? 'guest-local';
  String get displayName => _user?.displayName?.trim().isNotEmpty == true
      ? _user!.displayName!.trim()
      : _user?.email ?? 'Visitante';

  Future<bool> signIn(String email, String password) async {
    _isBusy = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _auth.signIn(email: email, password: password);
      return true;
    } on AuthFlowException catch (error) {
      _errorMessage = error.message;
      return false;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<bool> signInWithGoogle() async {
    _isBusy = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _auth.signInWithGoogle();
      return true;
    } on AuthFlowException catch (error) {
      _errorMessage = error.message;
      return false;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<bool> register(String name, String email, String password) async {
    _isBusy = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _auth.register(name: name, email: email, password: password);
      return true;
    } on AuthFlowException catch (error) {
      _errorMessage = error.message;
      return false;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<bool> sendPasswordReset(String email) async {
    _isBusy = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _auth.sendPasswordReset(email);
      return true;
    } on AuthFlowException catch (error) {
      _errorMessage = error.message;
      return false;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<void> signOut() => _auth.signOut();

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
