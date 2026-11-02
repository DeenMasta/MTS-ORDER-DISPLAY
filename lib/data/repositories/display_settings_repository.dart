import '../../domain/models/kds_settings.dart';
import '../services/display_settings_store.dart';

abstract interface class DisplaySettingsRepository {
  Future<KdsSettings> load();
  Future<void> save(KdsSettings settings);
}

class StoredDisplaySettingsRepository implements DisplaySettingsRepository {
  StoredDisplaySettingsRepository({required DisplaySettingsStore store})
    : _store = store;

  final DisplaySettingsStore _store;

  @override
  Future<KdsSettings> load() => _store.load();

  @override
  Future<void> save(KdsSettings settings) => _store.save(settings);
}
