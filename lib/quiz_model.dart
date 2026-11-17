// Modelo común del quiz: funciona con CUALQUIER par de idiomas.
// La lógica (quiz_logic.dart) y la pantalla solo conocen estos tipos, no las
// clase de datos (BilingualTerm); esa se convierte con un adaptador
// (ver word_lists.dart).

import 'bilingual_terms.dart';

/// Un idioma que puede aparecer en el quiz.
enum Language {
  english('EN', 'inglés'),
  spanish('ES', 'español');

  const Language(this.code, this.nombre);

  /// Código corto para los botones: "EN", "ES".
  final String code;

  /// Nombre en español, para los textos de ayuda.
  final String nombre;
}

/// La dirección de juego: qué idioma VES (from) y cuál ESCRIBES (to).
/// Es un enum con datos: cada valor lleva sus dos idiomas.
enum QuizMode {
  enToEs(Language.english, Language.spanish, 'en_es'),
  esToEn(Language.spanish, Language.english, 'es_en');

  const QuizMode(this.from, this.to, this.id);

  /// Idioma de la pregunta.
  final Language from;

  /// Idioma de la respuesta (el que se escribe).
  final Language to;

  /// Texto corto para llaves de widgets y tests: "de_en", "en_es"...
  final String id;
}

/// Un elemento del quiz: las formas de un término en cada idioma.
/// En cada lista de formas, la PRIMERA es la principal (la que se muestra) y
/// las demás son variantes que también se aceptan.
class QuizItem {
  const QuizItem(
    this._formas,
    this.category, {
    this.promptLimit = 1,
    this.showFirstOnMatch = false,
  });

  /// Adaptador para las listas bilingües (clase BilingualTerm).
  /// En la pregunta sale solo la forma principal y la celda verde muestra
  /// siempre la forma oficial, aunque el jugador haya escrito una variante.
  factory QuizItem.fromTerm(BilingualTerm t) => QuizItem(
        {
          Language.english: t.english,
          Language.spanish: t.spanish,
        },
        t.category,
        showFirstOnMatch: true,
      );

  final Map<Language, List<String>> _formas;

  /// Categoría del término (para agrupar; no se muestra por ahora).
  final String category;

  /// Cuántas formas se muestran juntas cuando este idioma es la PREGUNTA.
  final int promptLimit;

  /// true = al acertar se muestra la forma principal, no lo que se escribió.
  final bool showFirstOnMatch;

  /// Todas las formas válidas en [idioma] (la primera es la principal).
  List<String> answersIn(Language idioma) => _formas[idioma]!;
}
