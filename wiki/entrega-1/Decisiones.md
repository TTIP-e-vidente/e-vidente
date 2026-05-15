# Decisiones — Entrega 1

> Documento en estado de boceto. La idea es registrar las decisiones tomadas durante el sprint y dejar espacio para completar detalles con el equipo antes de la entrega final.

## Criterio general del sprint

Durante esta iteración se priorizó consolidar una demo local más clara, jugable y defendible. La decisión principal fue enfocar el esfuerzo en mejorar la experiencia visible del jugador antes que abrir funcionalidades de infraestructura como backend, autenticación, leaderboard o servicios remotos.

El objetivo del sprint fue que el jugador pudiera avanzar en el recorrido, resolver modalidades educativas, ver progreso y recibir un cierre más claro al completar una lección.

---

## Decisiones tomadas

| Decisión | Motivo | Alternativa descartada | Impacto | Pendiente |
|---|---|---|---|---|
| Usar nodos como unidad de partida | Permite organizar mejor el recorrido y que cada nodo pueda contener una experiencia jugable | Mantener capítulos o pantallas aisladas sin continuidad | El flujo se vuelve más flexible y más fácil de extender | No |
| Trabajar con tres modalidades: Plato, Pregunta y Vincular | Cada modalidad refuerza el aprendizaje de una forma distinta | Mantener solo una modalidad principal | La demo gana variedad y muestra más valor educativo | No |
| Desacoplar contenido mediante JSON | Facilita agregar o modificar contenido sin tocar lógica interna | Dejar contenido hardcodeado en escenas o scripts | Mejora la mantenibilidad y prepara futuras iteraciones | No |
| Mostrar progreso visible durante la partida | El jugador necesita entender cuánto avanzó y qué logró | Mostrar avance solo al final de la actividad | Mejora claridad, motivación y sensación de avance | No |
| Incorporar racha, EXP o resumen de progreso como motivadores | Ayuda a que el jugador perciba continuidad y recompensa | No mostrar indicadores de motivación | Refuerza la experiencia y el interés por continuar | Revisar alcance final |
| Agregar pantalla de Lección Terminada | Evita que la actividad termine de forma abrupta | Volver directamente al mapa al completar | Mejora el cierre de experiencia y la sensación de logro | No |
| Permitir rejugar lecciones completadas | El jugador puede repasar contenido sin quedar bloqueado | Bloquear nodos ya completados | Mejora la usabilidad y permite repaso educativo | No |
| Corregir problemas visibles antes de sumar más features | La demo debía ser estable para la entrega | Seguir agregando funcionalidades sin cerrar errores | Reduce riesgo durante la presentación | No |
| Priorizar demo local en Godot | El sprint necesitaba foco en gameplay y experiencia visible | Implementar backend o servicios online en esta etapa | Reduce complejidad y mejora chances de llegar con una demo sólida | No |
| Dejar persistencia local completa para revisar | La prioridad fue consolidar flujo, modalidades y feedback | Resolver guardado completo dentro del mismo sprint | Evita abrir un frente técnico grande sin necesidad inmediata | Sí — confirmar para E2 |

---

## Bugs y ajustes que influyeron en decisiones

| Ticket / tema | Problema detectado | Decisión asociada | Impacto |
|---|---|---|---|
| Modalidad Plato - error | La interacción podía generar una experiencia confusa o inconsistente | Priorizar estabilidad de modalidad principal | Mejora la confianza en el gameplay |
| Transparencia Pregunta | La visualización o lectura de la modalidad necesitaba ajuste | Mejorar claridad visual de las modalidades | Reduce fricción al responder |
| Modalidad Vincular - proceso | La nueva modalidad requería ajuste para integrarse mejor al flujo | Integrar modalidades sin crear caminos paralelos | Mantiene una experiencia más ordenada |
| Lineamiento del Mapa | El mapa necesitaba corrección visual o de alineación | Mejorar lectura del recorrido | Hace más claro dónde está el jugador |
| Corte de música en sesiones prolongadas | El audio podía interrumpirse durante sesiones largas | Corregir detalles de polish que afectan la demo | Mejora continuidad y presentación |
| Reposicionamiento de respuestas incorrectas | Las respuestas incorrectas podían repetirse de forma poco dinámica | Mejorar variedad y experiencia durante reintentos | Hace la actividad menos predecible |

---

## Cambios de prioridad durante el sprint

Durante el sprint se decidió priorizar:

- estabilidad del flujo jugable;
- claridad visual del mapa y progreso;
- cierre de lección;
- modalidades educativas funcionales;
- correcciones de bugs visibles.

Quedaron en segundo plano o para revisar después:

- backend;
- autenticación;
- leaderboard;
- administración;
- telemetría;
- persistencia local completa, si no queda confirmada para esta entrega.

---

## Decisiones pendientes de confirmar

- Confirmar si la persistencia local queda dentro de Entrega 1 o pasa formalmente a Entrega 2.
- Confirmar qué parte del resumen semanal de progreso está integrada al flujo real de juego.
- Confirmar si racha y EXP se muestran como feature principal o como mejora complementaria.
- Confirmar evidencia visual final: capturas del mapa, modalidades, progreso y pantalla de lección terminada.
- Confirmar si todas las modalidades quedan incluidas en la demo que se va a mostrar.

---

## Notas para completar con el equipo

- Agregar links a commits o PRs relacionados.
- Adjuntar capturas o mockups si están disponibles.
- Validar con el tutor si la persistencia local debe figurar como terminada o pendiente.
- Revisar si alguna decisión debe pasar a ADR si impacta futuras entregas.
