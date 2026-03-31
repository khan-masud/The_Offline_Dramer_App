import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(),
);

class AuthState {
  final bool isAuthenticated;
  final bool isPinSet;
  final bool isLoading;

  const AuthState({
    this.isAuthenticated = false,
    this.isPinSet = false,
    this.isLoading = true,
  });

  AuthState copyWith({bool? isAuthenticated, bool? isPinSet, bool? isLoading}) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isPinSet: isPinSet ?? this.isPinSet,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState()) {
    _init();
  }

  final _storage = const FlutterSecureStorage();
  static const _pinKey = 'user_pin';

  Future<void> _init() async {
    final pin = await _storage.read(key: _pinKey);
    state = state.copyWith(isPinSet: pin != null, isLoading: false);
  }

  Future<bool> verifyPin(String pin) async {
    final stored = await _storage.read(key: _pinKey);
    if (stored == pin) {
      state = state.copyWith(isAuthenticated: true);
      return true;
    }
    return false;
  }

  Future<void> setPin(String pin) async {
    await _storage.write(key: _pinKey, value: pin);
    state = state.copyWith(isPinSet: true, isAuthenticated: true);
  }

  Future<void> removePin() async {
    await _storage.delete(key: _pinKey);
    state = state.copyWith(isPinSet: false);
  }

  void lock() {
    state = state.copyWith(isAuthenticated: false);
  }
}
