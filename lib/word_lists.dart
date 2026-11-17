// Catálogo de listas del quiz. Cada lista dice qué elementos tiene, en qué
// par de idiomas se juega y cómo se dibuja (columnas y alto de fila).

import 'bilingual_terms.dart';
import 'quiz_model.dart';

class WordList {
  const WordList({
    required this.id,
    required this.nombre,
    required this.forward,
    required this.reverse,
    required this.items,
    required this.cortesColumnas,
    required this.altoFila,
  });

  /// Identificador corto, usado en llaves de widgets: "glosario", "medico"...
  final String id;

  /// Nombre que se ve en el selector de lista.
  final String nombre;

  /// Dirección "de ida" (la que se elige al cambiar de lista) y la inversa.
  final QuizMode forward;
  final QuizMode reverse;

  final List<QuizItem> items;

  /// Anchos mínimos de ventana para usar 4 y 2 columnas, respectivamente
  /// (por debajo del segundo, 1 columna). Las listas con frases largas
  /// necesitan más ancho por columna.
  final (double, double) cortesColumnas;

  /// Alto de cada fila de la cuadrícula, en píxeles.
  final double altoFila;

  /// Las dos direcciones disponibles, en el orden en que se muestran.
  List<QuizMode> get modos => [forward, reverse];

  /// Columnas que caben en [ancho] píxeles.
  int columnasPara(double ancho) => ancho >= cortesColumnas.$1
      ? 4
      : (ancho >= cortesColumnas.$2 ? 2 : 1);
}

/// Glosario oficial de entrenamiento (inglés <-> español).
final List<QuizItem> trainingItems = [
  for (final t in trainingGlossary) QuizItem.fromTerm(t),
];

/// Términos médicos ampliados (inglés <-> español).
final List<QuizItem> medicalItems = [
  for (final t in medicalTerms) QuizItem.fromTerm(t),
];

/// Las dos listas disponibles. La primera es la que se abre al empezar.
final List<WordList> wordLists = [
  WordList(
    id: 'glosario',
    nombre: 'Glosario de entrenamiento',
    forward: QuizMode.enToEs,
    reverse: QuizMode.esToEn,
    items: trainingItems,
    cortesColumnas: (1500, 800),
    altoFila: 52,
  ),
  WordList(
    id: 'medico',
    nombre: 'Médico ampliado',
    forward: QuizMode.enToEs,
    reverse: QuizMode.esToEn,
    items: medicalItems,
    cortesColumnas: (1500, 800),
    altoFila: 52,
  ),
];
