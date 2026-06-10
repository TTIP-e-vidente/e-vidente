# Decisiones — Entrega 3

## Por dónde arrancamos

En Entrega 1 dejamos escrito que había dos caminos: seguir puliendo en local (Opción A) o abrir infraestructura (Opción B). **Elegimos la B, pero a medias:** backend, PostgreSQL y cuenta, sin sacrificar la demo que ya funcionaba offline.

El sprint de Jira concentra 17 tickets en persistencia, auth, sync, perfil, enseñanzas JSON y calidad automatizada.

---

## Decisiones que tomamos

| Decisión | Por qué | Qué implica | ¿Queda algo? |
|---|---|---|---|
| Save local primero, sync después | El jugador no puede depender del servidor para jugar | Resiliencia ante caídas de red o backend | Mejorar señal UI de estado sync |
| PostgreSQL solo en Docker local | Entorno reproducible para TTIP sin costo de cloud | Cualquier dev levanta la stack con un comando | Deploy productivo |
| 8 user stories para 17 tickets | Misma lógica defendible que E1 y E2 | Documentación clara en TTIP | — |
| Smoke test en cada PR | Detectar roturas de navegación temprano | CI liviano pero útil | Validación JSON contenido |
| Tests UX/UI solo interfaz (UNQ-172) | No falsos negativos en reglas pedagógicas | Evidencia objetiva en Preguntas | Extender a otras modalidades |
| Perfil como escena dedicada | Login/sync eran prioridad en el sprint | Diseño UNQ-107 cerrado; UNQ-27 en progreso | Escena completa |

---

## Cómo movimos las prioridades en el camino

**Subió al tope de la lista:**

- Backend + sync funcionando de punta a punta.
- Login y registro dentro del flujo real del juego.
- Perfil dedicado (diseño cerrado, escena en marcha).
- Smoke test estable.
- Enseñanzas desacopladas y primer test UX/UI.

**Quedó para el cierre del sprint:**

- Escena de perfil completa (implementación UNQ-27).
- UX explícita del estado de sincronización.
- Validación JSON de contenido en CI.
- Leaderboard y admin.

Presentación visual de estas decisiones: [Entrega-3-Presentacion](Entrega-3-Presentacion).
