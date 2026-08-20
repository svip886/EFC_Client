// ignore_for_file: avoid_relative_lib_imports

import 'package:flutter_test/flutter_test.dart';

import 'package:ecfc_app/core/constants.dart';

void main() {
  group('AppConstants.normalizeLaunchUri', () {
    test('https host allowed', () {
      final u = AppConstants.normalizeLaunchUri(
        Uri.parse('https://ecfc.fans/forum?board=1'),
      );
      expect(u?.toString(), 'https://ecfc.fans/forum?board=1');
    });

    test('http upgraded to https', () {
      final u = AppConstants.normalizeLaunchUri(
        Uri.parse('http://ecfc.fans/checkin'),
      );
      expect(u?.scheme, 'https');
      expect(u?.path, '/checkin');
    });

    test('ecfc scheme with host as path', () {
      final u = AppConstants.normalizeLaunchUri(Uri.parse('ecfc://forum'));
      expect(u?.toString(), 'https://ecfc.fans/forum');
    });

    test('ecfc scheme with path only', () {
      final u = AppConstants.normalizeLaunchUri(
        Uri.parse('ecfc:///notifications'),
      );
      expect(u?.toString(), 'https://ecfc.fans/notifications');
    });

    test('foreign host rejected', () {
      final u = AppConstants.normalizeLaunchUri(
        Uri.parse('https://evil.example/x'),
      );
      expect(u, isNull);
    });
  });
}
