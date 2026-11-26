import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'models.dart';

/// Keeps tokens and the signed in user in the platform keychain / keystore.
class TokenStorage {
  TokenStorage([FlutterSecureStorage? storage]) : _s = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _s;
  String? _access;

  static const _kAccess = 'access_token';
  static const _kRefresh = 'refresh_token';
  static const _kUser = 'user';

  Future<String?> accessToken() async => _access ??= await _s.read(key: _kAccess);
  Future<String?> refreshToken() => _s.read(key: _kRefresh);

  Future<void> save(String access, String refresh) async {
    _access = access;
    await _s.write(key: _kAccess, value: access);
    await _s.write(key: _kRefresh, value: refresh);
  }

  Future<void> saveUser(AppUser user) => _s.write(key: _kUser, value: jsonEncode(user.toJson()));

  Future<AppUser?> user() async {
    final raw = await _s.read(key: _kUser);
    return raw == null ? null : AppUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> clear() async {
    _access = null;
    await _s.delete(key: _kAccess);
    await _s.delete(key: _kRefresh);
    await _s.delete(key: _kUser);
  }
}

final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());
