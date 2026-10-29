import 'data/repositories/device_identity_repository.dart';
import 'data/repositories/display_session_repository.dart';
import 'data/repositories/kitchen_repository.dart';
import 'data/repositories/pairing_repository.dart';
import 'data/services/app_database.dart';
import 'data/services/pos_connection_service.dart';
import 'data/services/secure_session_storage.dart';
import 'data/services/ticket_store.dart';
import 'ui/features/kitchen/view_models/kitchen_board_view_model.dart';
import 'ui/features/pairing/view_models/pairing_view_model.dart';
import 'ui/features/session/view_models/session_view_model.dart';

class AppDependencies {
  AppDependencies() {
    final sessionRepository = StoredDisplaySessionRepository(
      storage: SecureSessionStorage(),
    );
    final connection = PosConnectionService();
    sessionViewModel = SessionViewModel(sessionRepository: sessionRepository);
    pairingViewModel = PairingViewModel(
      pairingRepository: LanPairingRepository(connection: connection),
      deviceIdentityRepository: SecureDeviceIdentityRepository(),
      sessionRepository: sessionRepository,
    );
    kitchenBoardViewModel = KitchenBoardViewModel(
      repository: StoredKitchenRepository(
        connection: connection,
        store: TicketStore(openDatabase: AppDatabase.open),
      ),
    );
  }

  late final KitchenBoardViewModel kitchenBoardViewModel;
  late final PairingViewModel pairingViewModel;
  late final SessionViewModel sessionViewModel;
}
