import 'update_service.dart';

class UpdateCoordinator {
  UpdateCoordinator({
    UpdateService? service,
  }) : _service = service ?? UpdateService();

  static final UpdateCoordinator instance = UpdateCoordinator();

  final UpdateService _service;

  UpdateCheckResult? _latestResult;
  String? _latestRequestedVersion;
  final Map<String, Future<UpdateCheckResult>> _inFlightByVersion = {};

  UpdateCheckResult? get latestResult => _latestResult;

  Future<UpdateCheckResult> checkForUpdates({
    required String currentVersion,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final result = _latestResult;
      if (result != null && _latestRequestedVersion == currentVersion) {
        return result;
      }
    }

    final inFlight = _inFlightByVersion[currentVersion];
    if (inFlight != null) {
      return inFlight;
    }

    final request = _service.checkForUpdate(currentVersion: currentVersion);
    _inFlightByVersion[currentVersion] = request;
    try {
      final result = await request;
      _latestResult = result;
      _latestRequestedVersion = currentVersion;
      return result;
    } finally {
      if (identical(_inFlightByVersion[currentVersion], request)) {
        _inFlightByVersion.remove(currentVersion);
      }
    }
  }
}
