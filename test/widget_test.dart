// Tests de la pantalla del quiz.

import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:interpreting_quiz/main.dart';
import 'package:interpreting_quiz/quiz_logic.dart';
import 'package:interpreting_quiz/word_lists.dart';

/// Datos de las dos listas (la app arranca en el glosario, EN → ES).
final glosario = trainingItems;
final medico = medicalItems;

/// Pregunta del elemento [i] del glosario en EN → ES (se ve el inglés).
String pEn(int i) => promptFor(glosario[i], QuizMode.enToEs);

/// Pregunta del elemento [i] del glosario en ES → EN (se ve el español).
String pEs(int i) => promptFor(glosario[i], QuizMode.esToEn);

/// Respuesta principal en español / inglés del elemento [i] del glosario.
String esp(int i) => glosario[i].answersIn(Language.spanish).first;
String ing(int i) => glosario[i].answersIn(Language.english).first;

/// Un elemento del glosario cuya respuesta en español es el INICIO de la
/// respuesta de otro (caso ambiguo en modo libre). Devuelve su índice.
int elementoAmbiguo() {
  for (var k = 0; k < glosario.length; k++) {
    final corta = normalize(esp(k), Language.spanish);
    for (var j = 0; j < glosario.length; j++) {
      if (j == k) continue;
      for (final r in glosario[j].answersIn(Language.spanish)) {
        final larga = normalize(r, Language.spanish);
        if (larga.length > corta.length && larga.startsWith(corta)) return k;
      }
    }
  }
  return -1;
}

/// Simula presionar Enter en el campo de texto.
Future<void> presionarEnter(WidgetTester tester) async {
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pump();
}

/// ¿Tiene el campo de texto el foco del teclado?
bool campoTieneFoco(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus;

bool campoActivo(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField)).enabled ?? true;

String textoDelCampo(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField)).controller!.text;

/// Abre la app en una pantalla ancha de escritorio.
/// Por defecto la app arranca en modo ORDENADO; con [libre] cambia a LIBRE.
/// [azar] fija el generador aleatorio (con una semilla) para conocer el orden
/// que producirá "Mezclar orden".
Future<void> abrir(WidgetTester tester,
    {bool libre = false, Random? azar}) async {
  tester.view.physicalSize = const Size(1400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(InterpretingQuizApp(random: azar));
  await tester.pump();
  if (libre) {
    await tester.tap(find.byKey(const Key('orden_libre')));
    await tester.pump();
    await tester.pump();
  }
}

/// Comprueba que la fila resaltada es la del elemento cuya PREGUNTA es
/// [textoPregunta] (el rectángulo resaltado contiene a ese texto).
Future<void> expectSeleccion(WidgetTester tester, String textoPregunta) async {
  await tester.pumpAndSettle(); // deja terminar el scroll automático
  final sel = find.byKey(const Key('seleccion'));
  expect(sel, findsOneWidget, reason: 'debe haber una fila seleccionada');
  final texto = find.text(textoPregunta);
  expect(texto, findsOneWidget, reason: '"$textoPregunta" debe estar a la vista');
  expect(tester.getRect(sel).contains(tester.getCenter(texto)), isTrue,
      reason: 'la selección debería estar en "$textoPregunta"');
}

Future<void> tocar(WidgetTester tester, Key llave) async {
  await tester.tap(find.byKey(llave));
  await tester.pump();
  await tester.pump();
}

void main() {
  // =========================== MODO LIBRE ===========================
  // (se acepta cualquier elemento pendiente)

  testWidgets('empieza en 0/200 con el foco en el campo', (tester) async {
    await abrir(tester);
    expect(find.textContaining('0/200'), findsOneWidget);
    expect(campoTieneFoco(tester), isTrue);
  });

  testWidgets('libre: escribir una respuesta la marca, vacía el campo y mantiene el foco',
      (tester) async {
    await abrir(tester, libre: true);

    await tester.enterText(find.byType(TextField), 'interprete'); // sin tilde
    await tester.pump();

    expect(find.textContaining('1/200'), findsOneWidget);
    expect(find.text('✔ Interpreter = Intérprete'), findsOneWidget);
    expect(textoDelCampo(tester), '');
    expect(campoTieneFoco(tester), isTrue);

    await tester.enterText(find.byType(TextField), 'interpretacion consecutiva');
    await tester.pump();
    expect(find.textContaining('2/200'), findsOneWidget);
    expect(campoTieneFoco(tester), isTrue);
  });

  testWidgets('libre: un caso ambiguo (inicio de otra respuesta) solo se marca con Enter',
      (tester) async {
    final k = elementoAmbiguo();
    expect(k, greaterThanOrEqualTo(0), reason: 'los datos deben tener un caso así');
    await abrir(tester, libre: true);

    await tester.enterText(find.byType(TextField), esp(k));
    await tester.pump();
    expect(find.textContaining('0/200'), findsOneWidget);

    await presionarEnter(tester);
    expect(find.textContaining('1/200'), findsOneWidget);
    expect(campoTieneFoco(tester), isTrue);
  });

  testWidgets('libre: Enter sin coincidencia muestra el aviso y conserva el foco',
      (tester) async {
    await abrir(tester, libre: true);

    await tester.enterText(find.byType(TextField), 'xyz');
    await presionarEnter(tester);

    expect(find.text('No coincide con ninguna palabra pendiente'), findsOneWidget);
    expect(find.textContaining('0/200'), findsOneWidget);
    expect(campoTieneFoco(tester), isTrue);

    await tester.enterText(find.byType(TextField), 'xyzw');
    await tester.pump();
    expect(find.text('No coincide con ninguna palabra pendiente'), findsNothing);
  });

  testWidgets('libre: no hay resaltado ni botones Anterior/Siguiente',
      (tester) async {
    await abrir(tester, libre: true);
    expect(find.byKey(const Key('seleccion')), findsNothing);
    expect(find.byKey(const Key('btn_anterior')), findsNothing);
    expect(find.byKey(const Key('btn_siguiente')), findsNothing);
  });

  testWidgets('libre: Tab no saca el foco del campo', (tester) async {
    await abrir(tester, libre: true);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(campoTieneFoco(tester), isTrue);
  });

  // ---------------------- Me rindo / Reiniciar ----------------------

  testWidgets('"Me rindo" desactiva el campo y muestra en rojo las que faltan',
      (tester) async {
    await abrir(tester, libre: true);
    await tester.enterText(find.byType(TextField), 'interprete');
    await tester.pump();

    await tester.tap(find.text('Me rindo'));
    await tester.pump();

    expect(campoActivo(tester), isFalse);
    final pendiente = tester.widget<Text>(find.text(esp(1)));
    expect(pendiente.style!.color, Colors.red.shade800);
    final acertada = tester.widget<Text>(find.text(esp(0)));
    expect(acertada.style!.color, Colors.black);
    expect(find.textContaining('1/200'), findsOneWidget);
  });

  testWidgets('"Reiniciar" funciona después de rendirse y se puede escribir',
      (tester) async {
    await abrir(tester, libre: true);
    await tester.enterText(find.byType(TextField), 'interprete');
    await tester.pump();
    await tester.tap(find.text('Me rindo'));
    await tester.pump();
    expect(campoActivo(tester), isFalse);

    await tester.tap(find.text('Reiniciar'));
    await tester.pump();
    await tester.pump();

    expect(campoActivo(tester), isTrue);
    expect(campoTieneFoco(tester), isTrue);
    expect(find.textContaining('0/200'), findsOneWidget);
    expect(find.text(esp(1)), findsNothing);

    await tester.enterText(find.byType(TextField), 'interpretacion consecutiva');
    await tester.pump();
    expect(find.textContaining('1/200'), findsOneWidget);
  });

  testWidgets('"Reiniciar" a mitad de partida limpia todo', (tester) async {
    await abrir(tester, libre: true);
    await tester.enterText(find.byType(TextField), 'interprete');
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'xyz');
    await presionarEnter(tester);

    await tester.tap(find.text('Reiniciar'));
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('0/200'), findsOneWidget);
    expect(find.text('No coincide con ninguna palabra pendiente'), findsNothing);
    expect(textoDelCampo(tester), '');
    expect(campoTieneFoco(tester), isTrue);
  });

  testWidgets('completar las 200 (ordenado) muestra la felicitación y Reiniciar sigue sirviendo',
      (tester) async {
    await abrir(tester); // ordenado: se responde en orden, sin Enter
    for (var i = 0; i < glosario.length; i++) {
      await tester.enterText(find.byType(TextField), esp(i));
    }
    await tester.pumpAndSettle();

    expect(find.textContaining('200/200'), findsOneWidget);
    expect(find.textContaining('Felicidades'), findsOneWidget);
    expect(campoActivo(tester), isFalse);
    expect(find.byKey(const Key('seleccion')), findsNothing);

    await tester.tap(find.text('Reiniciar'));
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('0/200'), findsOneWidget);
    expect(find.textContaining('Felicidades'), findsNothing);
    expect(campoActivo(tester), isTrue);
    expect(campoTieneFoco(tester), isTrue);
    await expectSeleccion(tester, pEn(0));
  });

  // ============================ MODOS EN/ES ============================

  testWidgets('modo ES → EN (libre): se ve el español y se escribe el inglés',
      (tester) async {
    await abrir(tester, libre: true);
    await tocar(tester, const Key('modo_es_en'));

    expect(find.text(pEs(0)), findsOneWidget);
    expect(find.text(pEn(0)), findsNothing);
    expect(campoTieneFoco(tester), isTrue);

    await tester.enterText(find.byType(TextField), 'the interpreter');
    await tester.pump();
    expect(find.textContaining('1/200'), findsOneWidget);
    expect(find.text(ing(0)), findsOneWidget);
    expect(find.text('✔ Intérprete = Interpreter'), findsOneWidget);
    expect(campoTieneFoco(tester), isTrue);
  });

  testWidgets('cambiar de modo reinicia, incluso después de rendirse',
      (tester) async {
    await abrir(tester, libre: true);
    await tester.enterText(find.byType(TextField), 'interprete');
    await tester.pump();
    await tester.tap(find.text('Me rindo'));
    await tester.pump();

    await tocar(tester, const Key('modo_es_en'));
    expect(find.textContaining('0/200'), findsOneWidget);
    expect(campoActivo(tester), isTrue);
    expect(campoTieneFoco(tester), isTrue);

    await tocar(tester, const Key('modo_en_es'));
    expect(find.text(pEn(0)), findsOneWidget);
    expect(campoTieneFoco(tester), isTrue);
  });

  testWidgets('en ES → EN, "Me rindo" muestra el inglés en rojo', (tester) async {
    await abrir(tester, libre: true);
    await tocar(tester, const Key('modo_es_en'));
    await tester.tap(find.text('Me rindo'));
    await tester.pump();

    final t = tester.widget<Text>(find.text(ing(0)));
    expect(t.style!.color, Colors.red.shade800);
  });

  // =========================== MODO ORDENADO ===========================

  group('modo ordenado', () {
    testWidgets('arranca en Ordenado con el elemento 1 resaltado', (tester) async {
      await abrir(tester);
      await expectSeleccion(tester, pEn(0));
      expect(find.byKey(const Key('btn_anterior')), findsOneWidget);
      expect(find.byKey(const Key('btn_siguiente')), findsOneWidget);
      expect(campoTieneFoco(tester), isTrue);
    });

    testWidgets('solo acepta la respuesta del elemento seleccionado',
        (tester) async {
      await abrir(tester);

      // La respuesta del 2.º no vale: no pasa nada.
      await tester.enterText(find.byType(TextField), esp(1));
      await tester.pump();
      expect(find.textContaining('0/200'), findsOneWidget);
      await expectSeleccion(tester, pEn(0));

      // La de la seleccionada sí.
      await tester.enterText(find.byType(TextField), esp(0));
      await tester.pump();
      expect(find.textContaining('1/200'), findsOneWidget);
      expect(textoDelCampo(tester), '');
      expect(campoTieneFoco(tester), isTrue);
    });

    testWidgets('al acertar, la selección salta a la siguiente pendiente',
        (tester) async {
      await abrir(tester);
      await tester.enterText(find.byType(TextField), esp(0));
      await tester.pump();
      await expectSeleccion(tester, pEn(1));

      await tester.enterText(find.byType(TextField), esp(1));
      await tester.pump();
      await expectSeleccion(tester, pEn(2));
    });

    testWidgets('las reglas de comparación son las mismas (ES → EN)',
        (tester) async {
      await abrir(tester);
      await tocar(tester, const Key('modo_es_en'));
      await expectSeleccion(tester, pEs(0));

      await tester.enterText(find.byType(TextField), 'INTERPRETER');
      await tester.pump();
      expect(find.textContaining('1/200'), findsOneWidget);
      await expectSeleccion(tester, pEs(1));
    });

    testWidgets('no hay ambigüedad: una respuesta que es inicio de otra se marca sin Enter',
        (tester) async {
      final k = elementoAmbiguo();
      expect(k, greaterThanOrEqualTo(0));
      await abrir(tester);
      // Se navega hasta el elemento con Siguiente (el orden es por índice).
      for (var i = 0; i < k; i++) {
        await tester.tap(find.byKey(const Key('btn_siguiente')));
        await tester.pump();
      }
      await expectSeleccion(tester, pEn(k));
      await tester.enterText(find.byType(TextField), esp(k));
      await tester.pump();
      expect(find.textContaining('1/200'), findsOneWidget);
    });

    testWidgets('Enter con una respuesta equivocada muestra el aviso',
        (tester) async {
      await abrir(tester);
      await tester.enterText(find.byType(TextField), esp(1));
      await presionarEnter(tester);

      expect(find.text('No coincide con la palabra seleccionada'), findsOneWidget);
      expect(find.textContaining('0/200'), findsOneWidget);
      expect(campoTieneFoco(tester), isTrue);
      await expectSeleccion(tester, pEn(0));
    });

    testWidgets('Siguiente y Anterior mueven la selección y vacían el campo',
        (tester) async {
      await abrir(tester);

      await tester.enterText(find.byType(TextField), 'xx');
      await tocar(tester, const Key('btn_siguiente'));
      await expectSeleccion(tester, pEn(1));
      expect(textoDelCampo(tester), '');
      expect(campoTieneFoco(tester), isTrue);

      await tocar(tester, const Key('btn_anterior'));
      await expectSeleccion(tester, pEn(0));
      expect(campoTieneFoco(tester), isTrue);
    });

    testWidgets('navegar se salta los elementos ya acertados', (tester) async {
      await abrir(tester);
      // Haz clic en el 3.º y aciértalo.
      await tester.tap(find.text(pEn(2)));
      await tester.pump();
      await expectSeleccion(tester, pEn(2));
      await tester.enterText(find.byType(TextField), esp(2));
      await tester.pump();
      // Salta al siguiente pendiente (4.º).
      await expectSeleccion(tester, pEn(3));

      // Anterior: el 3.º está acertado, así que va al 2.º.
      await tocar(tester, const Key('btn_anterior'));
      await expectSeleccion(tester, pEn(1));
      await tocar(tester, const Key('btn_anterior'));
      await expectSeleccion(tester, pEn(0));
      // Siguiente, Siguiente: 2.º y luego se salta el 3.º -> 4.º.
      await tocar(tester, const Key('btn_siguiente'));
      await tocar(tester, const Key('btn_siguiente'));
      await expectSeleccion(tester, pEn(3));
    });

    testWidgets('es circular y la cuadrícula hace scroll hasta el seleccionado',
        (tester) async {
      await abrir(tester);

      // Anterior desde el primero -> el último (200.º), que está muy abajo.
      await tocar(tester, const Key('btn_anterior'));
      await expectSeleccion(tester, pEn(199));

      // Siguiente desde el último -> el primero, y la lista vuelve arriba.
      await tocar(tester, const Key('btn_siguiente'));
      await expectSeleccion(tester, pEn(0));
    });

    testWidgets('Tab = siguiente y Shift+Tab = anterior, sin perder el foco',
        (tester) async {
      await abrir(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await expectSeleccion(tester, pEn(1));
      expect(campoTieneFoco(tester), isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await expectSeleccion(tester, pEn(2));
      expect(campoTieneFoco(tester), isTrue);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      await expectSeleccion(tester, pEn(1));
      expect(campoTieneFoco(tester), isTrue);

      // Y se puede escribir enseguida.
      await tester.enterText(find.byType(TextField), esp(1));
      await tester.pump();
      expect(find.textContaining('1/200'), findsOneWidget);
    });

    testWidgets('Tab vacía el campo al cambiar de elemento', (tester) async {
      await abrir(tester);
      await tester.enterText(find.byType(TextField), 'inter');
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(textoDelCampo(tester), '');
    });

    testWidgets('clic en una celda pendiente la selecciona y devuelve el foco',
        (tester) async {
      await abrir(tester);
      await tester.tap(find.text(pEn(3)));
      await tester.pump();
      await tester.pump();

      await expectSeleccion(tester, pEn(3));
      expect(campoTieneFoco(tester), isTrue);
      expect(textoDelCampo(tester), '');
    });

    testWidgets('clic en una celda ya acertada no la selecciona', (tester) async {
      await abrir(tester);
      await tester.enterText(find.byType(TextField), esp(0));
      await tester.pump();
      await expectSeleccion(tester, pEn(1));

      await tester.tap(find.text(pEn(0))); // ya acertada
      await tester.pump();
      await expectSeleccion(tester, pEn(1)); // sigue donde estaba
      expect(campoTieneFoco(tester), isTrue);
    });

    testWidgets('Me rindo quita el resaltado y desactiva la navegación',
        (tester) async {
      await abrir(tester);
      await tester.tap(find.text('Me rindo'));
      await tester.pump();

      expect(find.byKey(const Key('seleccion')), findsNothing);
      expect(
          tester.widget<OutlinedButton>(find.byKey(const Key('btn_siguiente'))).onPressed,
          isNull);
      expect(
          tester.widget<OutlinedButton>(find.byKey(const Key('btn_anterior'))).onPressed,
          isNull);
    });

    testWidgets('Reiniciar vuelve a seleccionar el elemento 1', (tester) async {
      await abrir(tester);
      await tester.enterText(find.byType(TextField), esp(0));
      await tester.pump();
      await tocar(tester, const Key('btn_siguiente'));
      await tocar(tester, const Key('btn_anterior')); // lejos del 1.º
      await tocar(tester, const Key('btn_anterior'));
      await tester.tap(find.text('Me rindo'));
      await tester.pump();

      await tester.tap(find.text('Reiniciar'));
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('0/200'), findsOneWidget);
      expect(campoActivo(tester), isTrue);
      expect(campoTieneFoco(tester), isTrue);
      expect(find.byKey(const Key('btn_siguiente')), findsOneWidget);
      await expectSeleccion(tester, pEn(0));

      // Y se puede jugar de nuevo desde el primero.
      await tester.enterText(find.byType(TextField), esp(0));
      await tester.pump();
      expect(find.textContaining('1/200'), findsOneWidget);
    });

    testWidgets('Reiniciar sin haber jugado también deja todo en el elemento 1',
        (tester) async {
      await abrir(tester);
      await tocar(tester, const Key('btn_siguiente'));
      await expectSeleccion(tester, pEn(1));
      await tester.tap(find.text('Reiniciar'));
      await tester.pump();
      await tester.pump();
      await expectSeleccion(tester, pEn(0));
    });

    testWidgets('cambiar entre Ordenado y Libre reinicia', (tester) async {
      await abrir(tester);
      await tester.enterText(find.byType(TextField), esp(0));
      await tester.pump();
      expect(find.textContaining('1/200'), findsOneWidget);

      await tocar(tester, const Key('orden_libre'));
      expect(find.textContaining('0/200'), findsOneWidget);
      expect(find.byKey(const Key('seleccion')), findsNothing);
      expect(find.byKey(const Key('btn_siguiente')), findsNothing);
      expect(campoTieneFoco(tester), isTrue);

      await tocar(tester, const Key('orden_ordenado'));
      expect(find.textContaining('0/200'), findsOneWidget);
      await expectSeleccion(tester, pEn(0));
      expect(campoTieneFoco(tester), isTrue);
    });

    testWidgets('cambiar de modo de idioma reinicia y selecciona el elemento 1',
        (tester) async {
      await abrir(tester);
      await tester.enterText(find.byType(TextField), esp(0));
      await tester.pump();
      await tocar(tester, const Key('modo_es_en'));

      expect(find.textContaining('0/200'), findsOneWidget);
      await expectSeleccion(tester, pEs(0));
    });
  });

  // ========================== MEZCLAR ORDEN ==========================

  group('mezclar orden', () {
    const semilla = 42;

    /// Los dos primeros órdenes que producirá un Random(semilla): el primero
    /// al activar el interruptor y el segundo al reiniciar.
    (List<int>, List<int>) ordenes() {
      final azar = Random(semilla);
      return (shuffledOrder(200, azar), shuffledOrder(200, azar));
    }

    /// Comprueba que los primeros elementos de la columna 1 son los de
    /// [orden], de arriba hacia abajo.
    void expectColumnaUno(WidgetTester tester, List<int> orden) {
      for (var p = 0; p < 6; p++) {
        final texto = find.text(pEn(orden[p]));
        expect(texto, findsOneWidget, reason: 'posición $p');
        if (p > 0) {
          final antes = tester.getTopLeft(find.text(pEn(orden[p - 1])));
          final ahora = tester.getTopLeft(texto);
          expect(ahora.dx, antes.dx, reason: 'misma columna');
          expect(ahora.dy, greaterThan(antes.dy), reason: 'debajo de la anterior');
        }
      }
    }

    testWidgets('la semilla de prueba da órdenes distintos entre sí y del original',
        (tester) async {
      final (o1, o2) = ordenes();
      expect(o1[0], isNot(0));
      expect(o2[0], isNot(0));
      expect(o1[0], isNot(o2[0]));
    });

    testWidgets('activar el interruptor reparte los elementos en orden aleatorio',
        (tester) async {
      final (o1, _) = ordenes();
      await abrir(tester, azar: Random(semilla));
      expect(find.text(pEn(0)), findsOneWidget); // orden original al inicio

      await tocar(tester, const Key('mezclar'));

      expectColumnaUno(tester, o1);
      expect(find.textContaining('0/200'), findsOneWidget);
      await expectSeleccion(tester, pEn(o1[0]));
      expect(campoTieneFoco(tester), isTrue);
    });

    testWidgets('Reiniciar genera un orden nuevo', (tester) async {
      final (o1, o2) = ordenes();
      await abrir(tester, azar: Random(semilla));
      await tocar(tester, const Key('mezclar'));
      expectColumnaUno(tester, o1);

      await tester.tap(find.text('Reiniciar'));
      await tester.pump();
      await tester.pump();

      expectColumnaUno(tester, o2);
      await expectSeleccion(tester, pEn(o2[0]));
      expect(campoTieneFoco(tester), isTrue);
    });

    testWidgets('Reiniciar después de rendirse también mezcla de nuevo',
        (tester) async {
      final (_, o2) = ordenes();
      await abrir(tester, azar: Random(semilla));
      await tocar(tester, const Key('mezclar'));
      await tester.tap(find.text('Me rindo'));
      await tester.pump();

      await tester.tap(find.text('Reiniciar'));
      await tester.pump();
      await tester.pump();

      expectColumnaUno(tester, o2);
      expect(campoActivo(tester), isTrue);
      expect(campoTieneFoco(tester), isTrue);
    });

    testWidgets('desactivar el interruptor vuelve al orden original',
        (tester) async {
      await abrir(tester, azar: Random(semilla));
      await tocar(tester, const Key('mezclar'));
      await tocar(tester, const Key('mezclar'));

      expectColumnaUno(tester, [for (var i = 0; i < 200; i++) i]);
      await expectSeleccion(tester, pEn(0));
    });

    testWidgets('ordenado: la selección y la navegación siguen el orden mezclado',
        (tester) async {
      final (o1, _) = ordenes();
      await abrir(tester, azar: Random(semilla));
      await tocar(tester, const Key('mezclar'));

      // La respuesta del elemento ORIGINAL 1 no vale (ya no es el seleccionado).
      await tester.enterText(find.byType(TextField), esp(0));
      await tester.pump();
      expect(find.textContaining('0/200'), findsOneWidget);

      // La del seleccionado sí, y la selección pasa a la siguiente POSICIÓN.
      await tester.enterText(find.byType(TextField), esp(o1[0]));
      await tester.pump();
      expect(find.textContaining('1/200'), findsOneWidget);
      await expectSeleccion(tester, pEn(o1[1]));

      await tocar(tester, const Key('btn_siguiente'));
      await expectSeleccion(tester, pEn(o1[2]));
      await tocar(tester, const Key('btn_anterior'));
      await expectSeleccion(tester, pEn(o1[1]));

      // Tab también sigue el orden mezclado.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await expectSeleccion(tester, pEn(o1[2]));
      expect(campoTieneFoco(tester), isTrue);
    });

    testWidgets('ordenado: la navegación circular usa la última posición mezclada',
        (tester) async {
      final (o1, _) = ordenes();
      await abrir(tester, azar: Random(semilla));
      await tocar(tester, const Key('mezclar'));

      await tocar(tester, const Key('btn_anterior')); // desde la posición 0
      await expectSeleccion(tester, pEn(o1[199]));
    });

    testWidgets('ordenado: se pueden completar los 200 en orden mezclado',
        (tester) async {
      final (o1, _) = ordenes();
      await abrir(tester, azar: Random(semilla));
      await tocar(tester, const Key('mezclar'));

      for (final i in o1) {
        await tester.enterText(find.byType(TextField), esp(i));
      }
      await tester.pumpAndSettle();

      expect(find.textContaining('200/200'), findsOneWidget);
      expect(find.textContaining('Felicidades'), findsOneWidget);
    });

    testWidgets('ES → EN ordenado con mezcla: se ve el español y se escribe el inglés',
        (tester) async {
      final (o1, _) = ordenes();
      await abrir(tester, azar: Random(semilla));
      await tocar(tester, const Key('modo_es_en'));
      await tocar(tester, const Key('mezclar'));

      await expectSeleccion(tester, pEs(o1[0]));

      await tester.enterText(find.byType(TextField), ing(o1[0]));
      await tester.pump();
      expect(find.textContaining('1/200'), findsOneWidget);
      await expectSeleccion(tester, pEs(o1[1]));
    });

    testWidgets('libre con mezcla: cualquier elemento se acepta y no hay resaltado',
        (tester) async {
      final (o1, _) = ordenes();
      await abrir(tester, libre: true, azar: Random(semilla));
      await tocar(tester, const Key('mezclar'));

      expectColumnaUno(tester, o1);
      expect(find.byKey(const Key('seleccion')), findsNothing);

      await tester.enterText(find.byType(TextField), 'interprete');
      await tester.pump();
      expect(find.textContaining('1/200'), findsOneWidget);
      expect(find.text('✔ Interpreter = Intérprete'), findsOneWidget);
      expect(campoTieneFoco(tester), isTrue);
    });

    testWidgets('libre con mezcla: Reiniciar da un orden nuevo y Me rindo funciona',
        (tester) async {
      final (_, o2) = ordenes();
      await abrir(tester, libre: true, azar: Random(semilla));
      await tocar(tester, const Key('mezclar'));
      await tester.tap(find.text('Reiniciar'));
      await tester.pump();
      await tester.pump();
      expectColumnaUno(tester, o2);

      await tester.tap(find.text('Me rindo'));
      await tester.pump();
      expect(campoActivo(tester), isFalse);
      final roja = tester.widget<Text>(find.text(esp(o2[0])));
      expect(roja.style!.color, Colors.red.shade800);
    });

    testWidgets('ES → EN libre con mezcla: se acepta cualquier elemento', (tester) async {
      final (o1, _) = ordenes();
      await abrir(tester, libre: true, azar: Random(semilla));
      await tocar(tester, const Key('modo_es_en'));
      await tocar(tester, const Key('mezclar'));

      await tester.enterText(find.byType(TextField), 'interpreter');
      await tester.pump();
      expect(find.textContaining('1/200'), findsOneWidget);
      expect(find.text('✔ Intérprete = Interpreter'), findsOneWidget);
      expect(find.text(pEs(o1[0])), findsOneWidget);
    });

    testWidgets('cambiar entre Ordenado y Libre conserva el interruptor activado',
        (tester) async {
      final (o1, _) = ordenes();
      await abrir(tester, azar: Random(semilla));
      await tocar(tester, const Key('mezclar'));
      expectColumnaUno(tester, o1);

      await tocar(tester, const Key('orden_libre'));
      // Sigue mezclado (con un orden nuevo, porque cambiar de modo reinicia).
      expect(tester.widget<FilterChip>(find.byKey(const Key('mezclar'))).selected,
          isTrue);
      expect(find.textContaining('0/200'), findsOneWidget);
    });
  });

  // ============================== LISTAS ==============================

  group('selector de lista', () {
    testWidgets('el título es "Interpreting Quiz" y hay dos listas', (tester) async {
      await abrir(tester);
      expect(find.text('Interpreting Quiz'), findsOneWidget);
      expect(find.text('Vocab Quiz'), findsNothing);
      expect(find.text('Deutsch Quiz'), findsNothing);
      expect(find.text('Alemán'), findsNothing);
      expect(find.text('Glosario de entrenamiento'), findsOneWidget);
      expect(find.text('Médico ampliado'), findsOneWidget);
    });

    testWidgets('arranca en el glosario con las direcciones EN→ES y ES→EN',
        (tester) async {
      await abrir(tester);
      expect(find.byKey(const Key('modo_en_es')), findsOneWidget);
      expect(find.byKey(const Key('modo_es_en')), findsOneWidget);
      expect(find.byKey(const Key('lista_aleman')), findsNothing);
      expect(find.text('Interpreter'), findsOneWidget);
      await expectSeleccion(tester, pEn(0));
    });

    testWidgets('elegir el médico ampliado reinicia y empieza en EN→ES',
        (tester) async {
      await abrir(tester);
      await tester.enterText(find.byType(TextField), esp(0));
      await tester.pump();
      expect(find.textContaining('1/200'), findsOneWidget);

      await tocar(tester, const Key('lista_medico'));

      expect(find.byKey(const Key('modo_en_es')), findsOneWidget);
      expect(find.byKey(const Key('modo_es_en')), findsOneWidget);
      expect(find.textContaining('0/200'), findsOneWidget);
      expect(campoTieneFoco(tester), isTrue);
      await expectSeleccion(tester, promptFor(medico[0], QuizMode.enToEs));
      expect(find.text('Interpreter'), findsNothing);
    });

    testWidgets('el glosario ordenado acepta tildes opcionales y salta al siguiente',
        (tester) async {
      await abrir(tester);

      await tester.enterText(find.byType(TextField), 'interprete'); // sin tilde
      await tester.pump();

      expect(find.textContaining('1/200'), findsOneWidget);
      expect(find.text('Intérprete'), findsOneWidget); // celda verde oficial
      expect(find.text('✔ Interpreter = Intérprete'), findsOneWidget);
      expect(textoDelCampo(tester), '');
      expect(campoTieneFoco(tester), isTrue);
      await expectSeleccion(tester, pEn(1));
    });

    testWidgets('solo acepta el término seleccionado (glosario)', (tester) async {
      await abrir(tester);

      // "Intérprete" es del primero; el segundo se llama "Interpretación consecutiva".
      await tester.enterText(find.byType(TextField), 'interpretacion consecutiva');
      await tester.pump();
      expect(find.textContaining('0/200'), findsOneWidget);
      await expectSeleccion(tester, pEn(0));
    });

    testWidgets('ES→EN: se ve el español y se escribe el inglés', (tester) async {
      await abrir(tester);
      await tocar(tester, const Key('modo_es_en'));

      await expectSeleccion(tester, 'Intérprete');
      expect(find.text('Interpreter'), findsNothing);

      await tester.enterText(find.byType(TextField), 'INTERPRETER');
      await tester.pump();
      expect(find.textContaining('1/200'), findsOneWidget);
      expect(find.text('✔ Intérprete = Interpreter'), findsOneWidget);
      await expectSeleccion(tester, pEs(1));
    });

    testWidgets('libre: una variante se acepta y se muestra la forma oficial',
        (tester) async {
      await abrir(tester);
      await tocar(tester, const Key('orden_libre'));
      expect(find.byKey(const Key('seleccion')), findsNothing);

      // "Clarify" = "Aclarar" / "aclaración" (variante).
      await tester.enterText(find.byType(TextField), 'aclaracion');
      await tester.pump();

      expect(find.textContaining('1/200'), findsOneWidget);
      expect(find.text('Aclarar'), findsOneWidget);
      expect(find.text('✔ Clarify = Aclarar'), findsOneWidget);
      expect(campoTieneFoco(tester), isTrue);
    });

    testWidgets('Siguiente y Anterior funcionan en el glosario', (tester) async {
      await abrir(tester);

      await tocar(tester, const Key('btn_siguiente'));
      await expectSeleccion(tester, pEn(1));
      await tocar(tester, const Key('btn_anterior'));
      await tocar(tester, const Key('btn_anterior')); // circular: el último
      await expectSeleccion(tester, pEn(199));
    });

    testWidgets('Me rindo muestra en rojo la forma oficial (médico ampliado)',
        (tester) async {
      await abrir(tester);
      await tocar(tester, const Key('lista_medico'));
      await tester.tap(find.text('Me rindo'));
      await tester.pump();

      expect(campoActivo(tester), isFalse);
      final oficial = revealAnswer(medico[0], QuizMode.enToEs);
      final roja = tester.widget<Text>(find.text(oficial));
      expect(roja.style!.color, Colors.red.shade800);
    });

    testWidgets('Reiniciar después de rendirse en el médico ampliado',
        (tester) async {
      await abrir(tester);
      await tocar(tester, const Key('lista_medico'));
      await tester.tap(find.text('Me rindo'));
      await tester.pump();
      await tester.tap(find.text('Reiniciar'));
      await tester.pump();
      await tester.pump();

      expect(campoActivo(tester), isTrue);
      expect(campoTieneFoco(tester), isTrue);
      expect(find.textContaining('0/200'), findsOneWidget);
      await expectSeleccion(tester, promptFor(medico[0], QuizMode.enToEs));
    });

    testWidgets('completar los 200 del médico ampliado muestra la felicitación',
        (tester) async {
      await abrir(tester);
      await tocar(tester, const Key('lista_medico'));
      for (final item in medico) {
        await tester.enterText(
            find.byType(TextField), item.answersIn(Language.spanish).first);
      }
      await tester.pumpAndSettle();

      expect(find.textContaining('200/200'), findsOneWidget);
      expect(find.textContaining('Felicidades'), findsOneWidget);
      expect(campoActivo(tester), isFalse);
    });

    testWidgets('cambiar de lista y volver al glosario restaura todo', (tester) async {
      await abrir(tester);
      await tocar(tester, const Key('lista_medico'));
      await tocar(tester, const Key('lista_glosario'));

      expect(find.byKey(const Key('modo_en_es')), findsOneWidget);
      expect(find.textContaining('0/200'), findsOneWidget);
      expect(campoTieneFoco(tester), isTrue);
      await expectSeleccion(tester, pEn(0));

      await tester.enterText(find.byType(TextField), esp(0));
      await tester.pump();
      expect(find.textContaining('1/200'), findsOneWidget);
    });

    testWidgets('al cambiar de lista se conservan Libre y Mezclar',
        (tester) async {
      await abrir(tester, azar: Random(42));
      await tocar(tester, const Key('orden_libre'));
      await tocar(tester, const Key('mezclar'));

      await tocar(tester, const Key('lista_medico'));

      expect(tester.widget<FilterChip>(find.byKey(const Key('mezclar'))).selected,
          isTrue);
      expect(find.byKey(const Key('btn_siguiente')), findsNothing); // sigue Libre
      expect(find.byKey(const Key('seleccion')), findsNothing);
    });

    testWidgets('mezclar funciona en el médico ampliado (ordenado)', (tester) async {
      final azar = Random(42);
      final o1 = shuffledOrder(200, azar);
      await abrir(tester, azar: Random(42));
      await tocar(tester, const Key('lista_medico'));
      await tocar(tester, const Key('mezclar'));

      await expectSeleccion(tester, promptFor(medico[o1[0]], QuizMode.enToEs));
      await tester.enterText(find.byType(TextField),
          medico[o1[0]].answersIn(Language.spanish).first);
      await tester.pump();
      expect(find.textContaining('1/200'), findsOneWidget);
      await expectSeleccion(tester, promptFor(medico[o1[1]], QuizMode.enToEs));
    });
  });

  // ============================ CUADRÍCULA ============================

  testWidgets('la cuadrícula se ordena por columnas (1–100 | 101–200)',
      (tester) async {
    await abrir(tester); // 1400 px de ancho: 2 columnas en las listas bilingües

    final p0 = tester.getTopLeft(find.text(pEn(0)));
    final p1 = tester.getTopLeft(find.text(pEn(1)));
    final p100 = tester.getTopLeft(find.text(pEn(100)));

    expect(p1.dx, p0.dx);
    expect(p1.dy, greaterThan(p0.dy));
    expect(p100.dy, p0.dy);
    expect(p100.dx, greaterThan(p0.dx));
  });
}
