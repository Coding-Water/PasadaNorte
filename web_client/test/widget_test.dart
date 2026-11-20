import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web_client/main.dart';

void main() {
  testWidgets('Web Command Center renders MINC Admin login gate cleanly', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const PasadaNorteWebAdminApp());
    await tester.pump();

    expect(find.textContaining('PasadaNorte'), findsWidgets);
    expect(find.byType(TextField), findsWidgets);
  });
}
