import 'dart:async';
import 'dart:io';

import '../test/support/offline_http_overrides.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  HttpOverrides.global = OfflineHttpOverrides();
  await testMain();
}
