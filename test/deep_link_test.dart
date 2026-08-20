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

    test('ecfc quick checkin action', () {
      final u = AppConstants.normalizeLaunchUri(
        Uri.parse('ecfc://action/checkin'),
      );
      expect(u?.path, AppConstants.appActionCheckin);
      expect(AppConstants.isAppAction(u!), isTrue);
    });

    test('foreign host rejected', () {
      final u = AppConstants.normalizeLaunchUri(
        Uri.parse('https://evil.example/x'),
      );
      expect(u, isNull);
    });
  });

  group('AppConstants.resolveSharedContent', () {
    test('plain ecfc url', () {
      final u = AppConstants.resolveSharedContent(
        'https://ecfc.fans/posts/abc123',
      );
      expect(u?.path, '/posts/abc123');
    });

    test('url embedded in title text', () {
      final u = AppConstants.resolveSharedContent(
        '看看这篇 https://ecfc.fans/forum?board=daily-chat 有意思',
      );
      expect(u?.path, '/forum');
      expect(u?.queryParameters['board'], 'daily-chat');
    });

    test('ecfc scheme in share body', () {
      final u = AppConstants.resolveSharedContent('打开 ecfc://checkin');
      expect(u?.toString(), 'https://ecfc.fans/checkin');
    });

    test('plain text goes to search', () {
      final u = AppConstants.resolveSharedContent('陈奕迅 演唱会');
      expect(u?.path, '/search');
      expect(u?.queryParameters['q'], '陈奕迅 演唱会');
    });

    test('foreign url alone falls to search', () {
      final u = AppConstants.resolveSharedContent('https://evil.example/x');
      expect(u?.path, '/search');
      expect(u?.queryParameters['q'], 'https://evil.example/x');
    });

    test('empty rejected', () {
      expect(AppConstants.resolveSharedContent('   '), isNull);
      expect(AppConstants.resolveSharedContent(null), isNull);
    });
  });
}
