# Decisiones — Entrega 1

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
| Incorporar racha, EXP o resumen de progreso como motivadores | Ayuda a que el jugador perciba continuidad y recompensa | No mostrar indicadores de motivación | Refuerza la experiencia y el interés por continuar | No |
| Agregar pantalla de Lección Terminada | Evita que la actividad termine de forma abrupta | Volver directamente al mapa al completar | Mejora el cierre de experiencia y la sensación de logro | No |
| Permitir rejugar lecciones completadas | El jugador puede repasar contenido sin quedar bloqueado | Bloquear nodos ya completados | Mejora la usabilidad y permite repaso educativo | No |
| Priorizar demo local en Godot | El sprint necesitaba foco en gameplay y experiencia visible | Implementar backend o servicios online en esta etapa | Reduce complejidad y mejora el enfoque a nuevas implementaciones para llegar con una demo mas sólida | No |
| Dejar persistencia local completa para revisar | La prioridad fue consolidar flujo, modalidades y feedback | Resolver guardado completo dentro del mismo sprint | Evita abrir un frente técnico grande sin necesidad inmediata | No |

---

## Bugs y ajustes que influyeron en decisiones

| Ticket / tema | Problema detectado | Decisión asociada | Impacto |
|---|---|---|---|
| Modalidad Plato - error | La interacción podía generar una experiencia confusa o inconsistente ya que devolvia el item incorrecto automaticamente y no dejaba ver la animacion del personaje | Priorizar estabilidad de modalidad principal | Mejora la confianza en el gameplay |
| Transparencia Pregunta | La visualización o lectura de la modalidad necesitaba ajuste | Mejorar claridad visual de las modalidades | Reduce fricción al responder |
| Modalidad Vincular - proceso | La nueva modalidad requería mas pasos (Cantidad de clicks) para vincular 2 conceptos | Integrar modalidades de forma mas intuitiva | Mantiene una experiencia más ordenada |
| Lineamiento del Mapa | El mapa necesitaba corrección visual o de alineación | Mejorar lectura del recorrido | Hace más claro dónde está el jugador |
| Corte de música en sesiones prolongadas | El audio podía interrumpirse durante sesiones largas | Corregir detalles de polish que afectan la demo | Mejora continuidad y presentación |
| Reposicionamiento de respuestas incorrectas | Las respuestas incorrectas no frenaban la experiencia del juego para que el usuario detecte que su respuesta no fue correcta | Mejora el aprendizaje y experiencia durante reintentos | Hace la actividad menos predecible |

---

## Cambios de prioridad durante el sprint

Durante el sprint se decidió priorizar:

- estabilidad del flujo jugable;
- claridad visual del mapa y progreso;
- cierre de lección;
- modalidades educativas funcionales;
- correcciones de bugs visibles.

Quedaron en segundo plano o para revisar después:

- Backend;
- Autenticación;
- Leaderboard;
- Diseño de perdida de Racha
- Implementar el mapa en las demas restricciones 
- Diseñar el perfil del usuario 

---