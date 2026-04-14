# CI Pipeline

En esta etapa preferimos correr poco, pero que lo que corra sirva de verdad.

## Qué corre y cuándo

Hay tres workflows visibles:

- `.github/workflows/ci.yml` para `push` a `main`, `dev`, `feat/**` y `feature/**`, más corrida manual
- `.github/workflows/ci-pr.yml` para `pull_request` hacia `main` o `dev`
- `.github/workflows/pages.yml` para export web y deploy a GitHub Pages en `main`, más corrida manual

Los workflows de CI y PR delegan en `.github/workflows/ci-shared.yml`.

## Checks obligatorios

- `Docs / Wiki`
- `Codebase / Structure`
- `Gameplay Smoke`

Los tres bloquean merge. La idea es que cada job responda una sola pregunta.

## `Docs / Wiki`

Este job cubre dos cosas:

- que la documentacion base del proyecto siga existiendo
- que los cambios sensibles de un PR dejen rastro escrito

La documentacion minima que siempre tiene que estar presente es esta:

- `README.md`
- `wiki/Home.md`
- `wiki/Getting-Started.md`
- `wiki/CI.md`
- `wiki/Architecture.md`
- `wiki/Bitacora.md`

En `push`, si falla, deberia ser porque falta alguno de esos archivos o porque quedo vacio.

En `pull_request` suma dos recordatorios de trazabilidad:

- si el PR cambia workflows o scripts de validacion, tiene que actualizar `wiki/CI.md`
- si el PR toca zonas sensibles del proyecto (`project/niveles`, `project/interface`, `project/resources`, `project.godot`), tiene que actualizar `README.md` o algun archivo en `wiki/`


## `Codebase / Structure`

Este job corta solo por problemas técnicos básicos del slice:

- estructura crítica del repo
- escenas y archivos mínimos del flujo jugable
- entrypoints del runner de validación
- ESLint solo si existe configuración real y lockfile pinneado
- carga headless del proyecto con `godot --headless --path project --editor --quit`

No corre tests de catálogo ni integración fina.

## `Gameplay Smoke`

Este job responde una sola pregunta: si el flujo minimo del slice todavia puede llegar al gameplay sin romperse.

Corre en `barichello/godot-ci:4.6.2`, instala `libfontconfig1` y ejecuta `scripts/run-godot-validation.sh --run smoke godot`.

La pasada usa el track baseline y recorre este camino:

- Splash
- Intro
- Selector
- Archivero
- Libro del track baseline
- Apertura del capítulo 1
- Entrada al gameplay

Si falla, la expectativa es que se haya roto el flujo principal antes o justo al entrar a la escena jugable.

Valida tres cosas:

- que la escena jugable cargue
- que `ManagerLevel` quede inicializado con track y corrida activa
- que el slice siga vivo en los primeros frames

No intenta cubrir drag and drop, save/resume profundo ni navegacion fina de todos los tracks.

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

## Deploy web

El deploy web no bloquea merge y vive aparte en `.github/workflows/pages.yml`.

Ese workflow:

- corre solo en `main` o manualmente
- valida import headless del proyecto
- exporta el preset web `index` a `build/web/index.html`
- publica esa carpeta en GitHub Pages

Si el repo ya tenía Pages prendido con source de branch, conviene cambiarlo a `GitHub Actions` para que deje de fallar el deployment interno viejo y pase a usar este workflow.

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
```

Si querés correr solo una parte:

- `sh scripts/run-godot-validation.sh --run codebase godot`
- `sh scripts/run-godot-validation.sh --run smoke godot`
- `sh scripts/run-godot-validation.sh --run full godot`

## Cómo leer un test

- si falla `Docs / Wiki`, revisar documentación base del repo
- si falla `Codebase / Structure`, revisar estructura base, tooling o carga headless
- si falla `Gameplay Smoke`, revisar el flujo mínimo jugable del slice
- si hace falta más profundidad, correr manualmente los tests específicos de `project/tests/`

