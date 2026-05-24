# Tests del proyecto E-VIDENTE

Usamos [GdUnit4](https://github.com/godot-gdunit-labs/gdUnit4) para los tests unitarios dentro del editor de Godot.

## Antes de correr los tests: instalá GdUnit4

GdUnit4 no se versiona en el repo, así que cada uno lo instala localmente.

**Opción A — desde el editor:**
1. Abrí el proyecto en Godot 4.6.
2. Andá a **AssetLib** (panel superior).
3. Buscá `gdUnit4`, descargá la versión **v6.1.x** e instalala.
4. Activá el plugin en **Proyecto → Configuración del Proyecto → Plugins**.

**Opción B — desde GitHub:**
- Bajá el release [v6.1.3](https://github.com/godot-gdunit-labs/gdUnit4/releases/tag/v6.1.3).
- Copiá la carpeta `addons/gdUnit4/` dentro de `project/addons/`.
- Activá el plugin igual que arriba.

> `addons/gdUnit4/` está en `.gitignore` — no lo commitees.

---

## Estructura

```
project/tests/
├── README.md                              ← este archivo
├── vertical_slice_smoke_test.gd           ← smoke test headless, no necesita GdUnit4
└── preguntas/
    └── carga_json_preguntas_test.gd       ← pipeline de carga y evaluación de preguntas
```

---

## Cómo correr los tests

Con GdUnit4 instalado, abrí el panel **GdUnit Inspector** desde la barra inferior del editor.
Clic derecho sobre `tests/preguntas/carga_json_preguntas_test.gd` → **Run Tests**.
También podés correr toda la carpeta `tests/preguntas/` desde ahí.

---

## Qué cubre `carga_json_preguntas_test.gd`

Valida el flujo completo: `JSON → QuestionJsonLoader → Preguntas → EvaluadorDeOpcionPregunta`.

| Test | Qué verifica |
|---|---|
| `test_fixture_json_se_puede_abrir` | el JSON del fixture existe y parsea |
| `test_carga_retorna_ok` | el loader retorna `ok: true` |
| `test_tema_tiene_al_menos_una_pregunta` | el resultado tiene preguntas |
| `test_pregunta_tiene_opciones` | la primera pregunta tiene opciones cargadas |
| `test_existe_opcion_correcta` | `correct_answer` no está vacío y aparece en las opciones |
| `test_existe_opcion_incorrecta` | hay al menos una opción incorrecta |
| `test_evaluar_opcion_correcta` | el evaluador devuelve `true` para la correcta |
| `test_evaluar_opcion_incorrecta` | el evaluador devuelve `false` para una incorrecta |

Fixture: `res://niveles/nodos/celiaquia/gluten_arroz.json`

---

## Smoke test (sin GdUnit4)

`vertical_slice_smoke_test.gd` usa `extends SceneTree` y se ejecuta en modo headless
con `scripts/run-godot-validation.ps1` o `.sh`. No requiere GdUnit4.
