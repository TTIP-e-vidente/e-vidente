# CI Pipeline

En esta etapa estamos apuntando a una CI chica, clara y util. No queremos un pipeline enorme ni checks que hagan ruido porque si. La idea es que cada corrida diga algo concreto sobre el estado del proyecto.

## Qué corre y cuándo

Hoy tenemos tres workflows visibles:

- `.github/workflows/docs-pr.yml` para `pull_request` hacia `main` o `dev`
- `.github/workflows/ci.yml` para `pull_request` hacia `main` o `dev`, mas corrida manual
- `.github/workflows/gameplay-smoke-pr.yml` para `pull_request` hacia `main` o `dev`, mas corrida manual

No hay workflow compartido. Lo dejamos asi a proposito para que cada pipeline tenga un objetivo claro y sea facil de leer cuando falla.

## Checks obligatorios

- `Docs / Tracking`
- `Technical Health`
- `Gameplay Smoke`

Los tres pueden bloquear merge. Hoy los tres corren sobre el `pull_request` y dos de ellos tambien se pueden disparar manualmente.

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

- al menos un `.md` tocado en `docs/`, `wiki/` o `README.md`
- al menos un archivo de seguimiento tocado: `wiki/Bitacora.md` o algún `.md` equivalente con `bitacora` dentro de `docs/`

`docs-local/` queda fuera del gate porque se usa como documentacion local del equipo y no forma parte del contenido publicado del repo en GitHub.

## `Technical Health`

Este workflow vive en `.github/workflows/ci.yml` y hoy corre en PR o manual.

Es el check mas chico de los tres. No abre Godot ni corre smoke. Su trabajo actual es responder algo mas acotado: si la estructura minima del repo sigue en pie y si el lint opcional no se rompio.

Incluye dos jobs:

- `Structure`: revisa directorios y archivos criticos del repo, incluyendo escenas base del slice y scripts de CI.
- `Lint`: corre ESLint solo si existe `package.json`, hay configuracion real de ESLint y hay lockfile pinneado.

Hoy no hace import headless, no parsea logs de Godot y no sube artifacts. Si queremos volver a usarlo como chequeo tecnico mas profundo, eso habria que reintroducirlo en el workflow real.

## `Gameplay Smoke`

Este workflow vive en `.github/workflows/gameplay-smoke-pr.yml` y corre en PR.

La pregunta aca es bien concreta: el flujo minimo jugable sigue llegando a gameplay sin romperse.

Corre en `barichello/godot-ci:4.6.2`, instala `libfontconfig1` y ejecuta `scripts/run-godot-validation.sh --run smoke godot`.

Antes de entrar al vertical slice, el runner hace un import headless del proyecto. En cold start de GitHub Actions vimos fallos falsos por recursos importados y por carga de UI no critica cuando el smoke iba directo al gameplay sobre un checkout limpio. Con el import previo, el test reproduce mejor el arranque real del proyecto y deja de mezclar validacion jugable con fragilidad de importacion.

La pasada hoy recorre este camino:

- Splash
- Intro
- Selector
- Mapa
- Apertura del capitulo 1 desde el mapa
- Entrada al gameplay

Este smoke valida solo lo justo para darnos confianza:

- que la escena jugable cargue
- que el mapa cargue y exponga sus nodos jugables esperados
- que exista `ManagerLevel`
- que `ManagerLevel` exponga el contrato runtime minimo esperado
- que track y corrida activa queden inicializados
- que la escena siga viva durante los primeros frames
- que el nivel pueda completar una corrida y dejar el estado post-completion esperado

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
- import headless antes del smoke para estabilizar runners limpios
- sin export web dentro del gate obligatorio
- logs como artifact para `Gameplay Smoke`
- un script de validacion con modos chicos: `technical`, `smoke`, `ci` y `full`, aunque hoy en CI solo lo usa `Gameplay Smoke`

## Deploy web

El export web no bloquea merge y hoy tampoco tiene un workflow versionado dentro de `.github/workflows/`.

El repo mantiene el preset web `index` y la salida esperada sigue siendo `build/web/index.html` cuando el export corre bien.

Si mas adelante se automatiza la publicacion web, conviene agregar un workflow dedicado y documentarlo aca con el path real.

## Validación local

Hay una diferencia importante entre la validacion local y la CI real.

Los scripts `run-godot-validation.*` siguen sirviendo para abrir el proyecto en headless y correr smoke manualmente. Pero hoy ese paso de import headless no forma parte de `Technical Health`; en CI solo corre dentro de `Gameplay Smoke`.

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

- si falla `Docs / Tracking`, revisar si el PR actualizó docs Markdown y bitácora
- si falla `Technical Health`, revisar estructura critica del repo o tooling de lint
- si falla `Gameplay Smoke`, revisar el flujo minimo Splash -> Intro -> Selector -> Mapa -> Gameplay
- si hace falta mas profundidad, correr manualmente los tests especificos de `project/tests/`

