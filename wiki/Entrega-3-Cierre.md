# Cierre y defensa — Entrega 3

> Esto es el guión para la mesa TTIP. Los números vivos están en [Evidencia](Entrega-3-Evidencia) (sync Jira 10 jun 2026).

---

## Los cinco minutos que importan

Empezá contando la historia, no la tabla de tickets.

Primero hicimos que el juego **funcione y se vea bien en local**. Después **sumamos modalidades y polish**. En esta entrega abrimos **cuenta y persistencia remota** — pero sin sacarle al jugador la opción de jugar offline.

La frase que cierra bien: **“local-first con sync opcional”**. Todo se guarda primero en Godot. Si hay sesión y backend, el progreso viaja a PostgreSQL en segundo plano, sin que el jugador espere.

**Orden sugerido en pantalla:**

1. [Presentación visual](Entrega-3-Presentacion) — números y historias de un vistazo.
2. [Flujo E1→E3](Mer-Flujo) — cómo evolucionó dónde guardamos el progreso.
3. **Demo en vivo** — Intro → login u offline → mapa → partida → cierre.
4. [Evidencia](Entrega-3-Evidencia) — ticket ↔ historia con estado real de Jira.

---

## Cuándo damos por cerrada cada historia

| US | Tiene que estar true… | Hoy (jun 2026) |
|---|---|---|
| **US-01** | Docker levanta Postgres; migraciones aplican; MER documentado; relevamiento local hecho | En revisión — UNQ-161 ✅ |
| **US-02** | Registro, login, diseño y offline end-to-end | **Lista** — 4/4 tickets ✅ |
| **US-03** | Migración al login, partida remota, cola offline | En revisión |
| **US-04** | Diseño aprobado + escena con métricas y “continuar” | En curso — diseño ✅ |
| **US-05** | Un nodo orquesta modalidades por JSON | En revisión |
| **US-06** | Enseñanzas y feedback desde JSON | En curso — diseño ✅ |
| **US-07** | Test GdUnit4 Preguntas pasa y se ve en CI | En curso |
| **US-08** | Comidas legibles con contorno | **Terminada** ✅ |

Detalle: [Entrega-3-Evidencia](Entrega-3-Evidencia).

---

## Antes de entrar a la defensa

### Demo

- [ ] Backend arriba (`docker compose up` en `BACKEND/`) — o explicar que offline también vale.
- [ ] Smoke verde: `vertical_slice_smoke_test.gd`.
- [ ] Mapa celiaquía con al menos dos modalidades distintas.
- [ ] Login con cuenta de prueba → el progreso local no se pierde.
- [ ] Backend apagado → se juega igual → al volver, sync reintenta.

### Documentación

- [ ] [Entrega-3](Entrega-3) como hilo narrativo.
- [ ] [User Stories](Entrega-3-User-Stories) a mano por si piden criterios.
- [ ] [MER persistencia E3](Mer-Persistencia-E3) abierto para preguntas de modelo.
- [ ] [Decisiones](Entrega-3-Decisiones) por si preguntan trade-offs.

### Jira

- [ ] Tablero alineado con [Evidencia](Entrega-3-Evidencia#tickets-jira-del-sprint).
- [ ] Tickets en Revisión con link a PR, wiki o demo.
- [ ] Epic [UNQ-8](https://tip-unq.atlassian.net/browse/UNQ-8) visible.

---

## Si preguntan…

**“¿Por qué no reemplazaron el save local?”**  
Porque el juego tiene que correr en aula, feria o demo sin WiFi. PostgreSQL suma continuidad entre dispositivos; no reemplaza jugar offline.

**“¿Qué pasa si falla el sync?”**  
El jugador no lo siente en gameplay. La cola local guarda pendientes y reintenta cuando hay sesión y red. [Sync Godot↔Postgres](Sync-Godot-Postgres).

**“¿Qué quedó afuera?”**  
Leaderboard, refresh token, admin, mails reales y deploy productivo. Está explícito en [Entrega-3](Entrega-3).

**“¿Cómo saben que no rompieron nada?”**  
Smoke en cada PR + suite GdUnit4 (Preguntas en UNQ-172). [CI](CI).

---

## Lo que conviene decir con honestidad

| Tema | Qué tenemos hoy |
|---|---|
| Edge cases en merge local/online | `ProgressSyncService`, importador, fixes en bitácora |
| Perfil completo | Diseño cerrado (UNQ-107); escena UNQ-27 en progreso |
| Tickets en Revisión | Evidencia en repo + demo; pedir cierre formal post-defensa |
| Backend en producción | Solo Docker local documentado — sin prometer cloud |

---

## Links rápidos

| Recurso | Link |
|---|---|
| Presentación | [Entrega-3-Presentacion](Entrega-3-Presentacion) |
| Resumen | [Entrega-3](Entrega-3) |
| Evidencia + Jira | [Entrega-3-Evidencia](Entrega-3-Evidencia) |
| Historias | [Entrega-3-User-Stories](Entrega-3-User-Stories) |
| MER / flujo | [Mer-Hub](Mer-Hub) · [Mer-Flujo](Mer-Flujo) |
| Jira | [tip-unq.atlassian.net](https://tip-unq.atlassian.net/jira/software/projects/UNQ/boards) |
