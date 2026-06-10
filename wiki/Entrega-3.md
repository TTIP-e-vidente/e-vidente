# Entrega 3 — E-VIDENTE

> Junio 2026 · Sprint activo en Jira.  
> Si tenés poco tiempo: [Presentación](Entrega-3-Presentacion) → [Cierre / defensa](Entrega-3-Cierre) → [Evidencia](Entrega-3-Evidencia).  
> Vistas interactivas: [Vistas-Interactivas](Vistas-Interactivas)

---

## De qué va esta entrega

En la primera entrega armamos un juego que se podía jugar de punta a punta: mapa, modalidades, save en el disco. En la segunda lo pulimos hasta que se sienta producto — transiciones, estética nueva, más modalidades, primeros tests.

**Esta tercera entrega es el salto:** el juego deja de vivir solo en una máquina. Ahora puede tener cuenta, respaldar el progreso en PostgreSQL y seguir funcionando igual si no hay WiFi.

La idea central es simple y la repetimos en defensa: **primero local, después sync**. Nada de lo que pasa en una partida espera al servidor. Si el jugador quiere, su avance viaja a la nube en segundo plano.

---

## Qué hicimos en concreto

Levantamos un **backend Node** con Docker y migraciones. Integramos **registro y login** en el flujo real del juego, con salida clara para jugar offline. Armamos la **sincronización de progreso**: al loguearse migra el save local; al terminar una partida guarda el resumen remoto; si falla la red, encola y reintenta.

En paralelo avanzamos hacia un **nodo único de partida** que orquesta varias modalidades desde JSON. Sumamos **smoke test en CI** y empezamos **tests de interfaz** para Preguntas. Las **enseñanzas** van desacopladas hacia JSON, con feedback visual ya diseñado.

Para contarlo en la mesa: [Entrega-3-Presentacion](Entrega-3-Presentacion) y el guión de [Cierre](Entrega-3-Cierre).

---

## Cómo viene el sprint (Jira, 10 jun 2026)

Son **17 tickets UNQ** agrupados en **8 historias**. Hoy el tablero muestra **8 terminados**, **6 en revisión** y **3 en progreso**. Las historias más redondas: **cuenta y sesión (US-02)** y **borde en comidas (US-08)**.

El detalle ticket por ticket — siempre actualizado desde Jira — está en [Evidencia](Entrega-3-Evidencia#tickets-jira-del-sprint). Todo cuelga de la epic [UNQ-8](https://tip-unq.atlassian.net/browse/UNQ-8).

---

## Qué nota el jugador (y qué nota el equipo)

**Cuenta:** puede registrarse, loguearse o seguir offline. Su progreso ya no queda atado a un solo dispositivo.

**Sync:** cuando hay sesión, mapa y partidas se respaldan en PostgreSQL sin frenar la partida actual.

**Partidas:** un solo tipo de nodo puede combinar modalidades según el JSON del mapa.

**Calidad:** smoke en cada PR; tests de interfaz en Preguntas en marcha.

**Educación:** enseñanzas editables en archivos JSON, sin tocar código por cada contenido nuevo.

---

## Decisiones que no negociamos

Tomamos la **Opción B** de Entrega 1: abrir backend sin matar la demo local ([Decisiones](Entrega-3-Decisiones)). El save local sigue siendo la fuente inmediata; PostgreSQL corre en Docker para desarrollo, sin prometer producción en esta entrega. El smoke test cubre Intro → Login → offline → mapa → partida mínima en cada PR.

El **perfil dedicado** tiene diseño cerrado; la escena completa sigue en implementación — no es un modal definitivo.

Diagramas para mostrar: [MER persistencia E3](Mer-Persistencia-E3) · [Flujo E1→E3](Mer-Flujo).

---

## Lo que nos costó (y cómo lo resolvimos)

**Sync sin duplicar ni perder offline.** Merge local/remoto, cola con reintento, importador al login. Está en [Sync Godot↔Postgres](Sync-Godot-Postgres) y en `ProgressSyncService` / `ImportadorProgresoOnline`.

**PostgreSQL sin acoplar Godot a SQL.** Capa HTTP (`AuthApi`, `SyncApi`) y MER dual — ver [Mer-Persistencia-E3](Mer-Persistencia-E3).

**Unificar nodos del mapa sin romper celiaquía.** Refactor hacia nodo único (UNQ-170) manteniendo compatibilidad con el JSON actual.

**CI útil pero liviano.** Smoke headless + checks de monorepo en Windows y Linux.

---

## Qué entra y qué no en esta entrega

| Bloque | Dónde estamos |
|---|---|
| Infra PostgreSQL | En revisión |
| Cuenta y sesión | **US-02 lista** |
| Sync de progreso | En revisión |
| CI y smoke | Listo |
| Nodo único de partida | En revisión |
| Enseñanzas JSON | En curso |
| Tests UX Preguntas | En curso |
| Perfil dedicado | En curso (diseño ✅) |
| Polish comidas | **Terminado** |

**Fuera de alcance:** leaderboard, refresh token, admin, mails reales de recuperación, validación JSON en CI, deploy productivo del backend.

---

## Dónde está todo

| Página | Para qué sirve |
|---|---|
| [Presentación](Entrega-3-Presentacion) | Abrir en la defensa — vista clara del sprint |
| [Cierre / defensa](Entrega-3-Cierre) | Guión, checklist, respuestas si preguntan |
| [Evidencia](Entrega-3-Evidencia) | Jira + código + cómo probar |
| [User Stories](Entrega-3-User-Stories) | Historias y criterios de aceptación |
| [Arquitectura](Entrega-3-Arquitectura) | Backend, sync, auth, flujo del jugador |
| [Decisiones](Entrega-3-Decisiones) | Por qué elegimos cada trade-off |
| [Bitácora E3](Bitacora-Entrega-3) | Cronología de cambios |

**Entrega anterior:** [Entrega-2](Entrega-2) · **Contexto Opción B:** [Entrega-1-Proximos-Pasos](Entrega-1-Proximos-Pasos)
