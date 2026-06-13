# Bitácora — Entrega 3
---

### `2026-06-02` — Backend, sincronización de progreso y guardrails de CI
<kbd>Backend</kbd> <kbd>Godot</kbd> <kbd>CI</kbd>

Se conectó el juego con una primera capa de backend para que el progreso pueda guardarse también en una cuenta. El backend suma persistencia remota, pero no reemplaza el guardado local ni bloquea la experiencia: si el servidor no está disponible, el jugador puede seguir jugando.

**Qué se implementó**
- Backend con migraciones, autenticación, recuperación de contraseña y endpoints de jugador/progreso.
- Cliente Godot para iniciar sesión, restaurar sesión, consultar perfil y sincronizar partidas.
- Cola local de sincronización para conservar resúmenes cuando no hay conexión.
- Ajuste del smoke test para cubrir el flujo real `Intro → Login → jugar offline → Selector`.
- Guardrails de CI para validar estructura mínima del monorepo y documentación del PR.

**Impacto para el jugador**
- Puede jugar sin depender del backend.
- Si inicia sesión, su progreso puede sincronizarse con la cuenta.
- Si hay un problema de red, el progreso queda guardado localmente y se puede reintentar más adelante.

**Evidencia técnica**
- `BACKEND/src/modules/auth/`, `BACKEND/src/modules/player/`, `BACKEND/migrations/`
- `juego/API/backend/`, `juego/interface/auth.gd`
- `juego/tests/vertical_slice_smoke_test.gd`
- `scripts/ci/check-monorepo-infra.ps1`

---

### `2026-06-01` — Validaciones de CI y smoke test jugable
<kbd>Testing</kbd> <kbd>CI</kbd>

Se ordenó la validación automática del proyecto para que cada PR revise dos cosas simples pero críticas: que la documentación tenga trazabilidad y que el juego todavía pueda recorrer su flujo mínimo sin romperse.

**Qué valida**
- El arranque del juego y la navegación principal.
- El paso por Splash, Intro, Selector, Mapa y gameplay.
- Contratos mínimos de escenas y nodos críticos del runtime.
- Cierre de partida y retorno al mapa.

**Qué cubre hoy**
- `Docs / Tracking` — trazabilidad documental en PR.
- `Technical Health` — guardrails de estructura y lint condicional.
- `Gameplay Smoke` — flujo mínimo jugable con import headless y logs.

**Impacto**
- Detecta temprano roturas visibles de navegación.
- Evita merges sin documentación mínima.
- Mantiene un control liviano para iterar rápido sin perder calidad.

**Evidencia técnica**
- `wiki/CI.md`
- `.github/workflows/docs-pr.yml`, `ci.yml`, `gameplay-smoke-pr.yml`
- `juego/tests/vertical_slice_smoke_test.gd`
- `scripts/run-godot-validation.sh`, `scripts/run-godot-validation.ps1`
