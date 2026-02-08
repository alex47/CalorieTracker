import 'update_service.dart';

class UpdateCoordinator {
  UpdateCoordinator._();

  static final UpdateCoordinator instance = UpdateCoordinator._();

  final UpdateService _service = UpdateService();

  UpdateCheckResult? _latestResult;
  Future<UpdateCheckResult>? _inFlight;

  UpdateCheckResult? get latestResult => _latestResult;

  Future<UpdateCheckResult> checkForUpdates({
    required String currentVersion,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final result = _latestResult;
      if (result != null && result.currentVersion == currentVersion) {
        return result;
      }
    }

    final inFlight = _inFlight;
    if (inFlight != null) {
      return inFlight;
    }

    final request = _service.checkForUpdate(currentVersion: currentVersion);
    _inFlight = request;
    try {
      final result = await request;
      _latestResult = result;
      return result;
    } finally {
      _inFlight = null;
    }
  }
}
