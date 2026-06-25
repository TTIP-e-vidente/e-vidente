# Entrega 3 — E-VIDENTE

## Qué se agregó o modificó

- **Backend y PostgreSQL** — Docker Compose, migraciones, MER de usuario/perfil/progreso/partidas/racha; endpoints de auth y progreso documentados en `BACKEND/README.md`.
- **Cuenta y sesión** — registro, login y modo offline en el flujo Intro → Selector; pantallas de auth integradas al juego.
- **Sync de progreso** — merge local/remoto al loguearse, guardado de partida remota al terminar, cola offline y reintento; documentado en [Sync-Godot-Postgres](Sync-Godot-Postgres).
- **Perfil** — edición local de datos de usuario, sync de perfil y avatar; overlay de perfil en el HUD del mapa.
- **Nodo único de partida** — refactor hacia un nodo reutilizable que orquesta modalidades desde JSON del mapa.
- **Enseñanzas JSON** — diseño de feedback y carga parametrizada desde archivos.
- **Tests UX Preguntas** — suite GdUnit4 sobre interfaz visible de la modalidad.
- **Polish comidas** — borde blanco en sprites de alimentos para mejorar lectura en pantalla.

## Desafíos técnicos

- Sincronizar progreso sin duplicar partidas ni perder avance offline (merge, `clientRunId`, cola local).
- Mantener Godot desacoplado de SQL: capa HTTP (`AuthApi`, `SyncApi`) y contrato REST estable.
- Unificar nodos del mapa sin romper el JSON y la demo de Celiaquía ya existente.
- Alinear fechas de racha entre servidor UTC y calendario local del jugador.

## Alcance de Entrega 3

| Bloque                | Resultado                         | Estado |
| --------------------- | --------------------------------- | ------ |
| Infra PostgreSQL      | Docker, migraciones, MER dual     | Listo  |
| Cuenta y sesión       | Registro, login, offline          | Listo  |
| Sync de progreso      | Merge, cola, importador           | Listo  |
| CI y smoke            | Workflow en PR                    | Listo  |
| Nodo único de partida | Refactor mapa / JSON              | Listo  |
| Enseñanzas JSON       | Feedback + carga parametrizada    | Listo  |
| Tests UX Preguntas    | Suite GdUnit4 interfaz            | Listo  |
| Perfil dedicado       | Diseño + overlay; escena completa | Listo  |
| Polish comidas        | Borde en sprites                  | Listo  |

### Fuera de alcance

Leaderboard, refresh token, admin, mails reales de recuperación, validación JSON en CI y deploy productivo del backend.

## Documentación

- [User Stories](Entrega-3-User-Stories)
- [Arquitectura](Entrega-3-Arquitectura)
- [Decisiones](Entrega-3-Decisiones)
- [Evidencia](Entrega-3-Evidencia)
- [Vistas interactivas](Vistas-Interactivas) — diagramas MER y flujo E3
- [Bitácora E3](Bitacora-Entrega-3)

**Siguiente entrega:** [Entrega 4 — Emails y OTP](Entrega-4) · [Guía rápida E4](Entrega-4-Guia-Rapida) · [Flujo E3→E4](Entrega-4-Flujo-E3-E4)
