# User Stories — Entrega 1

## US-01 — Avanzar en un recorrido educativo

**Actor/es:** Jugador
**Funcionalidad:** Elegir un nodo en el mapa y avanzar dentro del recorrido educativo. El mapa refleja visualmente el progreso y permite rejugar lecciones ya completadas.
**Valor que aporta:** El jugador sabe dónde está, qué puede jugar y siente que su avance queda registrado.

### Criterios de aceptación

- Dado que el jugador está en el mapa, cuando elige un nodo habilitado, entonces puede iniciar y completar esa lección.
- Dado que el jugador completó una partida, cuando vuelve al mapa, entonces esa partida aparece visualmente como terminado.
- Dado que el jugador quiere repasar, cuando elige una partida ya completada, entonces puede rejugarlo sin restricción.


### Tickets relacionados

- UNQ-84 — Implementar actualización visual del mapa al completar un capítulo
- UNQ-93 — Permitir rejugar lecciones completadas del Mapa
- UNQ-124 — Corregir lineamiento del Mapa

### Mockups / evidencia visual

Pendiente de adjuntar captura o mockup.

**Cómo se valida:** se puede iniciar y completar una lección desde el mapa, el nodo queda marcado visualmente como terminado, y se puede rejugar sin restricción.

### Estado

Terminada.

---

## US-02 — Resolver modalidades educativas

**Actor/es:** Jugador
**Funcionalidad:** Resolver actividades interactivas de tipo Plato, Pregunta o Vincular conceptos, con dificultad progresiva y niveles de contenido diferenciados.
**Valor que aporta:** El jugador aprende contenido alimentario mediante interacción, no solo leyendo.

### Criterios de aceptación

- Dado que el jugador inicia una partida, cuando se le presenta una modalidad (Plato, Pregunta o Vincular), entonces puede interactuar y completarla.
- Dado que el jugador responde, cuando la respuesta es incorrecta, entonces la actividad da una señal clara y permite reintentar o continuar.
- Dado que el jugador avanza en nodos, cuando el nodo tiene mayor dificultad configurada, entonces el contenido presentado es más exigente.

### Tickets relacionados

- UNQ-127 — Modalidad Plato - error
- UNQ-126 — Transparencia Pregunta
- UNQ-60 — Implementar nueva modalidad de juego - vincular
- UNQ-123 — Diseñar modalidad de juego - Vincular conceptos
- UNQ-128 — Modalidad Vincular - proceso
- UNQ-110 — Implementar nuevos niveles de preguntas de Celiaquía con dificultad progresiva

**Cómo se valida:** se puede completar una actividad de cada modalidad (Plato, Pregunta, Vincular); la respuesta incorrecta da señal y permite reintentar; nodos de mayor nivel presentan contenido más exigente.

### Estado

Terminada.

---

## US-03 — Ver progreso y motivación durante la partida

**Actor/es:** Jugador
**Funcionalidad:** Ver señales de avance en tiempo real: barra de progreso, estado de racha, EXP acumulada y resumen de progreso semanal.
**Valor que aporta:** El jugador entiende cuánto avanzó dentro de la sesión y siente motivación para continuar.

### Criterios de aceptación

- Dado que el jugador está dentro de una partida, cuando avanza, entonces la barra de progreso se actualiza.
- Dado que el jugador mantiene una racha activa, cuando llega al juego, entonces el indicador de racha refleja su estado actual.
- Dado que el jugador completa un nodo, cuando termina, entonces se le acredita EXP y puede ver cuánto acumuló.

### Tickets relacionados

- UNQ-89 — Implementar barra de progreso durante partida
- UNQ-121 — Diseñar indicador de progreso durante partida
- UNQ-83 — Diseñar indicador visual de estado de racha al ingresar al juego
- UNQ-97 — Implementar experiencia de usuario con EXP acumulada
- UNQ-115 — Implementar resumen semanal de progreso

**Cómo se valida:** la barra de progreso se actualiza durante la partida, el indicador de racha refleja el estado correcto al ingresar, y el EXP se acredita al finalizar el nodo.

### Estado

Terminada.

---

## US-04 — Recibir un cierre claro de lección

**Actor/es:** Jugador
**Funcionalidad:** Ver una pantalla de lección terminada con feedback de resultado, EXP obtenida y, si el nodo fue perfecto, un sonido o señal especial.
**Valor que aporta:** El jugador cierra la actividad con una experiencia completa, sin corte abrupto, y con sensación real de logro.

### Criterios de aceptación

- Dado que el jugador completa todos los pasos de una lección, cuando termina, entonces aparece la pantalla de cierre con el resultado.
- Dado que la pantalla de cierre se muestra, cuando el nodo fue completado de forma perfecta, entonces se reproduce un sonido o efecto diferenciado.
- Dado que el jugador ve la pantalla de cierre, cuando decide continuar, entonces vuelve al mapa sin errores.

### Tickets relacionados

- UNQ-94 — Implementar pantalla de Lección Terminada
- UNQ-118 — Diseñar pantalla de Lección Terminada
- UNQ-116 — Implementar sonido especial por nodo perfecto

**Cómo se valida:** al completar todos los pasos de una lección aparece la pantalla de cierre; si el nodo fue perfecto se reproduce el sonido diferenciado; volver al mapa funciona sin errores.

### Estado

Terminada.

---

## US-05 — Mejorar continuidad, estabilidad y base técnica

**Actor/es:** Jugador / Equipo de desarrollo
**Funcionalidad:** Corregir errores críticos (audio, dificultad, reposicionamiento), desacoplar contenido del código mediante JSON, y sostener partidas por nodo con modalidades aleatorias.
**Valor que aporta:** La demo corre de forma más robusta, el contenido se puede actualizar sin tocar scripts, y la experiencia es más consistente para el jugador.

### Criterios de aceptación

- Dado que el jugador juega una sesión prolongada, cuando el audio termina su loop, entonces no se corta ni genera silencio.
- Dado que el jugador selecciona un nodo, cuando inicia la partida, entonces la modalidad se asigna correctamente con dificultad progresiva.
- Dado que una respuesta incorrecta es reposicionada, cuando el jugador vuelve a verla, entonces aparece en una posición distinta.
- Dado que el contenido de una lección se carga, cuando el sistema lo lee, entonces proviene de un archivo JSON externo, no hardcodeado.

### Tickets relacionados

- UNQ-100 — Implementar partidas por nodo con modalidades aleatorias
- UNQ-106 — Implementar dificultad progresiva por nodo
- UNQ-119 — Implementar contenido desacoplado de nodos mediante JSON
- UNQ-104 — Corregir corte de música durante sesiones prolongadas

**Cómo se valida:** el audio no se corta en sesiones largas; la modalidad se asigna con dificultad progresiva correcta; las respuestas incorrectas se reposicionan al reintentar; el contenido cargado proviene de un archivo JSON externo.

### Estado

Terminada.

---

## Resumen de trabajo realizado en Entrega 1

### Recorrido y mapa

Se actualizó el mapa para reflejar visualmente los nodos completados. Se corrigió el lineamiento visual del mapa que generaba una experiencia confusa. Se habilitó la opción de rejugar lecciones ya terminadas para que el jugador pueda repasar sin restricciones.

### Modalidades educativas

Se incorporó la modalidad Vincular conceptos desde diseño hasta implementación del proceso completo. Se corrigieron errores en la modalidad Plato y se mejoró la transparencia de la modalidad Pregunta para que la interacción sea más clara. Se agregaron niveles de preguntas con dificultad progresiva por nodo.

### Progreso, racha y EXP

Se implementó y diseñó la barra de progreso durante la partida, el indicador de racha al ingresar al juego, la acumulación de EXP al completar nodos y un resumen semanal de progreso. Estas piezas juntas dan al jugador una lectura clara de cuánto avanzó.

### Cierre de lección

Se diseñó e implementó la pantalla de Lección Terminada que aparece al completar un nodo. Se agregó un sonido diferenciado cuando el nodo fue completado de forma perfecta. El jugador ahora tiene un cierre explícito en lugar de volver abruptamente al mapa.

### Estabilidad, audio y base técnica

Se corrigió el corte de música en sesiones largas. Se implementó el reposicionamiento dinámico de respuestas incorrectas para evitar que el jugador memorice posiciones. Se desacopló el contenido del código mediante JSON para facilitar actualizaciones sin recompilar. Las partidas por nodo ahora asignan modalidades con dificultad progresiva configurable.

---

## Bugs y correcciones relevantes

| Ticket | Problema | Corrección | Impacto | Estado |
|---|---|---|---|---|
| UNQ-127 | Error en la modalidad Plato que podía dejar la actividad trabada | Corrección del flujo de validación | La actividad se puede completar sin quedar bloqueada | Resuelto |
| UNQ-124 | Lineamiento visual del mapa roto; los nodos no se leían bien | Corrección del layout del mapa | El recorrido se entiende de un vistazo | Resuelto |
| UNQ-104 | El audio se cortaba en sesiones largas | Corrección del loop de música | El sonido es continuo durante toda la sesión | Resuelto |
| UNQ-92 | Las respuestas incorrectas no se movían; el jugador memorizaba posiciones | Reposicionamiento dinámico de opciones incorrectas | El jugador necesita razonar la respuesta en cada intento | Resuelto |
| UNQ-126 | La modalidad Pregunta no dejaba claro si la respuesta fue correcta o no | Ajuste del feedback visual | El estado de la pregunta se entiende sin ambigüedad | Resuelto |
| UNQ-128 | Inconsistencias en el flujo de la modalidad Vincular | Estabilización del proceso de vinculación | La modalidad se puede completar de punta a punta | Resuelto |

---

## Decisiones tomadas durante la iteración

- **Agrupar tickets en 5 user stories** — evita documentación repetitiva y facilita defender el trabajo como bloques coherentes.
- **Priorizar demo local jugable** — antes de abrir infraestructura online (backend, auth, leaderboard, base de datos real).
- **Mejorar claridad visual y feedback** antes de agregar nuevas pantallas secundarias — el jugador necesita entender qué pasa antes de que haya más contenido.
- **Incorporar modalidades sin romper el flujo principal** — Vincular y Pregunta se integran sobre la misma estructura de partida existente.
- **Desacoplar contenido mediante JSON** — para que futuras iteraciones puedan cambiar niveles y preguntas sin tocar código.
- **Separar bugs de features nuevas** en la trazabilidad — para mostrar que hubo trabajo de estabilización, no solo suma de funcionalidades.

---
