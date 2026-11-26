import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/models.dart';
import '../../core/token_storage.dart';

sealed class AuthState {
  const AuthState();
}

class AuthUnknown extends AuthState {
  const AuthUnknown();
}

class SignedOut extends AuthState {
  const SignedOut();
}

class SignedIn extends AuthState {
  const SignedIn(this.user);
  final AppUser user;
}

class AuthController extends Notifier<AuthState> {
  /// Lets go_router re-run its redirect when the auth state changes.
  final changes = ValueNotifier<int>(0);

  @override
  AuthState build() {
    final api = ref.read(apiClientProvider);
    api.onSessionExpired = () => _set(const SignedOut());
    Future.microtask(_restore);
    return const AuthUnknown();
  }

  void _set(AuthState s) {
    state = s;
    changes.value++;
  }

  TokenStorage get _tokens => ref.read(tokenStorageProvider);

  /// Signs in from the stored session. Works offline: the cached user is used until the server says otherwise.
  Future<void> _restore() async {
    final user = await _tokens.user();
    final refresh = await _tokens.refreshToken();
    if (user == null || refresh == null) return _set(const SignedOut());
    _set(SignedIn(user));
    try {
      final me = await ref.read(apiClientProvider).call((d) => d.get<Map<String, dynamic>>('/auth/me'));
      final fresh = AppUser.fromJson(me.data!);
      await _tokens.saveUser(fresh);
      _set(SignedIn(fresh));
    } on ApiException catch (e) {
      if (e.statusCode == 401) await signOut();
    }
  }

  Future<void> signIn(String email, String password) async {
    final res = await ref.read(apiClientProvider).call(
          (d) => d.post<Map<String, dynamic>>('/auth/login', data: {'email': email.trim(), 'password': password}),
        );
    final tokens = AuthTokens.fromJson(res.data!);
    await _tokens.save(tokens.accessToken, tokens.refreshToken);
    await _tokens.saveUser(tokens.user);
    _set(SignedIn(tokens.user));
  }

  Future<void> signOut() async {
    final refresh = await _tokens.refreshToken();
    if (refresh != null) {
      try {
        await ref.read(apiClientProvider).call((d) => d.post<void>('/auth/logout', data: {'refreshToken': refresh}));
      } catch (_) {
        // Signing out locally is enough when offline.
      }
    }
    await _tokens.clear();
    _set(const SignedOut());
  }

  Future<void> changePassword(String current, String next) => ref.read(apiClientProvider).call(
        (d) => d.post<void>('/auth/change-password', data: {'currentPassword': current, 'newPassword': next}),
      );
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(AuthController.new);

final currentUserProvider = Provider<AppUser?>((ref) {
  final s = ref.watch(authControllerProvider);
  return s is SignedIn ? s.user : null;
});
