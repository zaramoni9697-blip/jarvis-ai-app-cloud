import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ProviderKeyStorage {
  static const FlutterSecureStorage _storage =
      FlutterSecureStorage();

  static String _key(int profileId, String provider) {
    return 'jarvis_${profileId}_$provider';
  }

  static Future<void> save({
    required int profileId,
    required String provider,
    required String apiKey,
  }) async {
    if (apiKey.trim().isEmpty) {
      throw ArgumentError('API Key cannot be empty');
    }

    await _storage.write(
      key: _key(profileId, provider),
      value: apiKey.trim(),
    );
  }

  static Future<String?> read({
    required int profileId,
    required String provider,
  }) async {
    return _storage.read(
      key: _key(profileId, provider),
    );
  }

  static Future<void> delete({
    required int profileId,
    required String provider,
  }) async {
    await _storage.delete(
      key: _key(profileId, provider),
    );
  }
}
