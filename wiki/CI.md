# CI Pipeline

La CI quedó armada para que falle solo cuando haya una rotura real del proyecto o una violación concreta de las guardas del repo.

## Archivo y disparadores

La CI visible se reparte en dos workflows cortos y faciles de leer en GitHub:

- `.github/workflows/ci.yml` con nombre visible `CI Branch` para `push` sobre `main` y `dev`, `schedule` nocturno y `workflow_dispatch`
- `.github/workflows/ci-pr.yml` con nombre visible `CI PR` para `pull_request` apuntando a `main` o `dev`

Ambos llaman a `.github/workflows/ci-shared.yml`, que contiene la logica real de `guardrails`, `validate` y `build-web`.

También cancela corridas viejas por rama para evitar ruido cuando entran commits nuevos.

Esta separacion es intencional: cuando `dev` tiene una PR abierta a `main`, un mismo commit dispara dos eventos distintos (`push` y `pull_request`). Ahora los nombres visibles en GitHub diferencian mejor cada corrida en vez de verse duplicados opacos.

## Contrato actual

- `guardrails` y `validate` son los dos gates bloqueantes.
- `guardrails` bloquea solo por estructura runtime realmente critica; docs y configuraciones opcionales quedan como warnings o notices.
- `validate` cubre import headless y regresiones jugables/persistencia.
- El recordatorio sobre `wiki/Bitacora.md` sigue siendo asistivo y no rompe la corrida.

## Jobs actuales

### `guardrails`

Este job si bloquea, pero ahora solo por reglas que dependen del repo y rompen de verdad la validacion.

Hoy cubre como bloqueo real:

- estructura runtime minima del proyecto Godot
- entrypoints criticos de la validacion compartida

Como hints no bloqueantes cubre:

- ESLint, pero solo si el repo trae configuracion y lockfile de npm validos
- README, wiki base y `wiki/Getting-Started.md`
- `project/export_presets.cfg`, que solo importa para el export web manual

La idea es que si este job falla, el problema sea atribuible a una deuda real de estructura o calidad del código, no a exportadores ni a tooling lateral.

Dentro de este job también queda un recordatorio no bloqueante cuando cambia `project/` sin actualizar `wiki/Bitacora.md`.

Cuando falla, el propio paso intenta explicar el motivo con mensajes concretos: estructura faltante, ESLint configurado sin `package.json`, lockfile ausente o errores reportados por ESLint.

### `validate`

Este job sí bloquea. Corre dentro de `barichello/godot-ci:4.6.2` y usa la suite compartida `scripts/run-godot-validation.sh`.

En `push`, `schedule` y PRs que tocan `project/` o la propia suite compartida, corre el perfil `full`.

En PRs que solo cambian docs, metadata o infraestructura fuera de `project/`, baja a un perfil `pr-fast` con tres pruebas smoke para no gastar minutos al pedo.

Si el import headless falla en la suite `full`, la CI limpia el estado generado de `project/.godot` (conservando `uid_cache.bin`) y reintenta una sola vez antes de dar la corrida por rota. Eso reduce falsos negativos por cache o estado importado viejo.

Cubre:

- import headless del proyecto
- smoke test de guardado local
- validación de persistencia y perfil
- contrato de señales de `SaveManager`
- migración de saves legacy
- overlay de Archivero
- flujo de Intro para perfil / continuidad
- quick save en niveles

La idea es simple: si falla acá, hay una rotura real en código, escenas o tests del proyecto.

Además, este job sube un artifact `validation-logs-*` con un log combinado y logs separados por paso para que sea evidente si falló el import headless, un test de `SaveManager`, el overlay de Archivero, Intro o quick save.

## Decisiones de fiabilidad

La CI se simplificó con algunos criterios explícitos:

- cache de `project/.godot` con key basada en imports, escenas, recursos y assets fuente relevantes
- cuando una PR toca `project/`, la validación vuelve al perfil `full` y reimporta antes de correr la suite compartida
- si el primer import falla, hay un reintento automatico con limpieza de estado generado para evitar fallas espurias
- sin export web dentro del gate principal
- ESLint solo corre si el repo realmente lo configuró y dejó lockfile determinístico
- dos checks obligatorios y concretos: `guardrails` para roturas estructurales reales y `validate` para roturas funcionales

## Validación local recomendada

Para mantener paridad con CI, conviene correr la misma suite antes de pushear.

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
sh scripts/run-godot-validation.sh --run full godot
```

Si hace falta probar export web, conviene correrlo como validación manual aparte, no como parte del gate principal de CI.

## Cómo leer una corrida

- Si falla `guardrails`, hay un problema de estructura del repo o de calidad de código que sí queremos bloquear.
- Si falla `validate`, rompimos algo real del proyecto.
- Si aparece warning por `wiki/Bitacora.md`, hay una deuda de registro técnico, pero no bloquea merges.

La intención es que la corrida no diga solo "falló": tiene que indicar qué bloque se rompió y darte una pista accionable para empezar a revisar.

## Mantenimiento

Si cambia un flujo importante del juego, lo correcto es sumar o ajustar un test headless en `project/tests/` y mantener `scripts/run-godot-validation.sh` como fuente única de verdad para la validación funcional.

Si el repo incorpora frontend o tooling Node de forma estable, recién ahí conviene endurecer `guardrails` alrededor de ese stack, con lockfile y configuración explícita dentro del repo.
