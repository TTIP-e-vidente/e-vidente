# Próximos Pasos
## Para Entrega 2

> Planificación original. Backend ya avanzó — [ESTADO-ACTUAL.md](../ESTADO-ACTUAL.md).

Ir mejorando de a poco los diseños, movimientos, experiencia a nivel gráfico del juego, pequeños pasos en cada Entrega. 


```
                    ┌─────────────────────────────┐
                    │       Entrega 2 - Inicio    │
                    └──────────────┬──────────────┘
                                   │
        ┌──────────────────────────┼──────────────────────────┐
        │                          │                          │
        ▼                          ▼                          ▼
┌──────────────────────┐ ┌──────────────────────┐ ┌────────────────────────┐
│  Opción A            │ │  Opción B            │ │  Opción C              │
│  Funcionalidades en  │ │  Implementar         │ │  Implementar todo en   │
│  el mapa de Celiaquía│ │  el Backend          │ │  las otras restricc. A.│
└──────────────────────┘ └──────────────────────┘ └────────────────────────┘
```

---

## Opción A — Seguir con funcionalidades en el mapa de Celiaquía

Profundizar la experiencia de juego dentro del mapa de Celiaquía ya existente: nuevas modalidades, mensajes, transiciones y feedback visual. No requiere infraestructura externa.

| ID | Tarea |
|----|-------|
| UNQ-125 | Parametrizar los niveles según la modalidad |
| UNQ-102 | Implementar felicitación por lección perfecta |
| UNQ-101 | Implementar felicitación por completar 3 modalidades sin errores (dentro de UNA partida) |
| UNQ-142 | Implementar Mensaje de Plato con el tipo de comida y restricción al que pertenece |
| UNQ-149 | Implementar Mensaje de Pérdida de Racha |
| UNQ-28  | Implementar feedback layer visual |
| UNQ-111 | Implementar transición suave de mapa a partida |
| UNQ-112 | Implementar transición suave de partida a resultados |
| UNQ-113 | Implementar transición suave de resultados a mapa |
| UNQ-95  | Implementar nueva modalidad de juego — completar con opciones de palabras |
| UNQ-99  | Implementar nueva modalidad de juego — selector de imágenes |
| UNQ-98  | Implementar nueva modalidad de juego — escala de opciones |

---

## Opción B — Implementar el Backend

Construir la infraestructura de usuarios, autenticación y persistencia remota. Habilita funcionalidades sociales y progreso multi-dispositivo.

> Base ya disponible: UNQ-85 (PostgreSQL con Docker), UNQ-87 (conexión validada), UNQ-86 (modelo inicial de persistencia) ✓

| ID | Tarea |
|----|-------|
| UNQ-90 | Implementar registro de usuario |
| UNQ-91 | Implementar login de usuario |
| UNQ-27 | Implementar escena de perfil de usuario |
| UNQ-69 | Implementar cambio de contraseña del usuario |
| UNQ-96 | Implementar tabla de posiciones global |
| UNQ-64 | Implementar notificaciones por email para racha diaria en riesgo |


---

## Opción C - Implementar lo generado en Celiaquía en las demás restricciones

Pasar todas las modalidades a las demás restricciones, con nuevos mapas, preguntas, etc. 

| ID | Tarea |
|----|-------|
| UNQ-72 | Implementar mapa para temática Cetogénica |
| UNQ-129 | Implementar json para arrastre Cetogénica |
| UNQ-130 | Implementar json para vincular Cetogénica |
| UNQ-131 | Implementar json para preguntas Cetogénica |
| UNQ-81 | Implementar mapa para temática Veganismo |
| UNQ-132 | Implementar json para arrastre Veganismo |
| UNQ-133 | Implementar json para vincular Veganismo |
| UNQ-134 | Implementar json para preguntas Veganismo |
| UNQ-82 | Implementar mapa para temática Vegan - GF |
| UNQ-135 | Implementar json para arrastre Vegan - GF |
| UNQ-136 | Implementar json para vincular Vegan - GF |
| UNQ-137 | Implementar json para preguntas Vegan - GF |
