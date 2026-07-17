import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_dilanscissors/main.dart';

void main() {
  testWidgets('La app arranca sin errores', (WidgetTester tester) async {
    await tester.pumpWidget(const DilanScissorsApp());
    await tester.pump();

    // Solo verifica que la app cargó sin explotar
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}