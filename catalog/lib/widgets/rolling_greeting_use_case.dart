import 'package:flutter/material.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;
import 'package:appforge/widgets/rolling_greeting.dart';

@widgetbook.UseCase(
  name: 'Default',
  type: RollingGreeting,
)
Widget buildRollingGreetingUseCase(BuildContext context) {
  return const Scaffold(
    body: Center(
      child: RollingGreeting(
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
      ),
    ),
  );
}

@widgetbook.UseCase(
  name: 'Custom Style',
  type: RollingGreeting,
)
Widget buildRollingGreetingCustomUseCase(BuildContext context) {
  return const Scaffold(
    body: Center(
      child: RollingGreeting(
        style: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w900,
          color: Colors.blue,
          letterSpacing: 1.2,
        ),
      ),
    ),
  );
}
