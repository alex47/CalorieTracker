import 'dart:io';

class OfflineHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    throw UnsupportedError(
      'Live HTTP is disabled in automated tests. Inject a mock client.',
    );
  }
}
