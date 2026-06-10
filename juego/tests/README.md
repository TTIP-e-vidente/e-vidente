# Tests

## Smoke (CI, sin GdUnit4)

```bash
godot --headless --path juego -s res://tests/vertical_slice_smoke_test.gd
```

O: `sh scripts/run-godot-validation.sh --run smoke godot`

## GdUnit4 (unitarios + jugabilidad UNQ-172)

No está en el repo. Instalar **v6.1.x** (AssetLib o [release](https://github.com/godot-gdunit-labs/gdUnit4/releases/tag/v6.1.3)) en `juego/addons/gdUnit4/`, activar plugin.

Correr desde el panel GdUnit:

- `tests/preguntas/carga_json_preguntas_test.gd` (8 tests: JSON, loader, evaluador)
- `tests/preguntas/test_jugabilidad_vertical_slice.gd` (3 tests: escenas, UI crítica, mapa)
- `tests/preguntas/test_modalidad_preguntas_ux_ui.gd` (8 tests: UX/UI de la modalidad de preguntas)

Headless (suite UNQ-172):

```bash
godot --headless --path juego -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests/preguntas/test_jugabilidad_vertical_slice.gd
```

Documentación: `docs-local/testing.md`

## Archivos

- `vertical_slice_smoke_test.gd` — flujo principal headless
- `preguntas/test_jugabilidad_vertical_slice.gd` — jugabilidad/UI vertical slice (GdUnit4, UNQ-172)
- `preguntas/jugabilidad_vertical_slice_datos.gd` — catálogo de escenas y nodos del test
- `preguntas/test_modalidad_preguntas_ux_ui.gd` — UX/UI de la modalidad de preguntas (8 tests)
- `preguntas/carga_json_preguntas_test.gd` — pipeline quiz
