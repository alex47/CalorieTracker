import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('automated tests reject unmocked HTTP clients', () {
    expect(
      HttpClient.new,
      throwsA(
        isA<UnsupportedError>().having(
          (error) => error.message,
          'message',
          contains('Inject a mock client'),
        ),
      ),
    );
  });
}
