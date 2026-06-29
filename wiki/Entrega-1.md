# Entrega 1 — E-VIDENTE

> Histórico Entrega 1. Stack actual: [SUPABASE_QUICKSTART](../BACKEND/docs/SUPABASE_QUICKSTART.md).

## Resumen ejecutivo

En esta iteración se consolidó una demo local más completa y clara de E-VIDENTE. Se trabajó sobre el recorrido del jugador, el mapa, modalidades educativas, feedback de progreso, cierre de lección, dificultad progresiva, audio y estabilidad general. La entrega priorizó que el jugador entienda qué hacer, vea su avance y reciba una experiencia más consistente antes de abrir funcionalidades de infraestructura como backend, autenticación.

## Qué se agregó o modificó

- **Mapa y continuidad del recorrido** — actualización visual al completar una partida, lineamiento corregido, rejugar partidas/lecciones habilitado.
- **Modalidades Plato, Pregunta y Vincular** — incorporación de Vincular desde diseño hasta proceso; corrección de errores en Plato y Pregunta.
- **Barra de progreso, racha, EXP y resumen semanal** — feedback visual completo durante y después de cada partida.
- **Pantalla de Lección Terminada** — cierre explícito de cada partida/leccion con sonido diferenciado para partida/leccion perfecto.
- **Contenido desacoplado por JSON** — el contenido de las partidas/lecciones se cargan desde archivos externos, sin hardcodear.
- **Dificultad progresiva** — cada partidas/lecciones pueden configurar un nivel de dificultad; las preguntas de Celiaquía tienen niveles diferenciados.
- **Corrección de bugs** — audio cortado en sesiones largas, reposicionamiento de respuestas incorrectas, errores en modalidades.

## Decisiones tomadas

- **Priorizar demo local en Godot** antes que abrir infraestructura innecesaria (backend, SQL, servicios).
- **Mejorar la experiencia del jugador** mediante progreso visible, suma puntos de EXP, feedback inmediato, racha y mapa actualizados con cierre de partida/leccion.
- **Incorporar y corregir las tres modalidades** (Plato, Pregunta, Vincular) sin abrir flujos paralelos incompletos.
- **Desacoplar contenido via JSON** para poder editar sin tocar scripts.

## Desafíos técnicos

- Integrar niveles en el mapa de Celiaquía de forma totalmente escalable, parametrizada y aleatoria mediante JSON.
- Integrar niveles en la modalidad de Pregunta,Vinculación y Arrastre de forma totalmente escalable, parametrizada y aleatoria mediante JSON.
- Integrar modalidades con dificultad progresiva por nodo sin romper el flujo base de partidas.
- Diseñar la pantalla de cierre de lección de forma que sirva para las tres modalidades.
- Diseñar la pantalla de la modalidad Vinculación 
- Implementar la funcionalidad de Vinculación 
- Diseñar un sistema de puntuación parametrizado y consistente para todas las modalidades de juego.
- Asegurar que el reposicionamiento dinámico de respuestas no genere bugs visuales.

## Trazabilidad ticket → historia

| Ticket | Título | Historia |
|---|---|---|
| UNQ-84 | Actualización visual del mapa | US-01 |
| UNQ-93 | Rejugar lecciones completadas | US-01 |
| UNQ-124 | Corregir lineamiento del Mapa | US-01 |
| UNQ-127 | Modalidad Plato - error | US-02 |
| UNQ-126 | Transparencia Pregunta | US-02 |
| UNQ-60 | Nueva modalidad - vincular | US-02 |
| UNQ-123 | Diseñar modalidad Vincular | US-02 |
| UNQ-128 | Modalidad Vincular - proceso | US-02 |
| UNQ-110 | Niveles de preguntas con dificultad progresiva | US-02 |
| UNQ-89 | Barra de progreso durante partida | US-03 |
| UNQ-121 | Indicador de progreso durante partida | US-03 |
| UNQ-83 | Indicador visual de estado de racha | US-03 |
| UNQ-97 | EXP acumulada | US-03 |
| UNQ-115 | Resumen semanal de progreso | US-03 |
| UNQ-94 | Pantalla de Lección Terminada | US-04 |
| UNQ-118 | Diseñar pantalla de Lección Terminada | US-04 |
| UNQ-116 | Sonido especial por nodo perfecto | US-04 |
| UNQ-100 | Partidas por nodo con modalidades aleatorias | US-05 |
| UNQ-106 | Dificultad progresiva por nodo | US-05 |
| UNQ-119 | Contenido desacoplado mediante JSON | US-05 |
| UNQ-104 | Corregir corte de música | US-05 |
| UNQ-92 | Reposicionamiento dinámico de respuestas | US-05 |

## Alcance de Entrega 1

| Bloque | Resultado | Estado |
|---|---|---|
| Flujo del recorrido | Mapa con partidas jugables, actualización visual, rejugar | Listo |
| Modalidades jugables | Plato, Pregunta y Vincular con dificultad progresiva | Listo |
| Progreso y feedback | Barra de progreso, racha, EXP durante partida | Listo |
| Cierre de lección | Pantalla de lección terminada con sonido especial, exp, precisión, tiempo | Listo |
| Estabilidad y contenido | Audio corregido, contenido desacoplado vía JSON | Listo |

### Fuera de alcance

Backend, autenticación, leaderboard, base de datos, panel de administración no forman parte de Entrega 1. La demo corre completamente en local.

## Documentación

- [User Stories](Entrega-1-User-Stories)
- [Arquitectura](Entrega-1-Arquitectura)
- [Evidencia](Entrega-1-Evidencia)
- [Decisiones](Entrega-1-Decisiones)
