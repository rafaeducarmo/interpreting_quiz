// Pantalla principal del quiz.
// Aquí solo hay interfaz y estado; las reglas de comparación y la navegación
// viven en quiz_logic.dart.

import 'dart:math';

// services.dart trae los tipos del teclado (LogicalKeyboardKey, KeyEvent...).
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'quiz_logic.dart';
import 'word_lists.dart';

/// StatefulWidget: una pantalla que CAMBIA mientras juegas (palabras
/// acertadas, mensajes...). Flutter separa el widget (inmutable) de su
/// estado (la clase _QuizScreenState), que es donde guardamos lo que cambia.
class QuizScreen extends StatefulWidget {
  /// [random] es opcional: sirve para que los tests usen un orden conocido
  /// (con una semilla). Normalmente es null y se usa un Random real.
  const QuizScreen({super.key, this.random});

  final Random? random;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  // Controlador: nos deja leer y borrar el texto del campo desde el código.
  final TextEditingController _controller = TextEditingController();

  // FocusNode: representa el "foco" del teclado. Con él podemos pedir que
  // el cursor vuelva al campo después de acertar. Se crea UNA vez aquí y se
  // libera en dispose(); si se creara dentro de build() se perdería el foco
  // en cada actualización de la pantalla (típico bug de "no puedo escribir").
  final FocusNode _focus = FocusNode();

  // Controlador del scroll de la cuadrícula: lo usamos para desplazarla
  // sola hasta la palabra seleccionada.
  final ScrollController _scroll = ScrollController();

  /// Alto de cada fila de la cuadrícula (celda + 2 de margen arriba y abajo).
  /// Depende de la lista elegida, pero dentro de una lista es FIJO, y por eso
  /// podemos calcular dónde está cada fila.
  double get _altoFila => _catalogo.altoFila;

  /// Margen interior de la lista (arriba y abajo).
  static const double _margenLista = 8;

  // ---- TODO EL ESTADO DEL JUEGO está en estas variables. ----
  // _reiniciar() las restaura todas; por eso reiniciar funciona siempre.

  /// La lista elegida (Glosario de entrenamiento o Médico ampliado).
  WordList _catalogo = wordLists.first;

  /// Dirección de juego actual: qué idioma se ve y cuál se escribe.
  /// Siempre es una de las dos direcciones de [_catalogo].
  QuizMode _modo = wordLists.first.forward;

  /// true = modo ORDENADO (hay una palabra seleccionada y solo se acepta
  /// esa). false = modo LIBRE (se acepta cualquier palabra pendiente).
  bool _ordenado = true;

  /// true = el interruptor "Mezclar orden" está activado.
  bool _mezclar = false;

  /// Los elementos en el orden en que se muestran en la cuadrícula.
  /// Normalmente son los de la lista elegida tal cual; con "Mezclar orden" es
  /// una copia en orden aleatorio. A PARTIR DE AQUÍ, todo índice (selección,
  /// acertadas) es una POSICIÓN en esta lista, no en la lista original.
  List<QuizItem> _lista = wordLists.first.items;

  /// Cuántos elementos tiene la lista elegida (siempre 200 por ahora).
  int get _total => _catalogo.items.length;

  /// Generador de números aleatorios (el de los tests o uno real).
  late final Random _random = widget.random ?? Random();

  /// Posición de la palabra seleccionada (solo se usa en modo ordenado).
  /// null cuando no hay ninguna: modo libre, o ya están todas acertadas.
  int? _seleccion = 0;

  /// Palabras acertadas: posición en `_lista` -> texto que se muestra en la celda.
  final Map<int, String> _acertadas = {};

  /// true después de presionar "Me rindo".
  bool _rendido = false;

  /// Mensaje bajo el campo y si es un aviso de error (para pintarlo distinto).
  String _mensaje = '';
  bool _mensajeEsError = false;

  /// ¿Completó todos? Se calcula a partir de las acertadas, no se guarda
  /// aparte, así nunca se puede desincronizar.
  bool get _ganado => _acertadas.length == _total;

  /// El campo solo se puede usar mientras el juego sigue en marcha.
  bool get _campoActivo => !_rendido && !_ganado;

  @override
  void initState() {
    super.initState();
    // Interceptamos Tab y Shift+Tab ANTES de que el navegador los use para
    // mover el foco a otro elemento de la página.
    _focus.onKeyEvent = _alTecla;
  }

  @override
  void dispose() {
    // Siempre liberar los objetos que lo necesitan.
    _controller.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Devuelve el foco al campo. Se hace "después del frame" porque justo
  /// después de setState() la pantalla aún se está reconstruyendo: si el
  /// campo estaba desactivado (tras rendirse), todavía no se ha reactivado
  /// y pedir el foco en ese momento no tendría efecto.
  void _devolverFoco() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  /// Teclas especiales del campo: Tab = siguiente, Shift+Tab = anterior.
  /// Devolver "handled" significa "ya me ocupé yo": así el foco NO se va.
  KeyEventResult _alTecla(FocusNode nodo, KeyEvent evento) {
    if (evento.logicalKey != LogicalKeyboardKey.tab) {
      return KeyEventResult.ignored;
    }
    // Solo actuamos al bajar la tecla (o al repetirse si se mantiene).
    if (evento is! KeyUpEvent && _ordenado && _campoActivo) {
      _mover(adelante: !HardwareKeyboard.instance.isShiftPressed);
    }
    // En modo libre, Tab no hace nada, pero tampoco debe sacar el foco.
    return KeyEventResult.handled;
  }

  // -------------------------------------------------------------------------
  // Selección (modo ordenado)
  // -------------------------------------------------------------------------

  /// Mueve la selección a la siguiente o anterior palabra pendiente.
  void _mover({required bool adelante}) {
    final actual = _seleccion;
    if (actual == null) return;
    final pendientes = _acertadas.keys.toSet();
    _seleccionar(adelante
        ? nextPending(actual, pendientes, _total)
        : previousPending(actual, pendientes, _total));
  }

  /// Selecciona una palabra: vacía el campo, devuelve el foco y desplaza la
  /// cuadrícula para que se vea.
  void _seleccionar(int? indice) {
    setState(() {
      _seleccion = indice;
      if (_mensajeEsError) {
        _mensaje = '';
        _mensajeEsError = false;
      }
    });
    _controller.clear();
    _devolverFoco();
    _mostrarSeleccion();
  }

  /// Número de columnas según el ancho (misma regla que usa la cuadrícula).
  /// Cada lista tiene sus propios cortes (las frases largas necesitan más ancho).
  int _columnasPara(double ancho) => _catalogo.columnasPara(ancho);

  /// Desplaza la lista SOLO si la fila seleccionada no está a la vista.
  /// No usamos Scrollable.ensureVisible porque ListView.builder no crea las
  /// filas que no se ven; en cambio, como todas miden lo mismo, la posición
  /// de cada una se calcula con una multiplicación.
  void _mostrarSeleccion() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final sel = _seleccion;
      if (!mounted || sel == null || !_scroll.hasClients) return;

      final columnas = _columnasPara(MediaQuery.sizeOf(context).width);
      final fila = sel % gridRows(_total, columnas);
      final arriba = _margenLista + fila * _altoFila;
      final abajo = arriba + _altoFila;
      final pos = _scroll.position;

      double? destino;
      if (arriba < pos.pixels + _margenLista) {
        destino = arriba - _margenLista; // está por encima: subir
      } else if (abajo > pos.pixels + pos.viewportDimension - _margenLista) {
        destino = abajo + _margenLista - pos.viewportDimension; // por debajo
      }
      if (destino != null) {
        _scroll.animateTo(
          destino.clamp(0.0, pos.maxScrollExtent),
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
        );
      } else {
        // Ya se ve: no hay que mover nada. Pero una animación anterior (p. ej.
        // al pulsar Tab muy rápido) podría seguir en marcha y alejar la lista
        // de la selección; jumpTo a la posición actual la cancela.
        _scroll.jumpTo(pos.pixels);
      }
    });
  }

  /// Clic en una celda de la cuadrícula.
  void _clicEnCelda(int indice) {
    if (_ordenado && _campoActivo && !_acertadas.containsKey(indice)) {
      _seleccionar(indice);
    } else {
      _devolverFoco(); // en cualquier otro caso, solo mantener el foco
    }
  }

  // -------------------------------------------------------------------------
  // Responder
  // -------------------------------------------------------------------------

  /// Busca la coincidencia según el modo: en ordenado solo cuenta la palabra
  /// seleccionada; en libre, cualquier pendiente.
  MatchResult? _buscar(String texto, {required bool enviado}) {
    if (_ordenado) {
      final sel = _seleccion;
      if (sel == null) return null;
      return matchSelected(texto, _lista[sel], sel, _modo);
    }
    return findMatch(texto, _lista, _acertadas.keys.toSet(), _modo,
        enviado: enviado);
  }

  /// Marca una palabra como acertada y prepara el campo para la siguiente.
  void _marcar(MatchResult r) {
    setState(() {
      _acertadas[r.index] = r.answer;
      // En modo ordenado la selección salta sola a la siguiente PENDIENTE
      // (null si ya no queda ninguna: ganaste).
      if (_ordenado) {
        _seleccion = nextPending(r.index, _acertadas.keys.toSet(), _total);
      }
      _mensaje = _ganado
          ? '🎉 ¡Felicidades! Completaste los $_total términos'
          : '✔ ${promptFor(_lista[r.index], _modo)} = ${r.answer}';
      _mensajeEsError = false;
    });
    _controller.clear(); // vaciar el campo (no dispara onChanged)
    _devolverFoco(); // y que el cursor siga ahí
    if (_ordenado) _mostrarSeleccion();
  }

  /// Se llama en cada tecla. Marca sola la palabra si coincide sin ambigüedad.
  void _alCambiar(String texto) {
    final r = _buscar(texto, enviado: false);
    if (r != null) {
      _marcar(r);
    } else if (_mensajeEsError) {
      // Al seguir escribiendo, desaparece el aviso de "no coincide".
      setState(() {
        _mensaje = '';
        _mensajeEsError = false;
      });
    }
  }

  /// Se llama al presionar Enter: en modo libre aquí sí se aceptan los casos
  /// ambiguos; en ambos modos, si no coincide, se muestra un aviso.
  void _alEnviar(String texto) {
    if (texto.trim().isEmpty) {
      _devolverFoco();
      return;
    }
    final r = _buscar(texto, enviado: true);
    if (r != null) {
      _marcar(r);
    } else {
      // No se vacía el campo: así el jugador puede corregir lo que escribió.
      setState(() {
        _mensaje = _ordenado
            ? 'No coincide con la palabra seleccionada'
            : 'No coincide con ninguna palabra pendiente';
        _mensajeEsError = true;
      });
      _devolverFoco();
    }
  }

  // -------------------------------------------------------------------------
  // Botones y modos
  // -------------------------------------------------------------------------

  /// "Me rindo": desactiva el campo y deja ver las respuestas que faltan.
  /// No borra nada: las acertadas se quedan como están.
  void _rendirse() {
    if (_rendido || _ganado) return;
    final faltan = _total - _acertadas.length;
    setState(() {
      _rendido = true;
      _mensaje = 'Te rendiste: faltaron $faltan términos';
      _mensajeEsError = false;
    });
  }

  /// "Reiniciar": vuelve TODO al estado inicial. No lee ningún estado
  /// anterior para decidir qué hacer, así que funciona igual antes de
  /// jugar, a mitad de partida, después de rendirse o después de ganar.
  void _reiniciar() {
    setState(() {
      _acertadas.clear();
      _rendido = false;
      _mensaje = '';
      _mensajeEsError = false;
      _seleccion = _ordenado ? 0 : null; // vuelve a la palabra 1
      // Orden nuevo en CADA reinicio: mezclado si el interruptor está
      // activado, o el original si no.
      _lista = orderedWords(_catalogo.items, _mezclar ? _random : null);
    });
    _controller.clear();
    _devolverFoco(); // el campo ya estará activo cuando se pida el foco
    if (_ordenado) _mostrarSeleccion(); // sube la cuadrícula al principio
  }

  /// Cambiar de dirección (p. ej. EN → ES a ES → EN) = poner la nueva y reiniciar.
  void _cambiarModo(QuizMode nuevo) {
    if (nuevo == _modo) return;
    setState(() => _modo = nuevo);
    _reiniciar();
  }

  /// Cambiar de lista = poner la lista nueva con su dirección "de ida" y
  /// reiniciar. Se conservan las opciones Ordenado/Libre y Mezclar orden.
  void _cambiarLista(WordList nueva) {
    if (identical(nueva, _catalogo)) return;
    setState(() {
      _catalogo = nueva;
      _modo = nueva.forward; // la dirección de la lista anterior ya no existe
    });
    _reiniciar();
  }

  /// Cambiar entre Ordenado y Libre = cambiar la opción y reiniciar.
  void _cambiarOrden(bool ordenado) {
    if (ordenado == _ordenado) return;
    setState(() => _ordenado = ordenado);
    _reiniciar();
  }

  /// Activar o desactivar "Mezclar orden" = cambiar la opción y reiniciar
  /// (el reinicio es lo que genera el orden nuevo).
  void _cambiarMezcla(bool mezclar) {
    setState(() => _mezclar = mezclar);
    _reiniciar();
  }

  // -------------------------------------------------------------------------
  // Interfaz
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _barraSuperior(context), // fija: está fuera del scroll
          Expanded(child: _cuadricula()), // ocupa el resto y hace scroll
        ],
      ),
    );
  }

  Widget _barraSuperior(BuildContext context) {
    final total = _total;
    final aciertos = _acertadas.length;
    final porcentaje = (aciertos * 100 / total).toStringAsFixed(0);
    final tema = Theme.of(context);

    // El texto de ayuda nombra el idioma que se escribe en la dirección actual.
    final idioma = _modo.to.nombre;
    final String pista = _ordenado
        ? 'Escribe en $idioma la traducción del término resaltado…'
        : 'Escribe la traducción en $idioma…';

    // Selector de lista: una ficha por lista del catálogo.
    final selectorLista = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final lista in wordLists)
          ChoiceChip(
            key: Key('lista_${lista.id}'),
            label: Text(lista.nombre),
            selected: identical(lista, _catalogo),
            showCheckmark: false,
            onSelected: (_) => _cambiarLista(lista),
          ),
      ],
    );

    final campo = TextField(
      controller: _controller,
      focusNode: _focus,
      enabled: _campoActivo, // se desactiva al rendirse o al ganar
      autofocus: true, // el cursor ya está en el campo al abrir
      autocorrect: false,
      enableSuggestions: false,
      onChanged: _alCambiar,
      onSubmitted: _alEnviar,
      // Si onEditingComplete es null, Flutter QUITA el foco al presionar
      // Enter. Con una función vacía no lo quita.
      onEditingComplete: () {},
      // Hacer clic fuera del campo (p. ej. en la cuadrícula) no debe
      // quitarle el foco.
      onTapOutside: (_) {},
      decoration: InputDecoration(
        hintText: pista,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );

    // Selectores, navegación y botones. Un Wrap pasa a una segunda línea
    // solo si no caben todos en el ancho disponible.
    final controles = Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Las dos direcciones de la lista elegida (EN→ES y
        // ES→EN): los idiomas salen del propio QuizMode.
        for (final modo in _catalogo.modos)
          _chip(modo.from.code, modo.to.code, Key('modo_${modo.id}'),
              _modo == modo, () => _cambiarModo(modo)),
        const SizedBox(width: 4),
        ChoiceChip(
          key: const Key('orden_ordenado'),
          label: const Text('Ordenado'),
          selected: _ordenado,
          showCheckmark: false,
          onSelected: (_) => _cambiarOrden(true),
        ),
        ChoiceChip(
          key: const Key('orden_libre'),
          label: const Text('Libre'),
          selected: !_ordenado,
          showCheckmark: false,
          onSelected: (_) => _cambiarOrden(false),
        ),
        // Interruptor: con el chip marcado, cada reinicio mezcla de nuevo.
        FilterChip(
          key: const Key('mezclar'),
          label: const Text('Mezclar orden'),
          selected: _mezclar,
          showCheckmark: false,
          avatar: Icon(_mezclar ? Icons.shuffle_on : Icons.shuffle, size: 18),
          onSelected: _cambiarMezcla,
        ),
        if (_ordenado) ...[
          const SizedBox(width: 4),
          // Las flechas son Icon (no caracteres ← →): ver _chip.
          OutlinedButton(
            key: const Key('btn_anterior'),
            onPressed: _campoActivo ? () => _mover(adelante: false) : null,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.arrow_back, size: 18),
                SizedBox(width: 4),
                Text('Anterior'),
              ],
            ),
          ),
          OutlinedButton(
            key: const Key('btn_siguiente'),
            onPressed: _campoActivo ? () => _mover(adelante: true) : null,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Siguiente'),
                SizedBox(width: 4),
                Icon(Icons.arrow_forward, size: 18),
              ],
            ),
          ),
        ],
        const SizedBox(width: 4),
        FilledButton(
          onPressed: _campoActivo ? _rendirse : null, // null = desactivado
          child: const Text('Me rindo'),
        ),
        OutlinedButton(
          onPressed: _reiniciar, // SIEMPRE activo
          child: const Text('Reiniciar'),
        ),
      ],
    );

    return Material(
      elevation: 4,
      color: tema.colorScheme.surface,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Fila 1: título y contador.
              Row(
                children: [
                  Text('Interpreting Quiz', style: tema.textTheme.titleLarge),
                  const Spacer(),
                  Text(
                    '$aciertos/$total  ($porcentaje%)',
                    style: tema.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              selectorLista, // Fila 2: qué lista practicar
              const SizedBox(height: 8),
              campo, // el único campo de texto
              const SizedBox(height: 8),
              // Dirección, Ordenado/Libre, mezcla, navegación y botones.
              const SizedBox(height: 8),
              controles,
              const SizedBox(height: 6),
              // Mensaje (último acierto, aviso o victoria). Altura fija para
              // que la barra no "salte" al aparecer o desaparecer.
              SizedBox(
                height: 20,
                child: Text(
                  _mensaje,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _mensajeEsError
                        ? Colors.red.shade700
                        : Colors.green.shade800,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Opción del selector de idioma: un ChoiceChip que mide su propio contenido.
  /// La flecha es un Icon (un dibujo), no el carácter "→" dentro de un Text:
  /// ese carácter no está en la fuente por defecto del navegador y Chrome lo
  /// dibuja con otra fuente de otro ancho, lo que recortaba la última letra.
  Widget _chip(String origen, String destino, Key llave, bool seleccionado,
      VoidCallback alElegir) {
    return ChoiceChip(
      key: llave,
      selected: seleccionado,
      showCheckmark: false,
      onSelected: (_) => alElegir(),
      label: Row(
        mainAxisSize: MainAxisSize.min, // el chip se ajusta a su contenido
        children: [
          Text(origen),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Icon(Icons.arrow_forward, size: 16),
          ),
          Text(destino),
        ],
      ),
    );
  }

  Widget _cuadricula() {
    // LayoutBuilder nos dice cuánto espacio hay, para elegir las columnas.
    return LayoutBuilder(
      builder: (context, constraints) {
        final columnas = _columnasPara(constraints.maxWidth);
        final filas = gridRows(_total, columnas);

        // ListView.builder solo construye las filas visibles (rápido).
        // Cada fila es un Row con una celda por columna; el índice de la
        // palabra sale de gridIndex para ordenar POR COLUMNAS.
        // itemExtent fija el alto de todas las filas (necesario para poder
        // calcular el scroll hacia la palabra seleccionada).
        return ListView.builder(
          controller: _scroll,
          padding: const EdgeInsets.all(_margenLista),
          itemExtent: _altoFila,
          itemCount: filas,
          itemBuilder: (context, fila) {
            return Row(
              children: [
                for (var c = 0; c < columnas; c++)
                  Expanded(
                    child: _fila(gridIndex(
                      fila: fila,
                      columna: c,
                      columnas: columnas,
                      total: _total,
                    )),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  /// Un par de celdas: pregunta (oscura) | respuesta (amarilla, verde o roja).
  Widget _fila(int? indice) {
    if (indice == null) return SizedBox(height: _altoFila); // celda vacía
    final acertada = _acertadas.containsKey(indice);
    final seleccionada = _ordenado && _campoActivo && _seleccion == indice;
    final clicable = _ordenado && _campoActivo && !acertada;

    // Qué se escribe en la celda de respuesta y de qué color.
    final String textoRespuesta;
    final Color fondo;
    final Color colorTexto;
    if (acertada) {
      textoRespuesta = _acertadas[indice]!; // verde
      fondo = Colors.green.shade400;
      colorTexto = Colors.black;
    } else if (_rendido) {
      textoRespuesta = revealAnswer(_lista[indice], _modo); // roja
      fondo = Colors.yellow.shade300;
      colorTexto = Colors.red.shade800;
    } else {
      textoRespuesta = ''; // pendiente
      fondo = Colors.yellow.shade300;
      colorTexto = Colors.black;
    }

    final par = Container(
      // Solo la fila seleccionada lleva esta llave (la usan los tests).
      key: seleccionada ? const Key('seleccion') : null,
      // foregroundDecoration se dibuja ENCIMA: así el borde grueso resalta
      // la fila entera sin cambiar su tamaño.
      foregroundDecoration: seleccionada
          ? BoxDecoration(
              border: Border.all(color: Colors.deepOrange, width: 3),
              borderRadius: BorderRadius.circular(5),
            )
          : null,
      child: Row(
        children: [
          Expanded(
            child: _celda(
              promptFor(_lista[indice], _modo),
              fondo: seleccionada
                  ? Colors.indigo.shade500
                  : Colors.blueGrey.shade800,
              colorTexto: Colors.white,
              negrita: seleccionada,
            ),
          ),
          const SizedBox(width: 2),
          Expanded(
            child: _celda(
              textoRespuesta,
              fondo: fondo,
              colorTexto: colorTexto,
              negrita: !acertada && _rendido,
            ),
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.all(2),
      child: MouseRegion(
        cursor: clicable ? SystemMouseCursors.click : MouseCursor.defer,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _clicEnCelda(indice),
          child: par,
        ),
      ),
    );
  }

  /// Una celda de color con texto. Los términos pueden ser frases largas
  /// ("Limited English proficiency"), así que se permiten 2 líneas y solo se
  /// recorta con "…" si ni así caben.
  Widget _celda(String contenido,
      {required Color fondo, required Color colorTexto, bool negrita = false}) {
    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        contenido,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: colorTexto,
          fontSize: 13,
          height: 1.15,
          fontWeight: negrita ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}
