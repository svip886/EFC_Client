import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ecfc_app/core/constants.dart';

void main() {
  test('AppConstants home path is community', () {
    expect(AppConstants.homePath, '/community');
    expect(AppConstants.appName, '私家E院');
    expect(AppConstants.homeUri.host, 'ecfc.fans');
  });

  testWidgets('MaterialApp smoke', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Text('私家E院')),
      ),
    );
    expect(find.text('私家E院'), findsOneWidget);
  });
}
