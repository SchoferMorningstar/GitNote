import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static const _storage = FlutterSecureStorage();
  
  static const _githubTokenKey = 'githubTokenKey';

  static Future<void> saveGithubToken(String token) async {
    await _storage.write(key: _githubTokenKey, value: token);
  }

  static Future<String?> getGithubToken() async {
    return await _storage.read(key: _githubTokenKey);
  }

  static Future<void> deleteGithubToken() async {
    await _storage.delete(key: _githubTokenKey);
  }
}
