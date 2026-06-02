# opciones_palabras — Modalidad "Completar con opciones de palabras"

## Qué hace esta modalidad

El jugador ve una frase incompleta con `____` y botones de palabras para completarla.

**Regla central**: si la respuesta es incorrecta, el botón hace un shake y vuelve a estar
disponible. El jugador puede reintentar hasta acertar. El mini-juego **solo termina cuando
todas las respuestas son correctas**. No hay "falló" — solo "todavía no".

---

## Flujo del jugador (lo que ve el jugador)

```
1. Aparece la frase incompleta con uno o varios ____
2. Aparecen botones con palabras para elegir
3. El jugador toca un botón
   → Si es INCORRECTO: el botón hace shake y vuelve disponible
                       "Esa no es. Intentá de nuevo."
   → Si es CORRECTO:   la palabra queda marcada (✓) en el botón
                       la frase muestra [palabra] en lugar de ____
                       si hay más blanks: "Palabra X de Y: elegí la siguiente."
4. Cuando todos los blanks están completos: "¡Correcto!"
5. Después de 1.5 segundos: avanza al siguiente juego
```

---

## Flujo técnico completo

```
celiaquia_mapa.json
  { "type": "word_options", "difficulty": N }
          ↓
ArmadorDePartida.gd
  MODOS_SOPORTADOS incluye "word_options"
  construye el plan de la partida
          ↓
NodeContentLoader.gd
  carga opciones_palabras.json como archivo OPCIONAL
  (si falta, push_warning y continúa — no rompe quiz/drag/match)
  filtra por mode="word_options" y difficulty=N
          ↓
WordOptionsLoader.gd
  pick(N):
    load_all()                          → carga JSON con caché
    _validate_challenge()               → descarta entradas inválidas
    _get_candidates_by_difficulty(N)    → filtra por dificultad
    candidates.shuffle()                → variedad entre sesiones
    _shuffle_options()                  → mezcla las opciones del ganador
    devuelve challenge_data
          ↓
GameSceneRouter.gd
  ir_a_modo_jugable("word_options")
  → abre opciones_palabras.tscn
          ↓
opciones_palabras.gd._ready()
  NodoRuntime.obtener_actividad_actual()
  → setup(challenge_data)
          ↓
Retry loop (slot a slot):
  _on_option_pressed(option, btn)
    _is_correct_for_current_slot()
    INCORRECTO → _show_error_feedback() + _return_option_to_origin() [Tween shake]
    CORRECTO   → _place_option_in_slot() + _update_sentence_display()
                 + _update_slot_progress() + _check_if_completed()
          ↓
_finish(true)
  _disable_interaction()
  _show_success_feedback()
  await 1.5s
  NodoRuntime.finalizar_mini_juego()   ← UNA SOLA VEZ
          ↓
ContinuidadDePartidaDeNodo.gd
  calcula score, EXP, progreso
  avanza al siguiente juego del plan
```

---

## Lo que esta escena NO hace

- ❌ No calcula score, EXP ni progreso (lo hace el sistema central).
- ❌ No finaliza con error (solo finaliza cuando todo es correcto).
- ❌ No hardcodea desafíos (todo viene del JSON vía NodoRuntime).
- ❌ No carga el JSON directamente (lo hace WordOptionsLoader).

---

## Archivos de esta carpeta

| Archivo | Rol |
|---|---|
| `WordOptionsLoader.gd` | Carga, valida, filtra y mezcla desafíos del JSON |
| `opciones_palabras.gd` | Lógica completa: render, retry loop, feedback, finalización |
| `opciones_palabras.tscn` | Escena visual (puede ser provisional o definitiva) |
| `README.md` | Esta documentación |

El JSON está en `res://contenido/mapa/opciones_palabras.json`.

---

## Contrato del JSON

```json
"word_celiaquia_agua_01": {
  "mode": "word_options",
  "difficulty": 1,
  "sentence": "Tomar ____ ayuda a mantener el cuerpo hidratado.",
  "answers": ["agua"],
  "options": ["agua", "gaseosa", "cerveza"],
  "order_matters": false,
  "teaching_key": "celiaquia_bebida"
}
```

| Campo | Tipo | Obligatorio | Descripción |
|---|---|---|---|
| `mode` | String | ✅ | Siempre `"word_options"`. |
| `difficulty` | int | ✅ | `1`, `2` o `3`. |
| `sentence` | String | ✅ | Frase con `____` por cada respuesta esperada. |
| `answers` | Array | ✅ | Respuestas correctas en orden de aparición en la frase. |
| `options` | Array | ✅ | Todas las opciones: answers + palabras distractoras. |
| `order_matters` | bool | ✅ | `true` = cada blank acepta solo la respuesta de esa posición. |
| `teaching_key` | String | ❌ | Reservado para feedback educativo futuro. No se usa todavía. |

### Reglas de validación (WordOptionsLoader las verifica al cargar)

1. `mode` == `"word_options"`.
2. `difficulty` == `1`, `2` o `3`.
3. `answers` no está vacío.
4. `options` no está vacío.
5. Cada elemento de `answers` existe en `options` (comparación exacta).
6. `sentence.count("____") == answers.size()`.

Si falla alguna regla → `push_error` en consola, el desafío se descarta silenciosamente.

---

## Contrato del .tscn

### Nodos obligatorios (dentro de un VBoxContainer)

```
OpcionesPalabras (Control)
└── VBoxContainer
    ├── PromptLabel       ← Label — muestra la consigna
    ├── SentenceLabel     ← Label — muestra la frase con ____ y [palabras]
    ├── OptionsContainer  ← Container — contiene los botones generados por código
    └── FeedbackLabel     ← Label — feedback de error, progreso y éxito
```

Si falta alguno → `_validate_scene_nodes()` emite `push_error` con el nombre exacto.

### Nodos opcionales

```
    └── ConfirmButton     ← Button — solo si el diseño lo requiere
```

Si `ConfirmButton` no existe, el script lo ignora sin error y funciona igual.

> **Nota**: `OptionsContainer` puede ser `FlowContainer`, `HBoxContainer`, `GridContainer`
> o cualquier `Container`. El script lo instancia con `Container` genérico.

---

## Comportamiento palabra INCORRECTA

```
_on_option_pressed("cerveza", btn)
  → _is_correct_for_current_slot("cerveza") = false
  → _show_error_feedback()
      FeedbackLabel: "Esa no es. Intentá de nuevo." (en rojo)
  → _return_option_to_origin(btn)
      Tween: shake horizontal de 4 pasos (0.35s total)
      _reset_option_state(btn):
        btn.disabled = false
        btn.text = "agua" (restaurado)
        FeedbackLabel: "" (limpio)
        _interaction_locked = false
  → El jugador puede seguir intentando
  → _already_finished sigue siendo false
```

## Comportamiento palabra CORRECTA

```
_on_option_pressed("agua", btn)
  → _is_correct_for_current_slot("agua") = true
  → _place_option_in_slot("agua", btn)
      _placed.append("agua")
      btn.disabled = true
      btn.text = "✓ agua"
      _update_sentence_display(): "Tomar [agua] ayuda..."
      _update_slot_progress(): "Palabra 1 de 2: elegí la siguiente."  ← multi-blank
  → _check_if_completed()
      Si todos completos: _finish(true)
      Si faltan: jugador continúa
```

---

## Cómo agregar un nuevo desafío

1. Abrir `res://contenido/mapa/opciones_palabras.json`.
2. Copiar cualquier entrada de la dificultad deseada como base.
3. Cambiar el ID (formato recomendado: `word_celiaquia_<tema>_<N>`).
4. Escribir `sentence` con `____` por cada respuesta.
5. Llenar `answers` en el mismo orden en que aparecen los `____`.
6. Poner las `answers` dentro de `options` más 1-3 palabras distractoras.
7. Verificar: `answers.size() == sentence.count("____")`.
8. Ejecutar smoke test — si el desafío tiene errores, `push_error` lo indica.

No hay que tocar ningún `.gd` para agregar contenido nuevo.

---

## Cómo agregar un nodo en el mapa

En `res://contenido/mapa/celiaquia_mapa.json`, dentro del array `games` de cualquier nodo:

```json
{ "type": "word_options", "difficulty": 1 }
```

El sistema elige automáticamente un desafío aleatorio de esa dificultad.

---

## MapBoard.tscn — Slots visuales

> **⚠️ Riesgo pendiente**: Los nodos del mapa visual están **hardcodeados** en `MapBoard.tscn`.
> Hay slots hasta `nivel_id = 30`. Los nodos 31, 32 y 33 de `celiaquia_mapa.json` (que usan
> `word_options`) **no tienen representación visual todavía**.

### Cómo agregar los slots 31, 32 y 33 en Godot

1. Abrir `res://mapas/MapBoard.tscn` en el editor.
2. En la jerarquía: `MapBoard → ScrollContainer → Contenido → NodesContainer`.
3. Seleccionar `Pregunta24` (el último nodo, `nivel_id = 30`).
4. Duplicarlo tres veces (`Ctrl+D` × 3).
5. Para cada copia, actualizar en el Inspector:
   - `nivel_id`: 31, 32 y 33 respectivamente.
   - `question_number` o `node_key`: según corresponda.
   - `position`: moverlos hacia abajo en el mapa (sumar ~300px de Y al último).
   - `label_text`: "Completar 1", "Completar 2", "Completar 3".
6. Guardar la escena.
7. Verificar en el juego que aparecen los nuevos nodos al final del mapa.

---

## Distribución actual (11 desafíos)

| Dificultad | Cantidad | Blanks | order_matters |
|---|---|---|---|
| 1 | 4 | 1 | false — cualquier orden |
| 2 | 4 | 2 | true — importa el orden |
| 3 | 3 | 2-3 | true — importa el orden |

---

## Checklist de prueba manual

```
□ Godot: File → Reload All
□ Smoke test → consola: "[WordOptions] ✓ Todos los tests pasaron."
□ MapBoard.tscn tiene slots visuales para nodos 31, 32 y 33
□ Nodo 31 (dif. 1)
    □ Se muestra PromptLabel y SentenceLabel con ____
    □ Se muestran botones de opciones
    □ Presionar opción incorrecta → shake visual → botón vuelve disponible
    □ Presionar opción correcta → "✓ palabra", avanza automáticamente
    □ "¡Correcto!" → transición en ~1.5s
□ Nodo 32 (dif. 2)
    □ Dos blanks en la frase
    □ Primer blank: retry hasta acertar
    □ FeedbackLabel muestra "Palabra 1 de 2: elegí la siguiente."
    □ Segundo blank: retry hasta acertar → "¡Correcto!" → transición
□ Nodo 33 (dif. 3)
    □ Dos o tres blanks, order_matters=true
    □ Palabras en orden incorrecto → incorrecto
    □ Palabras en orden correcto → correcto
□ Score/EXP/progreso en pantalla de finalización (no en la escena)
□ Jugar quiz  → sin cambios ✓
□ Jugar drag  → sin cambios ✓
□ Jugar match → sin cambios ✓
```

---

## Para el jurado — Defensa técnica de la modalidad

### Qué se implementó

Se integró una nueva modalidad de juego — **"Completar con opciones de palabras"** — sin
modificar ninguna de las modalidades existentes (quiz, arrastre, vinculación).

### Por qué es escalable

- **Contenido 100% dinámico**: cada desafío vive en `opciones_palabras.json`. Agregar nuevo
  contenido es editar el JSON — ningún `.gd` cambia.
- **Arquitectura reutilizada**: el sistema de partidas, score, EXP y progreso es exactamente
  el mismo que usa quiz, arrastre y vinculación. No se creó ningún autoload ni manager nuevo.
- **Validación de contrato automática**: `WordOptionsLoader` descarta entradas malformadas con
  errores claros en consola. El contenido no puede entrar sin pasar la validación.

### Por qué el error es aprendizaje

- Las palabras incorrectas **no penalizan**: el botón hace shake y vuelve disponible.
- El jugador **reintenta hasta acertar** — la frustración nunca termina el juego.
- Esta mecánica refuerza el aprendizaje por ensayo y error, alineada al objetivo educativo
  de E-VIDENTE.

### Cómo se protegieron las modalidades existentes

- `opciones_palabras.json` es un archivo **opcional** en `NodeContentLoader`. Si falta o
  está corrupto, se loguea un warning y las demás modalidades cargan normal.
- Las rutas del router son constantes separadas por modalidad — agregar una nueva es añadir
  una sola línea en cada `match`.

### Extensibilidad futura

- `teaching_key` está reservado para mostrar contenido educativo específico al finalizar.
- El script soporta drag-and-drop agregando `_on_option_dropped(option, target_slot)` sin
  cambiar nada de la lógica de validación.
- El mismo contrato JSON puede usarse para otras pistas (no solo celiaquía).

---

## Para más adelante (no urgente)

- `teaching_key`: mostrar imagen o explicación al completar correctamente.
- Slots visuales en el mapa para nodos 31-33.
- Animación de vuelo del botón hacia el slot (reemplazar shake por trayecto).
- Hints visuales: resaltar el blank activo con color diferente.
