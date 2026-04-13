# CI Pipeline

En esta etapa preferimos correr poco, pero que lo que corra sirva de verdad.

## Qué corre y cuándo

Hay dos workflows visibles:

- `.github/workflows/ci.yml` para `push` a `main`, `dev`, `feat/**` y `feature/**`, más corrida manual
- `.github/workflows/ci-pr.yml` para `pull_request` hacia `main` o `dev`

Los dos delegan en `.github/workflows/ci-shared.yml`.

No hay validación diff-aware, no hay nightly y no hay export web dentro del gate principal. La suite es la misma en push y PR a propósito: menos caminos, menos sorpresas.

## Checks obligatorios

- `Guardrails`
- `Core Validation`

Los dos bloquean merge. Con eso alcanza por ahora.

## `Guardrails`

Este job corta solo por problemas básicos del repo:

- estructura crítica del repo
- escenas y archivos mínimos del slice jugable
- entrypoints del runner de validación
- ESLint solo si existe configuración real y lockfile pinneado

No revisa docs, no mira la wiki y no suma warnings de relleno. Si falla, debería ser por algo que realmente dejó mal parado al repo.

## `Core Validation`

Este job corre en `barichello/godot-ci:4.6.2` y usa `scripts/run-godot-validation.sh`.

Hoy el gate obligatorio quedó en tres pasos:

- `godot --headless --path project --editor --quit`
- `res://tests/content_catalog_validation_test.gd`
- `res://tests/vertical_slice_smoke_test.gd`

El smoke test hace un recorrido corto por el flujo principal del slice:

- Intro
- Selector
- Archivero
- Libro del primer track
- Capítulo 1
- Entrada al gameplay

Valida que la escena jugable cargue, que `ManagerLevel` tenga una corrida activa y que el slice no se caiga en los primeros frames. No intenta probar todo el juego. Solo confirma que el camino principal sigue vivo.

## Qué quedó afuera del gate principal

Estos tests siguen sirviendo, pero ya no bloquean cada PR:

- save/local profile
- señales de `SaveManager`
- migraciones legacy
- overlay de `Archivero`
- quick save por nivel
- tests de integración más finos por track

Tiene sentido correrlos cuando se toque fuerte persistencia, UI o flujo interno, pero no vale la pena ponerlos a bloquear cada commit.

## Decisiones de fiabilidad

- sin cache de `project/.godot`
- sin reintentos especiales ni limpieza condicional del import cache
- sin perfiles `full` vs `pr-fast`
- sin export web dentro del workflow obligatorio
- un único runner funcional para push y PR

La apuesta acá es que cada corrida se parezca lo más posible a un checkout limpio, aunque eso signifique resignar optimizaciones que hoy meten más ruido que valor.

## Validación local

En Windows:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run-godot-validation.ps1
```

Si `godot` no está en PATH:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run-godot-validation.ps1 -GodotCommand "C:\ruta\a\Godot_v4.6.2-stable_win64.exe"
```

En shell:

```bash
sh scripts/run-godot-validation.sh --run ci godot
```

## Cómo leer un test

- si falla `Guardrails`, revisar estructura base o tooling 
- si falla `Core Validation`, revisar parseo, catálogo o flujo mínimo del juego
- si hace falta más profundidad, correr manualmente los tests específicos de `project/tests/`

