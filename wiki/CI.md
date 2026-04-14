# CI Pipeline

En esta etapa estamos apuntando a una CI chica, clara y util. No queremos un pipeline enorme ni checks que hagan ruido porque si. La idea es que cada corrida diga algo concreto sobre el estado del proyecto.

## Qué corre y cuándo

Hoy tenemos cuatro workflows visibles:

- `.github/workflows/docs-pr.yml` para `pull_request` hacia `main` o `dev`
- `.github/workflows/ci.yml` para `push` a `main`, `dev`, `feat/**` y `feature/**`, mas corrida manual
- `.github/workflows/gameplay-smoke-pr.yml` para `pull_request` hacia `main` o `dev`, mas corrida manual
- `.github/workflows/pages.yml` para export web y deploy a GitHub Pages en `main`, mas corrida manual

No hay workflow compartido. Lo dejamos asi a proposito para que cada pipeline tenga un objetivo claro y sea facil de leer cuando falla.

## Checks obligatorios

- `Docs / Tracking`
- `Technical Health`
- `Gameplay Smoke`

Los tres pueden bloquear merge. En la practica, `Technical Health` llega por el `push` del branch y los otros dos corren sobre el `pull_request`.

## `Docs / Tracking`

Este workflow vive en `.github/workflows/docs-pr.yml` y corre solo en PR.

La idea es bastante simple: si un cambio entra por PR, deberia dejar algo de contexto escrito. No hace falta una novela, pero si una minima traza de que se cambio y por que.

Chequea dos cosas:

- que la documentacion base del repo siga estando
- que el diff del PR incluya documentacion Markdown y alguna entrada de seguimiento

La documentacion minima que siempre deberia existir es esta:

- `README.md`
- `wiki/Home.md`
- `wiki/Getting-Started.md`
- `wiki/CI.md`
- `wiki/Architecture.md`
- `wiki/Bitacora.md`

Para el diff del PR, el gate pide:

- al menos un `.md` tocado en `docs/`, `wiki/`, `README.md` o `CHANGELOG.md`
- al menos un archivo de seguimiento tocado: `wiki/Bitacora.md`, `CHANGELOG.md` o algun `.md` equivalente con `bitacora` o `changelog` dentro de `docs/`

Hoy el repo usa `wiki/` y no `docs/`, pero el check acepta ambos para no atar la regla a una sola carpeta.

## `Technical Health`

Este workflow vive en `.github/workflows/ci.yml` y corre en cada `push` relevante.

Lo que intenta responder es esto: con un checkout limpio, el proyecto sigue sano o ya hay alguna rotura tecnica obvia.

Incluye estos checks:

- valida estructura critica del repo
- valida escenas y archivos minimos del slice
- valida que sigan presentes los entrypoints de CI
- corre ESLint solo si existe configuracion real y lockfile pinneado
- abre el proyecto en headless con `godot --headless --path project --editor --quit`
- revisa el log aunque Godot salga con codigo `0`, para no dejar pasar parse errors silenciosos

No corre catalog validation ni tests de integracion fina. En esta etapa preferimos detectar roturas claras y mantener el gate estable.

## `Gameplay Smoke`

Este workflow vive en `.github/workflows/gameplay-smoke-pr.yml` y corre en PR.

La pregunta aca es bien concreta: el flujo minimo jugable sigue llegando a gameplay sin romperse.

Corre en `barichello/godot-ci:4.6.2`, instala `libfontconfig1` y ejecuta `scripts/run-godot-validation.sh --run smoke godot`.

La pasada usa el track baseline y recorre este camino:

- Splash
- Intro
- Selector
- Archivero
- Libro del track baseline
- Apertura del capitulo 1
- Entrada al gameplay

Este smoke valida solo lo justo para darnos confianza:

- que la escena jugable cargue
- que exista `ManagerLevel`
- que `ManagerLevel` exponga el contrato runtime minimo esperado
- que track y corrida activa queden inicializados
- que la escena siga viva durante los primeros frames

No intenta cubrir drag and drop, save/resume profundo, UI fina ni todos los tracks.

## Qué quedó afuera del gate principal

Estos tests siguen siendo utiles, pero no bloquean cada PR:

- `res://tests/content_catalog_validation_test.gd`
- save/local profile
- señales de `SaveManager`
- migraciones legacy
- overlay de `Archivero`
- quick save por nivel
- tests de integracion mas finos por track

Si tocamos fuerte persistencia, UI o flujo interno, tiene sentido correrlos. Pero hoy no conviene meterlos en el gate chico del dia a dia.

## Decisiones de fiabilidad

- sin cache de `project/.godot`
- sin reintentos especiales ni limpieza condicional del import cache
- sin suites grandes para cada PR
- sin export web dentro del gate obligatorio
- logs como artifact para `Technical Health` y `Gameplay Smoke`
- un script de validacion con modos chicos: `technical`, `smoke`, `ci` y `full`

## Deploy web

El deploy web no bloquea merge y vive aparte en `.github/workflows/pages.yml`.

Ese workflow:

- corre solo en `main` o manualmente
- valida import headless del proyecto
- exporta el preset web `index` a `build/web/index.html`
- publica esa carpeta en GitHub Pages

Si el repo ya tenia Pages prendido con source de branch, conviene cambiarlo a `GitHub Actions` para que deje de fallar el deployment viejo y pase a usar este workflow.

## Validación local

En Windows:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run-godot-validation.ps1 -Mode technical
powershell -ExecutionPolicy Bypass -File scripts/run-godot-validation.ps1 -Mode smoke
```

Si `godot` no esta en PATH:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run-godot-validation.ps1 -Mode technical -GodotCommand "C:\ruta\a\Godot_v4.6.2-stable_win64.exe"
```

En shell:

```bash
sh scripts/run-godot-validation.sh --run technical godot
sh scripts/run-godot-validation.sh --run smoke godot
```

Para el check de documentacion del PR:

```bash
git fetch origin main
EVIDENTE_PR_BASE_REF=main sh scripts/ci/check-pr-docs.sh
```

Si queres correr la suite larga manualmente:

- `sh scripts/run-godot-validation.sh --run ci godot`
- `sh scripts/run-godot-validation.sh --run full godot`

## Cómo leer un check

- si falla `Docs / Tracking`, revisar si el PR actualizo docs Markdown y bitacora o changelog
- si falla `Technical Health`, revisar estructura, tooling, parseo o carga headless
- si falla `Gameplay Smoke`, revisar el flujo minimo Splash -> Intro -> Selector -> Archivero -> Libro -> Gameplay
- si hace falta mas profundidad, correr manualmente los tests especificos de `project/tests/`

