# Tests

Guía de referencia. Documentación de defensa: [`docs-local/onboarding-jugabilidad-tests/README.md`](../../docs-local/onboarding-jugabilidad-tests/README.md)

---

## Capas de tests

| Capa | Archivo | Framework | Qué protege |
|---|---|---|---|
| Smoke CI | `vertical_slice_smoke_test.gd` | Godot headless | Flujo completo Intro → mapa → partida → cierre |
| Pipeline JSON | `preguntas/carga_json_preguntas_test.gd` | GdUnit4 | JSON → loader → `Preguntas` → evaluador |
| UX Preguntas | `preguntas/test_modalidad_preguntas.gd` | GdUnit4 (UNQ-172) | Feedback rojo/verde, reintento, panel final |

---

## Smoke (CI, sin GdUnit4)

```bash
godot --headless --path juego -s res://tests/vertical_slice_smoke_test.gd
```

O: `sh scripts/run-godot-validation.sh --run smoke godot`

Corre en cada PR.

---

## GdUnit4

GdUnit4 **no está en el repo**. Instalar **v6.1.x** en `juego/addons/gdUnit4/` y activar el plugin.

### Suites en `preguntas/`

| Suite | Archivo | Tests | Qué valida |
|---|---|---|---|
| JSON / loader | `carga_json_preguntas_test.gd` | 8 | Fixture JSON, loader, evaluador |
| UX Preguntas (UNQ-172) | `test_modalidad_preguntas.gd` | 5 | Carga, feedback rojo/verde, reintento, panel `"1/1"` |

### Correr headless

Todas las suites de preguntas:

```bash
godot --headless --path juego -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a res://tests/preguntas/
```

Solo UNQ-172:

```bash
godot --headless --path juego -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a res://tests/preguntas/test_modalidad_preguntas.gd
```

También desde el panel GdUnit en el editor.

---

## UNQ-172 — `test_modalidad_preguntas.gd`

Test de **feedback visual** al responder en `pregunta.tscn`.

| Test | Qué verifica |
|---|---|
| `test_quiz_cargado_deja_modalidad_lista_para_jugar` | Enunciado + opciones visibles/habilitadas |
| `test_respuesta_incorrecta_pinta_boton_rojo` | `MiPaleta.FEEDBACK_ERROR` |
| `test_respuesta_incorrecta_permite_reintentar` | `bloqueado == false` tras error |
| `test_respuesta_correcta_pinta_boton_verde` | `MiPaleta.FEEDBACK_OK` |
| `test_respuesta_correcta_muestra_puntaje_en_panel_final` | Puntaje 1, panel Game Over `"1/1"` |

Quiz de prueba: *"¿El gluten está en el maíz?"* — "Sí" incorrecta, "No" correcta.

Simula el click con `boton.pressed.emit()`.

→ [Doc detallada](../../docs-local/onboarding-jugabilidad-tests/test-modalidad-preguntas.md)

---

## Archivos del directorio

| Archivo | Tipo | Descripción |
|---|---|---|
| `vertical_slice_smoke_test.gd` | Smoke CI | Flujo principal headless |
| `preguntas/carga_json_preguntas_test.gd` | GdUnit4 | Pipeline JSON (8 tests) |
| `preguntas/test_modalidad_preguntas.gd` | GdUnit4 | UX modalidad preguntas (5 tests, UNQ-172) |

---

## Qué testeamos y qué no (UNQ-172)

**Sí:** carga de modalidad, feedback rojo/verde, reintento al fallar, panel final al acertar.

**No:** partida completa (smoke), sonido, animaciones, click real del mouse, JSON (otra suite), balance pedagógico.

---

## Respuestas rápidas para la defensa

**¿Por qué GdUnit4 y no solo smoke?**  
El smoke recorre el flujo feliz. GdUnit permite assertar el feedback visual de preguntas sin jugar toda la partida.

**¿Por qué `pressed.emit()`?**  
Simula el click del jugador sin llamar métodos internos de la escena.

**¿Por qué no JSON en este test?**  
Para aislar UX/UI. El loader se prueba en `carga_json_preguntas_test.gd`.

**¿Qué significa que pasen?**  
El feedback visual de preguntas funciona. No significa que todo el juego esté probado.

---

## Referencias

- Onboarding / guion de defensa: [`docs-local/onboarding-jugabilidad-tests/`](../../docs-local/onboarding-jugabilidad-tests/)
- US-07 / UNQ-172: `wiki/Entrega-3-User-Stories.md`
