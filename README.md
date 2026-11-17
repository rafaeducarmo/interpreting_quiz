# Interpreting Quiz

App web en Flutter para practicar vocabulario al estilo de los quizzes de
Sporcle: escribes las respuestas en un solo campo de texto y cada término se
marca solo al acertarlo, sin temporizador.

## Probarla en línea

**https://rafaeducarmo.github.io/interpreting_quiz/**

Se publica sola en GitHub Pages en cada push a `main` (ver
`.github/workflows/deploy.yml`).

## Listas

Se elige arriba, con las fichas de lista. Cambiar de lista reinicia.

| Lista                         | Idiomas      | Contenido                                        |
| ----------------------------- | ------------ | ------------------------------------------------ |
| **Glosario de entrenamiento** | EN ↔ ES      | 200 términos del glosario oficial de entrenamiento (interpretación, medicina, emergencias...) |
| **Médico ampliado**           | EN ↔ ES      | 200 términos médicos de complemento              |

En cada lista hay dos direcciones (EN → ES y ES → EN): lo que ves y lo que escribes se intercambian.

## Cómo se juega

- **Ordenado / Libre:** en *Ordenado* (por defecto) siempre hay un término
  resaltado y el campo solo acepta su respuesta; al acertar, la selección salta
  a la siguiente pendiente. Se navega con los botones Anterior / Siguiente,
  con Tab / Shift+Tab o haciendo clic en una celda. En *Libre* se puede
  escribir cualquier término pendiente.
- **Mezclar orden:** reparte los 200 términos en orden aleatorio en la
  cuadrícula (y en la navegación del modo ordenado). Se genera un orden nuevo
  cada vez que activas el interruptor o reinicias.
- **Botones:** "Me rindo" muestra en rojo lo que falta; "Reiniciar" empieza de cero.
- **Contador:** `X/200` y porcentaje, siempre visibles.

## Reglas para comparar respuestas

Se ignoran mayúsculas, signos de puntuación y espacios extra; un guion vale
como un espacio ("self-correction" = "self correction").

- **Inglés:** se ignora "to", "a", "an" y "the" al inicio.
- **Español:** las tildes son opcionales (á = a, é = e...), ñ = n, se ignoran
  ¿ ? ¡ ! y los artículos el, la, los, las, un, una son opcionales.
- En las listas bilingües, cada término tiene una forma oficial (la primera) y
  variantes que también se aceptan. La pregunta y las respuestas reveladas
  muestran la forma oficial, y al acertar con una variante la celda verde
  muestra también la oficial.
- En modo *Libre*, si lo que escribes es el inicio de otra respuesta pendiente
  (p. ej. "be" y "become"), se marca al presionar Enter.

## Cómo correrla

```
cd C:\Users\rafae\proyectos\interpreting_quiz
flutter run -d chrome
```

## Tests

```
flutter analyze
flutter test
```

## Estructura

| Archivo                     | Qué hace                                                |
| --------------------------- | ------------------------------------------------------- |
| `lib/bilingual_terms.dart`  | Datos: `BilingualTerm`, `trainingGlossary` y `medicalTerms` |
| `lib/quiz_model.dart`       | Modelo común: `Language`, `QuizMode` y `QuizItem`       |
| `lib/word_lists.dart`       | Las 2 listas y el adaptador `BilingualTerm` → `QuizItem` |
| `lib/quiz_logic.dart`       | Normalización, coincidencias, navegación y orden aleatorio (Dart puro) |
| `lib/quiz_screen.dart`      | La pantalla del quiz                                    |
| `lib/main.dart`             | Arranque de la app                                      |
| `test/quiz_logic_test.dart` | Tests de las reglas, la navegación y la integridad de los datos |
| `test/widget_test.dart`     | Tests de la pantalla (foco, rendirse, reiniciar, listas, modos) |

Para añadir otra lista: crear sus datos, un adaptador a `QuizItem` y una
entrada en `wordLists` (`lib/word_lists.dart`). Si usa un idioma nuevo, añadirlo
a `Language`, su normalización a `normalize` y sus direcciones a `QuizMode`.
