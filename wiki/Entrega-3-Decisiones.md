# Decisiones — Entrega 3

## Criterio general del sprint

Se tomó la Opción B de los próximos pasos de Entrega 1: abrir infraestructura (backend, PostgreSQL, cuenta) sin sacrificar la demo local jugable. El sprint activo en Jira concentra 17 tickets en persistencia, autenticación, sync, mapa escalable, enseñanzas JSON y calidad automatizada.

---

## Decisiones tomadas

| Decisión | Motivo | Impacto | Pendiente |
|---|---|---|---|
| Save local primero, sync después | El jugador no debe depender del servidor para jugar | Resiliencia ante caídas de red o backend | Mejorar señal UI de estado sync |
| PostgreSQL solo en Docker local | Entorno reproducible para TTIP sin costo de cloud | Cualquier dev levanta la stack con un comando | Despliegue productivo |
| Agrupar tickets en 8 user stories | Misma trazabilidad que Entrega 1 y 2 | Documentación defendible en TTIP | No |
| Mapa con `placement_mode = anchors` | Evitar drift de `sample_baked` y posiciones manuales en `.tscn` | Escalar a 30+ nodos editando la curva | No |
| Smoke test en cada PR | Detectar roturas de navegación temprano | CI liviano pero útil | Validación JSON contenido |
| Tests UX/UI acotados a interfaz (UNQ-172) | Evitar falsos negativos en reglas pedagógicas | Evidencia objetiva de modalidad Preguntas | Extender a otras modalidades |
| Perfil dedicado postergado al cierre | Login/sync priorizados en el sprint | UNQ-107 y UNQ-27 siguen Por Hacer | Sí — cierre E3 |

---

## Cambios de prioridad durante el sprint

Se priorizó:

- backend + sync funcionando end-to-end;
- login/registro integrados al flujo real del juego;
- mapa mantenible y smoke test estable;
- desacople de enseñanzas y primer test UX/UI.

Quedó para el cierre:

- pantalla de perfil completa (diseño + implementación);
- UX explícita de estado de sincronización;
- validación JSON de contenido en CI;
- leaderboard y admin.
