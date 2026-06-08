# Entrega 3 — E-VIDENTE

> En curso (jun 2026). Estado vivo: [ESTADO-ACTUAL.md](../ESTADO-ACTUAL.md).

## Resumen ejecutivo

En esta iteración se abrió la infraestructura externa planificada desde Entrega 1: backend Node con PostgreSQL, autenticación y sincronización de progreso, sin reemplazar el save local de Godot. En paralelo se consolidó el mapa de celiaquía como contenido escalable (layout en curva, nodos parametrizados), se reforzó la calidad con smoke test jugable y guardrails de CI, y se avanzó en cuenta de usuario, enseñanzas por JSON y tests de UX/UI para la modalidad Preguntas. La entrega prioriza que el jugador pueda seguir jugando offline y, si quiere, asociar su avance a una cuenta.

## Qué se agregó o modificó

- **Monorepo y backend local** — carpeta `BACKEND/` con API Node, Docker Compose para PostgreSQL, migraciones y documentación unificada.
- **Autenticación y cuenta** — registro, login JWT, perfil de jugador; flujo de Login desde Intro con opción de jugar offline.
- **Sincronización de progreso** — `ProgressSyncService`, cola local, migración del save al iniciar sesión y guardado de resumen de partida en PostgreSQL.
- **Mapa mantenible** — posicionamiento automático de nodos sobre `Path2D` (`placement_mode = anchors`), pipeline `MapLayoutConfig` → `MapBoard`.
- **Partida unificada** — avance hacia un único nodo de partida que admite múltiples modalidades por JSON (UNQ-170).
- **CI estable** — smoke test Godot (`vertical_slice_smoke_test.gd`), validación de estructura del monorepo y trazabilidad documental en PR.
- **Contenido educativo** — desacople de enseñanzas y feedback visual hacia JSON (en curso).
- **Calidad de interfaz** — test automatizado UX/UI de modalidad Preguntas (en curso); borde blanco en sprites de comidas (UNQ-166).
- **Correcciones** — fusión de progreso local/online, rachas, serialización de saves concurrentes, nomenclatura en español en módulos clave.

## Decisiones tomadas

- **Opción B de Entrega 1 (parcial)** — abrir backend y persistencia sin bloquear la demo local.
- **Local-first** — toda partida se guarda primero en Godot; la sync es best-effort con reintento.
- **PostgreSQL solo en desarrollo** — Docker local documentado; sin despliegue productivo en esta entrega.
- **Smoke test como red de seguridad** — Intro → Login → offline → Selector → mapa → partida mínima en cada PR.
- **Perfil y leaderboard fuera del cierre** — diseño de perfil (UNQ-107) e implementación (UNQ-27) siguen pendientes.

## Desafíos técnicos

- Sincronizar progreso local y remoto sin duplicar partidas ni perder nodos completados offline.
- Modelar entidades del jugador en PostgreSQL alineadas al MER sin acoplar Godot a SQL directo.
- Unificar tipos de nodo del mapa sin romper partidas ya configuradas en JSON.
- Mantener CI liviano pero útil en Windows/Linux (import headless, scripts PowerShell y bash).
- Tests de UX/UI en Godot sin depender de interacción humana ni validar reglas pedagógicas profundas.

## Trazabilidad ticket → historia

| Ticket | Título | Historia |
|---|---|---|
| UNQ-85 | Configurar PostgreSQL local con Docker | US-01 |
| UNQ-87 | Validar conexión inicial con PostgreSQL | US-01 |
| UNQ-162 | Modelar entidades principales del jugador | US-01 |
| UNQ-161 | Identificar datos locales críticos a migrar | US-01 |
| UNQ-65 | Diseñar registro de usuario | US-02 |
| UNQ-171 | Diseñar pantalla de login de usuario | US-02 |
| UNQ-90 | Implementar registro de usuario | US-02 |
| UNQ-91 | Implementar login de usuario | US-02 |
| UNQ-160 | Migrar y sincronizar progreso local | US-03 |
| UNQ-163 | Guardar resumen de partida en PostgreSQL | US-03 |
| UNQ-107 | Diseñar pantalla de perfil de usuario | US-04 |
| UNQ-27 | Implementar escena de perfil de usuario | US-04 |
| UNQ-170 | Partidas como nodo único multi-modalidad | US-05 |
| UNQ-167 | Diseñar feedback enseñanzas | US-06 |
| UNQ-168 | Implementar feedback enseñanzas mediante JSON | US-06 |
| UNQ-172 | Test automatizado UX/UI Preguntas | US-07 |
| UNQ-166 | Borde blanco en comidas | US-08 |

## Trazabilidad commit → ticket (muestra)

| Commit | Descripción | Ticket(s) / bloque |
|---|---|---|
| `c3e9d0a` | Setup Docker PostgreSQL (#32) | UNQ-85 |
| `65bf2f1` | Encaminando Entrega 3 (#31) | Infra / mapa |
| `3f458a0` | MapApi, layout y nomenclatura en español | Mapa / US-05 |
| `28e1d0b` | AuthApi, SyncApi e importador de progreso | US-02, US-03 |
| `eb35afa` | Mejorar sincronización local y online | UNQ-160 |
| `51eae03` | Fusionar progreso local y online | UNQ-160 |
| `4def73a` | Login actualizado | UNQ-91, UNQ-171 |
| `80690ab` | Actualizar smoke test | CI |
| `e1f0784` | Solucionando error del mapa | Mapa |

## Alcance de Entrega 3

| Bloque | Resultado | Estado |
|---|---|---|
| Infraestructura PostgreSQL | Docker, conexión, modelo y migraciones | En revisión |
| Cuenta y sesión | Registro, login, diseño de pantallas | En revisión |
| Sync de progreso | Migración local, resumen de partida, cola offline | En revisión |
| Mapa escalable | Layout en curva, contenido JSON | Listo |
| CI y smoke | Flujo mínimo jugable + guardrails monorepo | Listo |
| Nodo único de partida | Multi-modalidad por configuración | En revisión |
| Enseñanzas JSON + feedback | Contenido desacoplado y diseño visual | En curso |
| Tests UX/UI Preguntas | Suite GdUnit4 de interfaz | En curso |
| Perfil dedicado | Diseño + escena completa | Pendiente |
| Polish visual comidas | Borde blanco en sprites | Listo |

### Fuera de alcance (esta entrega)

Leaderboard, refresh token, panel de administración, mails de recuperación reales, validación JSON de contenido en CI, despliegue productivo del backend.

## Bitácora de esta entrega

Detalle cronológico: [Bitacora-Entrega-3.md](Bitacora-Entrega-3)

## Referencia Entrega 2

[Entrega-2](Entrega-2) · [Próximos pasos originales](Entrega-1-Proximos-Pasos) (Opción B en marcha)

## Documentación

- [User Stories](Entrega-3-User-Stories)
- [Evidencia](Entrega-3-Evidencia)
- [Arquitectura](Entrega-3-Arquitectura)
- [Decisiones](Entrega-3-Decisiones)
- [MER persistencia](mer-persistencia-e3) · [Índice MER](MER)
