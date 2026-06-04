# Tests

## Smoke (CI, sin GdUnit4)

```bash
godot --headless --path juego -s res://tests/vertical_slice_smoke_test.gd
```

O: `sh scripts/run-godot-validation.sh --run smoke godot`

## GdUnit4 (unitarios)

No está en el repo. Instalar **v6.1.x** (AssetLib o [release](https://github.com/godot-gdunit-labs/gdUnit4/releases/tag/v6.1.3)) en `juego/addons/gdUnit4/`, activar plugin.

Correr desde el panel GdUnit: `tests/preguntas/carga_json_preguntas_test.gd` (8 tests: JSON, loader, evaluador).

## Archivos

- `vertical_slice_smoke_test.gd` — flujo principal headless
- `preguntas/carga_json_preguntas_test.gd` — pipeline quiz
