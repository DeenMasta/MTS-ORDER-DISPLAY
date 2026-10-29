import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class DeviceIdentityRepository {
  Future<String> getOrCreate();
}

class SecureDeviceIdentityRepository implements DeviceIdentityRepository {
  SecureDeviceIdentityRepository({FlutterSecureStorage? storage})
    : _storage = storage ?? FlutterSecureStorage();

  static const _key = 'installation_id';

  final FlutterSecureStorage _storage;

  @override
  Future<String> getOrCreate() async {
    final storedId = await _storage.read(key: _key);
    if (storedId != null && storedId.isNotEmpty) {
      return storedId;
    }

    final id = _newUuid();
    await _storage.write(key: _key, value: id);
    return id;
  }

  String _newUuid() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}
