# Decisiones — Entrega 3

## Por dónde arrancamos

Persistencia, auth, sync, perfil, enseñanzas JSON y calidad automatizada.

---

## Decisiones que tomamos

| Decisión | Por qué | Qué implica | ¿Queda algo? |
|---|---|---|---|
| Save local primero, sync después | El jugador no puede depender del servidor para jugar | Resiliencia ante caídas de red o backend | Mejorar señal UI de estado sync |
| PostgreSQL solo en Docker local | Entorno reproducible para TTIP sin costo de cloud | Cualquier dev levanta la stack con un comando | Deploy productivo |
| Smoke test en cada PR | Detectar roturas de navegación temprano | CI liviano pero útil | Validación JSON contenido |
| Tests UX/UI solo interfaz (UNQ-172) | No falsos negativos en reglas pedagógicas | Evidencia objetiva en Preguntas | Extender a otras modalidades |
| Perfil como escena dedicada | Login/sync eran prioridad en el sprint | Diseño UNQ-107 cerrado | Escena completa |

---

## Cómo movimos las prioridades en el camino

- Backend + sync funcionando de punta a punta.
- Login y registro dentro del flujo real del juego.
- Perfil dedicado (diseño cerrado, escena en marcha).
- Smoke test estable.
- Enseñanzas desacopladas y primer test UX/UI
- Escena de perfil completa.
- UX explícita del estado de sincronización.
- Validación JSON de contenido en CI.
- Leaderboard y admin.

Diagramas interactivos de estas decisiones: [Vistas-Interactivas](Vistas-Interactivas) · [Mer-Flujo](Mer-Flujo) · [Mer-Persistencia-E3](Mer-Persistencia-E3).
