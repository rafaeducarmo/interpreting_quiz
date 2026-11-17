// Punto de entrada de la app (Interpreting Quiz): arranca Flutter y muestra la
// pantalla del quiz.

import 'dart:math';

import 'package:material_ui/material_ui.dart';

import 'quiz_screen.dart';

void main() {
  runApp(const InterpretingQuizApp());
}

class InterpretingQuizApp extends StatelessWidget {
  /// [random] solo lo usan los tests (para tener un orden conocido).
  const InterpretingQuizApp({super.key, this.random});

  final Random? random;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Interpreting Quiz',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
      ),
      home: QuizScreen(random: random),
    );
  }
}
