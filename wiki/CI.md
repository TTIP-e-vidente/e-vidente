# CI Pipeline

La CI está pensada para cortar roturas reales del proyecto, no para meter ruido por cualquier detalle accesorio.

## Qué corre y cuándo

Hay dos workflows visibles:

- `.github/workflows/ci.yml` para `push` a `main`, `dev`, `feat/**`, `feature/**`, además de `schedule` y `workflow_dispatch`
- `.github/workflows/ci-pr.yml` para `pull_request` hacia `main` o `dev`

Los dos llaman a `.github/workflows/ci-shared.yml`, que es donde vive la lógica real.

Las ramas feature también corren CI en `push` para detectar problemas antes de llegar a `dev`.

La validación sigue siendo diff-aware:

- si se toca `project/` o la suite compartida, corre `full`
- si el cambio es de docs o infraestructura liviana, baja a `pr-fast`

También se cancelan corridas anteriores de la misma rama para no acumular checks viejos.

## Gates

- `guardrails` y `validate` son los checks que bloquean
- `guardrails` corta por estructura crítica o problemas concretos de setup
- `validate` corta por errores reales del juego, escenas o persistencia
- el recordatorio sobre `wiki/Bitacora.md` no bloquea

## `guardrails`

Este job bloquea solo por cosas que realmente dejan al repo en mal estado para validar o ejecutar.

Hoy chequea como bloqueo real:

- estructura mínima del proyecto Godot
- entrypoints críticos de la validación compartida

Y deja como aviso no bloqueante:

- ESLint, pero solo si hay configuración y lockfile válidos
- `README.md`, `wiki/Home.md`, `wiki/Getting-Started.md` y `wiki/Bitacora.md`
- `project/export_presets.cfg`, porque solo importa para el export web manual

Si este job falla, debería haber un motivo concreto: falta algo runtime, falta configuración necesaria o hay una falla real del tooling que sí usamos.

## `validate`

Este job corre en `barichello/godot-ci:4.6.2` y usa `scripts/run-godot-validation.sh`.

Reglas actuales:

- `full` en `schedule`, `workflow_dispatch` y en cambios que tocan `project/` o la suite compartida
- `pr-fast` cuando el cambio no afecta runtime ni tests principales

Si el import headless falla en `full`, la CI limpia el estado generado de `project/.godot` y reintenta una vez, conservando `uid_cache.bin`.

Cubre:

- import headless del proyecto
- integración entre catálogo, libros y niveles de todos los tracks
- smoke test de guardado local
- validación de persistencia y perfil
- contrato de señales de `SaveManager`
- migración de saves legacy
- overlay de Archivero
- flujo de Intro para perfil y continuidad
- quick save en niveles
- suficiencia real de pools por categoría para cada corrida del catálogo

Si falla este job, hay una rotura real que conviene arreglar antes de mergear.

Además sube un artifact `validation-logs-*` con un log general y logs separados por paso.

## Decisiones de fiabilidad

- cache de `project/.godot` basada en imports, escenas, recursos y assets relevantes
- cuando una PR toca `project/`, la validación vuelve a `full`
- si el primer import falla, hay un reintento con limpieza del estado generado
- el export web quedó fuera del gate principal
- ESLint solo corre si el repo realmente lo usa de forma determinística

## Validación local

Para probar lo mismo que corre en CI:

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

El export web conviene dejarlo como verificación manual aparte.

## Cómo leer una corrida

- si falla `guardrails`, revisar estructura del repo o setup
- si falla `validate`, revisar código, escenas, recursos o tests
- si aparece warning por `wiki/Bitacora.md`, es deuda de documentación, no un bloqueo

## Mantenimiento

Si cambia un flujo importante del juego, hay que sumar o ajustar un test en `project/tests/` y mantener `scripts/run-godot-validation.sh` como punto único de entrada para la validación funcional.

Si más adelante el repo incorpora un stack Node estable, ahí sí vale la pena endurecer `guardrails` alrededor de ese tooling.
