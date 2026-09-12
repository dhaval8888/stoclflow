import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/app_constants.dart';

final tokenStorageProvider = Provider<TokenStorageService>((ref) {
  return TokenStorageService(const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  ));
});

/// Secure Token Storage wrapping FlutterSecureStorage
class TokenStorageService {
  final FlutterSecureStorage _storage;

  TokenStorageService(this._storage);

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await Future.wait([
      _storage.write(key: AppConstants.keyAccessToken, value: accessToken),
      _storage.write(key: AppConstants.keyRefreshToken, value: refreshToken),
    ]);
  }

  Future<void> saveAccessToken(String accessToken) async {
    await _storage.write(key: AppConstants.keyAccessToken, value: accessToken);
  }

  Future<String?> getAccessToken() async {
    return _storage.read(key: AppConstants.keyAccessToken);
  }

  Future<String?> getRefreshToken() async {
    return _storage.read(key: AppConstants.keyRefreshToken);
  }

  Future<void> saveUserJson(String userJson) async {
    await _storage.write(key: AppConstants.keyUserData, value: userJson);
  }

  Future<String?> getUserJson() async {
    return _storage.read(key: AppConstants.keyUserData);
  }

  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
