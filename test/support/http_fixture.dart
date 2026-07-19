import 'dart:io';

String readFixture(String relativePath) {
  return File('test/fixtures/$relativePath').readAsStringSync();
}
