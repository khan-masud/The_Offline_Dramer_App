import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(),
);

class AuthState {
  final bool isAuthenticated;
  final bool isPinSet;
  final bool isLoading;
  final int attemptCount;
  final DateTime? lockUntil;

  const AuthState({
    this.isAuthenticated = false,
    this.isPinSet = false,
    this.isLoading = true,
    this.attemptCount = 0,
    this.lockUntil,
  });

  bool get isLocked {
    if (lockUntil == null) return false;
    return DateTime.now().isBefore(lockUntil!);
  }

  int get remainingAttempts => max(0, 5 - attemptCount);

  AuthState copyWith({
    bool? isAuthenticated,
    bool? isPinSet,
    bool? isLoading,
    int? attemptCount,
    DateTime? lockUntil,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isPinSet: isPinSet ?? this.isPinSet,
      isLoading: isLoading ?? this.isLoading,
      attemptCount: attemptCount ?? this.attemptCount,
      lockUntil: lockUntil ?? this.lockUntil,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState()) {
    _init();
  }

  final _storage = const FlutterSecureStorage();
  static const _pinHashKey = 'user_pin_hash';
  static const _saltKey = 'user_pin_salt';

  // Progressive lockout durations in seconds
  static const List<int> _lockoutDurations = [30, 60, 300, 600];

  String _hashPin(String pin, String salt) {
    final bytes = utf8.encode(pin + salt);
    return sha256.convert(bytes).toString();
  }

  Future<void> _init() async {
    final pinHash = await _storage.read(key: _pinHashKey);
    state = state.copyWith(isPinSet: pinHash != null, isLoading: false);
  }

  Future<bool> verifyPin(String pin) async {
    // If currently locked, reject immediately
    if (state.isLocked) {
      final remaining = state.lockUntil!.difference(DateTime.now());
      if (remaining.inSeconds > 0) return false;
    }

    final storedHash = await _storage.read(key: _pinHashKey);
    final salt = await _storage.read(key: _saltKey);
    if (storedHash == null || salt == null) return false;

    if (storedHash == _hashPin(pin, salt)) {
      // Success — reset attempts
      state = state.copyWith(
        isAuthenticated: true,
        attemptCount: 0,
        lockUntil: null,
      );
      return true;
    }

    // Failed attempt — increment and possibly lock
    final newAttemptCount = state.attemptCount + 1;
    if (newAttemptCount >= 5) {
      // Determine lockout duration based on how many times we've hit 5
      final lockoutIndex = (state.attemptCount ~/ 5).clamp(0, _lockoutDurations.length - 1);
      final lockDuration = _lockoutDurations[lockoutIndex];
      state = state.copyWith(
        attemptCount: newAttemptCount,
        lockUntil: DateTime.now().add(Duration(seconds: lockDuration)),
      );
    } else {
      state = state.copyWith(attemptCount: newAttemptCount);
    }
    return false;
  }

  Future<void> setPin(String pin) async {
    final random = Random.secure();
    final saltBytes = List<int>.generate(16, (_) => random.nextInt(256));
    final salt = base64Url.encode(saltBytes);
    final hash = _hashPin(pin, salt);
    await _storage.write(key: _saltKey, value: salt);
    await _storage.write(key: _pinHashKey, value: hash);
    state = state.copyWith(
      isPinSet: true,
      isAuthenticated: true,
      attemptCount: 0,
      lockUntil: null,
    );
  }

  Future<void> removePin() async {
    await _storage.delete(key: _pinHashKey);
    await _storage.delete(key: _saltKey);
    state = state.copyWith(
      isPinSet: false,
      attemptCount: 0,
      lockUntil: null,
    );
  }

  void lock() {
    state = state.copyWith(isAuthenticated: false);
  }

  void resetAttempts() {
    state = state.copyWith(attemptCount: 0, lockUntil: null);
  }
}
