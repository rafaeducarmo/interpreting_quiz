// Lógica del quiz en Dart PURO: no importa Flutter.
// Así se puede probar con `flutter test` sin abrir ninguna pantalla,
// y la pantalla (quiz_screen.dart) solo se encarga de dibujar.

import 'dart:math';

import 'quiz_model.dart';

// Quien importe quiz_logic.dart también recibe Language, QuizMode y QuizItem.
export 'quiz_model.dart';

/// Resultado de una coincidencia: qué elemento se acertó y con qué texto.
class MatchResult {
  /// Posición del elemento en la lista que se le pasó a la función.
  final int index;

  /// El texto que se muestra en la celda verde y en el mensaje, tal como
  /// está en los datos (sin normalizar), p. ej. "dog" o "Intérprete".
  final String answer;

  const MatchResult(this.index, this.answer);
}

// ---------------------------------------------------------------------------
// Normalización
// ---------------------------------------------------------------------------

/// Pasa a minúsculas, quita todo lo que no sea letra, número o espacio, y
/// junta los espacios. `unicode: true` hace que \p{L} (cualquier letra)
/// funcione en Dart. Esto elimina también ¿ ? ¡ ! y las comillas.
///
/// Los guiones se cambian por ESPACIO antes de limpiar (no se borran), así
/// "self-correction" y "self correction" quedan iguales.
String _limpiar(String texto) {
  final sinGuiones = texto
      .toLowerCase()
      .replaceAll(RegExp(r'[-‐‑–—]'), ' ');
  final sinPuntuacion =
      sinGuiones.replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), '');
  return sinPuntuacion.trim().replaceAll(RegExp(r'\s+'), ' ');
}

/// Quita un prefijo de la lista solo si va seguido de un espacio.
/// Ej.: "to go" -> "go", pero "to" solo se queda como "to".
String _quitarPrefijo(String texto, List<String> prefijos) {
  for (final p in prefijos) {
    if (texto.startsWith('$p ')) return texto.substring(p.length + 1);
  }
  return texto;
}

/// Normaliza una respuesta en INGLÉS: minúsculas, sin puntuación,
/// sin "to " / "a " / "an " / "the " al inicio.
String normalizeEnglish(String texto) =>
    _quitarPrefijo(_limpiar(texto), const ['to', 'the', 'an', 'a']);

/// Normaliza una respuesta en ESPAÑOL: minúsculas, sin puntuación (¿ ? ¡ !
/// incluidos), tildes opcionales (á=a, é=e, í=i, ó=o, ú=u, ü=u), ñ=n y
/// artículo el/la/los/las/un/una opcional al inicio.
String normalizeSpanish(String texto) {
  const equivalencias = {
    'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ü': 'u', 'ñ': 'n', //
  };
  final sinTildes = _limpiar(texto)
      .split('')
      .map((letra) => equivalencias[letra] ?? letra)
      .join();
  return _quitarPrefijo(sinTildes, const ['los', 'las', 'el', 'la', 'una', 'un']);
}

/// Normaliza [texto] con las reglas del [idioma] en el que se ESCRIBE.
String normalize(String texto, Language idioma) {
  switch (idioma) {
    case Language.english:
      return normalizeEnglish(texto);
    case Language.spanish:
      return normalizeSpanish(texto);
  }
}

// ---------------------------------------------------------------------------
// Datos de cada elemento según el modo
// ---------------------------------------------------------------------------

/// Respuestas válidas de un elemento, SIN normalizar (tal como están en los
/// datos): las formas del idioma que se escribe. La primera es la principal.
List<String> rawAnswers(QuizItem item, QuizMode modo) =>
    item.answersIn(modo.to);

/// Lo que se le muestra al jugador como pregunta: la forma (o las primeras
/// formas, según el elemento) del idioma que se VE, separadas por " / ".
String promptFor(QuizItem item, QuizMode modo) =>
    item.answersIn(modo.from).take(item.promptLimit).join(' / ');

/// Respuesta que se muestra al rendirse (la principal del elemento).
String revealAnswer(QuizItem item, QuizMode modo) =>
    rawAnswers(item, modo).first;

/// Qué texto se muestra al acertar con la forma [escrita]: la forma oficial
/// (la primera) en los elementos que lo piden, o la que se acertó en el resto.
String _textoAcertado(QuizItem item, QuizMode modo, String escrita) =>
    item.showFirstOnMatch ? revealAnswer(item, modo) : escrita;

// ---------------------------------------------------------------------------
// Cuadrícula
// ---------------------------------------------------------------------------

/// Cuántas filas necesita la cuadrícula para [total] palabras en [columnas].
int gridRows(int total, int columnas) => (total + columnas - 1) ~/ columnas;

/// Índice de la palabra que va en la celda (fila, columna), ordenando POR
/// COLUMNAS como Sporcle: con 4 columnas y 200 palabras, la columna 0 lleva
/// las palabras 0–49, la 1 las 50–99, etc., de arriba hacia abajo.
/// Devuelve null si la celda queda vacía (última columna incompleta).
int? gridIndex({
  required int fila,
  required int columna,
  required int columnas,
  required int total,
}) {
  final indice = columna * gridRows(total, columnas) + fila;
  return indice < total ? indice : null;
}

// ---------------------------------------------------------------------------
// Orden aleatorio
// ---------------------------------------------------------------------------

/// Devuelve una permutación aleatoria de 0..total-1 (algoritmo Fisher-Yates:
/// recorre la lista de atrás hacia adelante intercambiando cada elemento con
/// otro al azar de los que quedan; todas las permutaciones son igual de
/// probables). Se recibe el [azar] para poder usar una semilla en los tests:
/// `Random(42)` siempre da el mismo resultado.
List<int> shuffledOrder(int total, Random azar) {
  final orden = [for (var i = 0; i < total; i++) i];
  for (var i = total - 1; i > 0; i--) {
    final j = azar.nextInt(i + 1); // 0..i
    final tmp = orden[i];
    orden[i] = orden[j];
    orden[j] = tmp;
  }
  return orden;
}

/// Los elementos en el orden en que se muestran: mezclados con [azar], o tal
/// cual vienen si [azar] es null. La posición en esta lista es la celda de la
/// cuadrícula (ver gridIndex): todo lo demás (selección, acertadas,
/// navegación) trabaja con POSICIONES de esta lista.
List<T> orderedWords<T>(List<T> lista, Random? azar) {
  if (azar == null) return lista;
  return [for (final i in shuffledOrder(lista.length, azar)) lista[i]];
}

// ---------------------------------------------------------------------------
// Navegación (modo ordenado)
// ---------------------------------------------------------------------------
// El orden de la cuadrícula es por columnas (ver gridIndex), así que "la
// siguiente palabra" es simplemente el siguiente índice: 0, 1, 2 ... 199.

/// Siguiente palabra PENDIENTE después de [actual], dando la vuelta al final
/// (circular). Se salta las ya acertadas. Si [actual] es la única pendiente,
/// devuelve [actual]. Devuelve null si no queda ninguna pendiente.
/// [actual] puede ser -1 para "antes de la primera".
int? nextPending(int actual, Set<int> acertadas, int total) {
  for (var paso = 1; paso <= total; paso++) {
    // El % de Dart con divisor positivo nunca da negativos, así que -1 funciona.
    final i = (actual + paso) % total;
    if (!acertadas.contains(i)) return i;
  }
  return null;
}

/// Palabra PENDIENTE anterior a [actual], circular (de la primera pasa a la
/// última). Mismas reglas que [nextPending].
int? previousPending(int actual, Set<int> acertadas, int total) {
  for (var paso = 1; paso <= total; paso++) {
    final i = (actual - paso) % total;
    if (!acertadas.contains(i)) return i;
  }
  return null;
}

/// Primera palabra pendiente (null si ya están todas acertadas).
int? firstPending(Set<int> acertadas, int total) =>
    nextPending(-1, acertadas, total);

/// Modo ordenado: compara lo escrito SOLO con una palabra concreta.
/// Usa las mismas reglas de normalización que [findMatch]. No hay caso
/// ambiguo: como solo se compara con la palabra seleccionada, "be" no puede
/// ser el inicio de "become" y se acepta de inmediato.
MatchResult? matchSelected(
  String entrada,
  QuizItem palabra,
  int indice,
  QuizMode modo,
) {
  final texto = normalize(entrada, modo.to);
  if (texto.isEmpty) return null;
  for (final cruda in rawAnswers(palabra, modo)) {
    if (normalize(cruda, modo.to) == texto) {
      return MatchResult(indice, _textoAcertado(palabra, modo, cruda));
    }
  }
  return null;
}

// ---------------------------------------------------------------------------
// Coincidencias
// ---------------------------------------------------------------------------

/// Busca qué palabra PENDIENTE coincide con lo que escribió el jugador.
///
/// - [entrada]: el texto del campo.
/// - [lista]: los elementos, en el orden en que se muestran.
/// - [acertadas]: índices que ya están resueltos (se ignoran).
/// - [enviado]: true si el jugador presionó Enter.
///
/// Reglas:
/// * Si dos pendientes aceptan lo mismo, gana la primera de la lista.
/// * Si la entrada coincide pero además es el INICIO de la respuesta de otra
///   palabra pendiente (ej. "be" y "become"), no se marca sola: solo cuando
///   [enviado] es true.
/// Devuelve null si no hay nada que marcar.
MatchResult? findMatch(
  String entrada,
  List<QuizItem> lista,
  Set<int> acertadas,
  QuizMode modo, {
  bool enviado = false,
}) {
  final texto = normalize(entrada, modo.to);
  if (texto.isEmpty) return null;

  // 1) Primer elemento pendiente cuya respuesta coincide exactamente.
  int? indice;
  String? respuesta;
  for (var i = 0; i < lista.length && indice == null; i++) {
    if (acertadas.contains(i)) continue;
    for (final cruda in rawAnswers(lista[i], modo)) {
      if (normalize(cruda, modo.to) == texto) {
        indice = i;
        respuesta = _textoAcertado(lista[i], modo, cruda);
        break;
      }
    }
  }
  if (indice == null) return null;

  // 2) Si no se presionó Enter, comprobar que no sea inicio de otra respuesta
  //    más larga de OTRO elemento pendiente.
  if (!enviado) {
    for (var j = 0; j < lista.length; j++) {
      if (j == indice || acertadas.contains(j)) continue;
      for (final cruda in rawAnswers(lista[j], modo)) {
        final otra = normalize(cruda, modo.to);
        if (otra.length > texto.length && otra.startsWith(texto)) {
          return null; // ambiguo: esperar a Enter
        }
      }
    }
  }
  return MatchResult(indice, respuesta!);
}
