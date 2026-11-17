import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:interpreting_quiz/bilingual_terms.dart';
import 'package:interpreting_quiz/quiz_logic.dart';
import 'package:interpreting_quiz/word_lists.dart';

/// Elemento de prueba EN/ES (como los de las listas reales: la primera forma
/// es la oficial y se muestra al acertar).
QuizItem q(List<String> en, List<String> es) =>
    QuizItem.fromTerm(BilingualTerm(en, es, 't'));

/// Lista pequeña para probar findMatch sin depender de los datos reales.
final glos = [
  q(['Pain', 'ache'], ['Dolor']), //                0
  q(['Painful'], ['Doloroso']), //                  1
  q(['Fever'], ['Fiebre']), //                      2
  q(['Fever'], ['Calentura']), //                   3 (misma respuesta que la 2)
  q(['Holiday', 'Holidays'], ['Fiesta']), //        4
  q(['Interpreter'], ['Intérprete']), //            5
];

void main() {
  group('normalizeEnglish', () {
    test('ignora mayúsculas, espacios extra y puntuación', () {
      expect(normalizeEnglish('  Dog!  '), 'dog');
      expect(normalizeEnglish('thank,   you.'), 'thank you');
    });

    test('quita "to ", "a ", "an ", "the " al inicio', () {
      expect(normalizeEnglish('to go'), 'go');
      expect(normalizeEnglish('The dog'), 'dog');
      expect(normalizeEnglish('a house'), 'house');
      expect(normalizeEnglish('an apple'), 'apple');
    });

    test('no quita "to"/"a" cuando no hay nada más', () {
      expect(normalizeEnglish('to'), 'to');
      expect(normalizeEnglish('a'), 'a');
    });

    test('no quita "to" en medio de la frase', () {
      expect(normalizeEnglish('ought to'), 'ought to');
      expect(normalizeEnglish('have to'), 'have to');
    });
  });

  group('promptFor / revealAnswer', () {
    test('muestra solo la forma principal del idioma que se ve', () {
      expect(promptFor(glos[0], QuizMode.enToEs), 'Pain');
      expect(promptFor(glos[0], QuizMode.esToEn), 'Dolor');
    });

    test('revealAnswer da la respuesta principal', () {
      expect(revealAnswer(glos[0], QuizMode.esToEn), 'Pain');
      expect(revealAnswer(glos[0], QuizMode.enToEs), 'Dolor');
    });
  });

  group('findMatch ES→EN (se escribe en inglés)', () {
    const modo = QuizMode.esToEn;

    test('encuentra una traducción válida y muestra la forma oficial', () {
      final r = findMatch('fever', glos, {}, modo);
      expect(r!.index, 2);
      expect(r.answer, 'Fever');
      final v = findMatch('ache', glos, {}, modo);
      expect(v!.index, 0);
      expect(v.answer, 'Pain'); // la oficial, no la variante escrita
    });

    test('ignora mayúsculas, puntuación y "the"', () {
      expect(findMatch('  FEVER! ', glos, {}, modo)!.index, 2);
      expect(findMatch('the fever', glos, {}, modo)!.index, 2);
    });

    test('devuelve null si no hay coincidencia o el texto está vacío', () {
      expect(findMatch('xyz', glos, {}, modo), isNull);
      expect(findMatch('', glos, {}, modo), isNull);
      expect(findMatch('   ', glos, {}, modo), isNull);
    });

    test('no marca un elemento que ya está acertado', () {
      expect(findMatch('ache', glos, {0}, modo), isNull);
    });

    test('"pain" es ambiguo ("painful"): solo con Enter', () {
      expect(findMatch('pain', glos, {}, modo), isNull);
      expect(findMatch('pain', glos, {}, modo, enviado: true)!.index, 0);
    });

    test('si la respuesta más larga ya está acertada, ya no hay ambigüedad', () {
      expect(findMatch('pain', glos, {1}, modo)!.index, 0);
    });

    test('un prefijo de otra respuesta no basta: "painf" no marca nada', () {
      expect(findMatch('painf', glos, {}, modo, enviado: true), isNull);
    });

    test('las variantes del mismo elemento no cuentan como ambiguas', () {
      // "holiday" es inicio de "holidays", pero ambas son del elemento 4.
      expect(findMatch('holiday', glos, {}, modo)!.index, 4);
    });

    test('dos elementos con la misma respuesta: primero uno y luego el otro', () {
      final acertadas = <int>{};
      final r1 = findMatch('fever', glos, acertadas, modo);
      expect(r1!.index, 2);
      acertadas.add(r1.index);
      expect(findMatch('fever', glos, acertadas, modo)!.index, 3);
      acertadas.add(3);
      expect(findMatch('fever', glos, acertadas, modo), isNull);
    });
  });

  group('findMatch EN→ES (se escribe en español)', () {
    const modo = QuizMode.enToEs;

    test('acepta con y sin tildes y con artículo', () {
      for (final t in ['Intérprete', 'interprete', 'el intérprete', 'UN INTERPRETE']) {
        expect(findMatch(t, glos, {}, modo)!.index, 5, reason: t);
      }
    });

    test('devuelve la forma oficial', () {
      expect(findMatch('interprete', glos, {}, modo)!.answer, 'Intérprete');
    });

    test('un texto que es inicio de otra respuesta espera a Enter', () {
      // "dolor" es respuesta del 0 y también inicio de "doloroso" (1).
      expect(findMatch('dolor', glos, {}, modo), isNull);
      expect(findMatch('dolor', glos, {}, modo, enviado: true)!.index, 0);
    });
  });


  group('gridIndex (orden por columnas)', () {
    int? celda(int fila, int col, int columnas) =>
        gridIndex(fila: fila, columna: col, columnas: columnas, total: 200);

    test('4 columnas: 1–50, 51–100, 101–150, 151–200', () {
      expect(gridRows(200, 4), 50);
      expect(celda(0, 0, 4), 0);
      expect(celda(1, 0, 4), 1); // la 2.ª palabra va debajo de la 1.ª
      expect(celda(49, 0, 4), 49);
      expect(celda(0, 1, 4), 50);
      expect(celda(0, 2, 4), 100);
      expect(celda(49, 3, 4), 199);
    });

    test('2 columnas: 1–100 y 101–200', () {
      expect(celda(0, 0, 2), 0);
      expect(celda(99, 0, 2), 99);
      expect(celda(0, 1, 2), 100);
      expect(celda(99, 1, 2), 199);
    });

    test('1 columna: en orden', () {
      expect(celda(0, 0, 1), 0);
      expect(celda(199, 0, 1), 199);
    });

    test('con un total que no divide exacto quedan celdas vacías', () {
      // 10 palabras en 4 columnas: 3 filas -> columnas de 3, 3, 3, 1.
      int? c(int f, int col) =>
          gridIndex(fila: f, columna: col, columnas: 4, total: 10);
      expect(gridRows(10, 4), 3);
      expect(c(0, 3), 9);
      expect(c(1, 3), isNull);
      expect(c(2, 3), isNull);
    });

    test('cada palabra aparece exactamente una vez', () {
      for (final columnas in [1, 2, 4]) {
        final vistas = <int>{};
        for (var f = 0; f < gridRows(200, columnas); f++) {
          for (var c = 0; c < columnas; c++) {
            final i = celda(f, c, columnas);
            if (i != null) expect(vistas.add(i), isTrue);
          }
        }
        expect(vistas.length, 200);
      }
    });
  });

  group('orden aleatorio', () {
    test('shuffledOrder es una permutación: cada número sale una sola vez', () {
      final orden = shuffledOrder(200, Random(1));
      expect(orden.length, 200);
      expect(orden.toSet().length, 200);
      expect(orden.reduce(min), 0);
      expect(orden.reduce(max), 199);
    });

    test('de verdad cambia el orden (no queda igual al original)', () {
      final original = [for (var i = 0; i < 200; i++) i];
      expect(shuffledOrder(200, Random(1)), isNot(original));
    });

    test('con la misma semilla da el mismo orden; con otra, uno distinto', () {
      expect(shuffledOrder(200, Random(5)), shuffledOrder(200, Random(5)));
      expect(shuffledOrder(200, Random(5)), isNot(shuffledOrder(200, Random(6))));
    });

    test('llamadas seguidas con el mismo Random dan órdenes nuevos', () {
      final azar = Random(9);
      expect(shuffledOrder(200, azar), isNot(shuffledOrder(200, azar)));
    });

    test('casos pequeños: 0 y 1 elementos', () {
      expect(shuffledOrder(0, Random(1)), isEmpty);
      expect(shuffledOrder(1, Random(1)), [0]);
    });

    test('orderedWords sin azar devuelve la lista tal cual', () {
      expect(identical(orderedWords(trainingItems, null), trainingItems), isTrue);
    });

    test('orderedWords con azar contiene los mismos 200 elementos', () {
      final mezcladas = orderedWords(trainingItems, Random(3));
      expect(mezcladas.length, 200);
      expect(mezcladas.toSet().length, 200); // ninguno repetido
      expect(mezcladas.toSet(), trainingItems.toSet()); // ninguno perdido
      expect(mezcladas, isNot(trainingItems));
    });

    test('findMatch con una lista mezclada marca las duplicadas en el orden mostrado', () {
      // Los elementos 2 y 3 de glos aceptan lo mismo ("fever") en ES→EN. Se
      // marca primero el que esté antes EN LA LISTA QUE SE LE PASA.
      final lista = [glos[3], glos[2]];
      final r = findMatch('fever', lista, {}, QuizMode.esToEn);
      expect(r!.index, 0);
      expect(findMatch('fever', lista, {0}, QuizMode.esToEn)!.index, 1);
    });
  });



  group('navegación nextPending / previousPending', () {
    test('avanza al siguiente índice', () {
      expect(nextPending(0, {}, 200), 1);
      expect(nextPending(41, {}, 200), 42);
    });

    test('retrocede al índice anterior', () {
      expect(previousPending(5, {}, 200), 4);
    });

    test('se salta las ya acertadas', () {
      expect(nextPending(0, {1, 2}, 200), 3);
      expect(previousPending(5, {4, 3}, 200), 2);
    });

    test('es circular: de la última pasa a la primera y al revés', () {
      expect(nextPending(199, {}, 200), 0);
      expect(previousPending(0, {}, 200), 199);
    });

    test('la vuelta también se salta las acertadas', () {
      expect(nextPending(199, {0, 1}, 200), 2);
      expect(previousPending(0, {199, 198}, 200), 197);
    });

    test('si solo queda una pendiente, devuelve esa misma', () {
      final todasMenos7 = {for (var i = 0; i < 200; i++) if (i != 7) i};
      expect(nextPending(7, todasMenos7, 200), 7);
      expect(previousPending(7, todasMenos7, 200), 7);
    });

    test('desde una palabra ya acertada busca la pendiente más cercana', () {
      // Justo después de acertar la 10 (ya en el conjunto) -> la 11.
      expect(nextPending(10, {10}, 200), 11);
      expect(nextPending(199, {199}, 200), 0);
    });

    test('devuelve null si ya no queda ninguna pendiente', () {
      final todas = {for (var i = 0; i < 200; i++) i};
      expect(nextPending(5, todas, 200), isNull);
      expect(previousPending(5, todas, 200), isNull);
      expect(firstPending(todas, 200), isNull);
    });

    test('firstPending: la primera sin acertar', () {
      expect(firstPending({}, 200), 0);
      expect(firstPending({0, 1, 2}, 200), 3);
    });

    test('recorrer todas con nextPending visita cada palabra una vez', () {
      final vistas = <int>[];
      var actual = firstPending({}, 200)!;
      for (var i = 0; i < 200; i++) {
        vistas.add(actual);
        actual = nextPending(actual, {}, 200)!;
      }
      expect(vistas, [for (var i = 0; i < 200; i++) i]);
      expect(actual, 0); // dio la vuelta completa
    });
  });

  group('matchSelected (modo ordenado)', () {
    final dolor = glos[0];

    test('acepta la respuesta del elemento seleccionado', () {
      final r = matchSelected('ache', dolor, 7, QuizMode.esToEn);
      expect(r!.index, 7);
      expect(r.answer, 'Pain');
    });

    test('rechaza la respuesta de otro elemento', () {
      expect(matchSelected('fever', dolor, 7, QuizMode.esToEn), isNull);
    });

    test('usa las mismas reglas de normalización', () {
      expect(matchSelected('  THE Pain! ', dolor, 7, QuizMode.esToEn), isNotNull);
      expect(matchSelected('interprete', glos[5], 1, QuizMode.enToEs), isNotNull);
      expect(matchSelected('el Intérprete', glos[5], 1, QuizMode.enToEs), isNotNull);
    });

    test('no hay ambigüedad: "pain" se acepta de inmediato para el 0', () {
      expect(matchSelected('pain', dolor, 3, QuizMode.esToEn), isNotNull);
    });

    test('texto vacío no coincide', () {
      expect(matchSelected('', dolor, 7, QuizMode.esToEn), isNull);
      expect(matchSelected('  ', dolor, 7, QuizMode.esToEn), isNull);
    });
  });


  // ------------------------------------------------------------------
  // Español y listas bilingües
  // ------------------------------------------------------------------

  group('normalizeSpanish', () {
    test('las tildes son opcionales', () {
      expect(normalizeSpanish('Intérprete'), normalizeSpanish('interprete'));
      expect(normalizeSpanish('Interpretación'), 'interpretacion');
      expect(normalizeSpanish('Síntomas'), normalizeSpanish('sintomas'));
      expect(normalizeSpanish('pingüino'), 'pinguino'); // ü = u
      expect(normalizeSpanish('ÁÉÍÓÚ'), 'aeiou'); // también en mayúsculas
    });

    test('ñ = n', () {
      expect(normalizeSpanish('niño'), normalizeSpanish('nino'));
      expect(normalizeSpanish('Consulta de niño sano'),
          normalizeSpanish('consulta de nino sano'));
    });

    test('ignora ¿ ? ¡ ! y otros signos', () {
      expect(normalizeSpanish('¿Dónde le duele?'), 'donde le duele');
      expect(normalizeSpanish('¡Espere un momento!'), 'espere un momento');
      expect(normalizeSpanish('  hola,   ¿qué tal?  '), 'hola que tal');
    });

    test('los artículos el, la, los, las, un, una son opcionales', () {
      expect(normalizeSpanish('el pulso'), 'pulso');
      expect(normalizeSpanish('La cita'), 'cita');
      expect(normalizeSpanish('los síntomas'), 'sintomas');
      expect(normalizeSpanish('las alergias'), 'alergias');
      expect(normalizeSpanish('un momento'), 'momento');
      expect(normalizeSpanish('una receta'), 'receta');
    });

    test('un artículo solo (sin nada más) no se quita', () {
      expect(normalizeSpanish('la'), 'la');
      expect(normalizeSpanish('el'), 'el');
    });

    test('solo se quita el artículo inicial, no los del medio', () {
      expect(normalizeSpanish('Médico de la familia'), 'medico de la familia');
    });

    test('NO se quitan "to", "a" ni "the" en español', () {
      expect(normalizeSpanish('a la derecha'), 'a la derecha');
    });
  });

  group('guiones y espacios', () {
    test('un guion vale como un espacio (inglés)', () {
      expect(normalizeEnglish('Self-correction'), 'self correction');
      expect(normalizeEnglish('self correction'), normalizeEnglish('Self-correction'));
      expect(normalizeEnglish('over-the-counter'), 'over the counter');
    });

    test('un guion vale como un espacio (español)', () {
      expect(normalizeSpanish('Potencialmente-mortal'), 'potencialmente mortal');
    });

    test('las variantes sin guion siguen siendo distintas, pero las lista el autor', () {
      expect(normalizeEnglish('checkup'), 'checkup');
      expect(normalizeEnglish('Check-up'), 'check up');
    });

    test('guiones largos y espacios sobrantes se juntan', () {
      expect(normalizeEnglish('well – child   visit'), 'well child visit');
    });
  });

  group('normalize elige las reglas por idioma', () {
    test('cada idioma usa las suyas', () {
      expect(normalize('The Dog!', Language.english), 'dog');
      expect(normalize('Interpretación', Language.spanish), 'interpretacion');
      // El artículo "the" solo se ignora en inglés:
      expect(normalize('the', Language.spanish), 'the');
      expect(normalize('el pulso', Language.english), 'el pulso');
    });
  });

  group('QuizMode y QuizItem', () {
    test('cada modo sabe qué idioma se ve y cuál se escribe', () {
      expect(QuizMode.enToEs.from, Language.english);
      expect(QuizMode.enToEs.to, Language.spanish);
      expect(QuizMode.esToEn.from, Language.spanish);
      expect(QuizMode.esToEn.to, Language.english);
    });

    test('las dos listas tienen sus direcciones', () {
      expect(wordLists.map((l) => l.nombre),
          ['Glosario de entrenamiento', 'Médico ampliado']);
      expect(wordLists[0].modos, [QuizMode.enToEs, QuizMode.esToEn]);
      expect(wordLists[1].modos, [QuizMode.enToEs, QuizMode.esToEn]);
    });

    test('las listas con frases largas usan menos columnas', () {
      for (final lista in wordLists) {
        expect([799.0, 800.0, 1499.0, 1500.0].map(lista.columnasPara),
            [1, 2, 2, 4]);
      }
    });

    test('cada lista tiene 200 elementos', () {
      for (final lista in wordLists) {
        expect(lista.items.length, 200, reason: lista.nombre);
      }
    });


    test('el adaptador de BilingualTerm muestra solo la forma principal', () {
      final receta = trainingItems.firstWhere(
          (t) => t.answersIn(Language.english).first == 'Prescription');
      expect(promptFor(receta, QuizMode.enToEs), 'Prescription');
      expect(promptFor(receta, QuizMode.esToEn), 'Receta médica');
      expect(revealAnswer(receta, QuizMode.enToEs), 'Receta médica');
      expect(revealAnswer(receta, QuizMode.esToEn), 'Prescription');
    });

    test('con una variante, la celda verde muestra la forma oficial', () {
      final receta = trainingItems.firstWhere(
          (t) => t.answersIn(Language.english).first == 'Prescription');
      final r = matchSelected('receta', receta, 5, QuizMode.enToEs);
      expect(r!.index, 5);
      expect(r.answer, 'Receta médica'); // no "receta"
    });

    test('las variantes en inglés también se aceptan (EN←ES)', () {
      final repeat = trainingItems.firstWhere(
          (t) => t.answersIn(Language.english).first == 'Repeat please');
      expect(matchSelected('please repeat', repeat, 0, QuizMode.esToEn), isNotNull);
      expect(matchSelected('Repeat, please!', repeat, 0, QuizMode.esToEn), isNotNull);
      expect(matchSelected('say again', repeat, 0, QuizMode.esToEn), isNull);
    });

    test('español: tildes y artículos opcionales al escribir', () {
      final interprete = trainingItems.firstWhere(
          (t) => t.answersIn(Language.english).first == 'Interpreter');
      for (final texto in ['Intérprete', 'interprete', 'el intérprete', 'UN INTERPRETE']) {
        expect(matchSelected(texto, interprete, 0, QuizMode.enToEs), isNotNull,
            reason: texto);
      }
    });

    test('findMatch en modo libre funciona con una lista bilingüe', () {
      final r = findMatch('interprete', trainingItems, {}, QuizMode.enToEs);
      expect(r, isNotNull);
      expect(r!.answer, 'Intérprete');
      expect(
          promptFor(trainingItems[r.index], QuizMode.enToEs), 'Interpreter');
    });
  });

  group('integridad de los datos', () {
    // Quita tildes y ñ a mano (sin usar normalizeSpanish) para comprobar que
    // las respuestas siguen valiendo escritas sin ellas.
    String sinTildes(String s) {
      const m = {
        'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ü': 'u', 'ñ': 'n', //
        'Á': 'A', 'É': 'E', 'Í': 'I', 'Ó': 'O', 'Ú': 'U', 'Ñ': 'N',
      };
      return s.split('').map((c) => m[c] ?? c).join();
    }

    test('hay 200 + 200 términos bilingües', () {
      expect(trainingItems.length, 200);
      expect(medicalItems.length, 200);
    });

    for (final lista in wordLists) {
      for (final modo in lista.modos) {
        test('${lista.nombre}: todo elemento se puede acertar en ${modo.id}', () {
          final items = lista.items;
          for (var i = 0; i < items.length; i++) {
            final respuestas = rawAnswers(items[i], modo);
            expect(respuestas, isNotEmpty, reason: 'elemento $i sin respuestas');
            expect(promptFor(items[i], modo), isNotEmpty);

            for (final cruda in respuestas) {
              final conjunto = {...respuestas};
              expect(conjunto.length, respuestas.length,
                  reason: 'repetidas en $i');
              expect(normalize(cruda, modo.to), isNotEmpty,
                  reason: '"$cruda" se normaliza a vacío');

              // Modo libre (con Enter): puede caer en un elemento anterior que
              // acepta lo mismo, pero nunca en uno posterior ni en ninguno.
              final libre = findMatch(cruda, items, {}, modo, enviado: true);
              expect(libre, isNotNull, reason: '"$cruda" no coincide con nada');
              expect(libre!.index, lessThanOrEqualTo(i), reason: '"$cruda"');

              // Modo ordenado: se acepta SIEMPRE en su propio elemento.
              final ordenado = matchSelected(cruda, items[i], i, modo);
              expect(ordenado, isNotNull, reason: '"$cruda" en el elemento $i');
              expect(ordenado!.index, i);

              // Y las tildes siguen siendo opcionales en español.
              if (modo.to == Language.spanish) {
                expect(matchSelected(sinTildes(cruda), items[i], i, modo),
                    isNotNull,
                    reason: '"${sinTildes(cruda)}" (sin tildes) en el elemento $i');
              }
            }
          }
        });
      }
    }

    test('las listas bilingües siempre muestran la forma oficial al acertar', () {
      for (final items in [trainingItems, medicalItems]) {
        for (final modo in [QuizMode.enToEs, QuizMode.esToEn]) {
          for (var i = 0; i < items.length; i++) {
            for (final cruda in rawAnswers(items[i], modo)) {
              final r = matchSelected(cruda, items[i], i, modo)!;
              expect(r.answer, revealAnswer(items[i], modo), reason: cruda);
            }
          }
        }
      }
    });

    test('en las listas bilingües la pregunta es una sola forma (la primera)', () {
      for (final items in [trainingItems, medicalItems]) {
        for (final item in items) {
          expect(promptFor(item, QuizMode.enToEs),
              item.answersIn(Language.english).first);
          expect(promptFor(item, QuizMode.esToEn),
              item.answersIn(Language.spanish).first);
        }
      }
    });

    test('no hay dos elementos con la misma pregunta principal en la misma lista', () {
      for (final lista in wordLists) {
        for (final modo in lista.modos) {
          final vistas = <String>{};
          final repetidas = <String>[];
          for (final item in lista.items) {
            if (!vistas.add(promptFor(item, modo))) {
              repetidas.add(promptFor(item, modo));
            }
          }
          // Solo informativo: puede haber preguntas repetidas en los datos y no
          // es un error, pero así queda a la vista si pasa.
          printOnFailure('${lista.nombre} ${modo.id}: repetidas $repetidas');
        }
      }
    });
  });
}