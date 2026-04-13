# CI Pipeline

En esta etapa preferimos correr poco, pero que lo que corra sirva de verdad.

## Qué corre y cuándo

Hay dos workflows visibles:

- `.github/workflows/ci.yml` para `push` a `main`, `dev`, `feat/**` y `feature/**`, más corrida manual
- `.github/workflows/ci-pr.yml` para `pull_request` hacia `main` o `dev`

Los dos delegan en `.github/workflows/ci-shared.yml`.

No hay validación diff-aware, no hay nightly y no hay export web dentro del gate principal. La suite es la misma en push y PR a propósito: menos caminos, menos sorpresas.

## Checks obligatorios

- `Docs / Wiki`
- `Codebase / Structure`
- `Gameplay Smoke`

Los tres bloquean merge. La idea es que cada job responda una sola pregunta.

## `Docs / Wiki`

Este job solo revisa que exista la documentación mínima del proyecto:

- `README.md`
- `wiki/Home.md`
- `wiki/Getting-Started.md`
- `wiki/CI.md`
- `wiki/Architecture.md`
- `wiki/Bitacora.md`

No intenta validar calidad de redacción, links o consistencia fina. Si falla, debería ser porque desapareció documentación base o quedó vacía.

## `Codebase / Structure`

Este job corta solo por problemas técnicos básicos del slice:

- estructura crítica del repo
- escenas y archivos mínimos del flujo jugable
- entrypoints del runner de validación
- ESLint solo si existe configuración real y lockfile pinneado
- carga headless del proyecto con `godot --headless --path project --editor --quit`

No corre tests de catálogo ni integración fina.

## `Gameplay Smoke`

Este job corre en `barichello/godot-ci:4.6.2`, instala `libfontconfig1` y ejecuta `scripts/run-godot-validation.sh --run smoke godot`.

El smoke test hace una pasada corta del flujo principal:

- Splash
- Intro
- Selector
- Archivero
- Libro del track baseline
- Apertura del capítulo 1
- Entrada al gameplay

Valida que la escena jugable cargue, que `ManagerLevel` tenga track y corrida activa, y que el slice no se caiga en los primeros frames. No intenta probar drag and drop, save/resume profundo ni navegación fina de todos los tracks.

## Qué quedó afuera del gate principal

Estos tests siguen sirviendo, pero ya no bloquean cada PR:

- `res://tests/content_catalog_validation_test.gd`
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
powershell -ExecutionPolicy Bypass -File scripts/run-godot-validation.ps1 -Mode ci
```

Si `godot` no está en PATH:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run-godot-validation.ps1 -Mode ci -GodotCommand "C:\ruta\a\Godot_v4.6.2-stable_win64.exe"
```

En shell:

```bash
sh scripts/run-godot-validation.sh --run ci godot

Si querés correr solo una parte:

- `sh scripts/run-godot-validation.sh --run codebase godot`
- `sh scripts/run-godot-validation.sh --run smoke godot`
- `sh scripts/run-godot-validation.sh --run full godot`
```

## Cómo leer un test

- si falla `Docs / Wiki`, revisar documentación base del repo
- si falla `Codebase / Structure`, revisar estructura base, tooling o carga headless
- si falla `Gameplay Smoke`, revisar el flujo mínimo jugable del slice
- si hace falta más profundidad, correr manualmente los tests específicos de `project/tests/`

