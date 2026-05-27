    ![alt text](image.png)# Entrega 2 — E-VIDENTE

## Resumen ejecutivo

En esta iteración se consolidó la estética general del juego y se completaron las funcionalidades de polish y nuevas modalidades planificadas en Entrega 1. Se tomó la Opción A de los próximos pasos: profundizar la experiencia dentro del mapa de Celiaquía antes de abrir infraestructura externa. El foco estuvo en transiciones de escena, renovación gráfica completa, felicitaciones por partida perfecta, mensaje de objetivo en la modalidad Arrastre, incorporación de la modalidad Completar Palabra, un efecto typewriter, y la primera infraestructura de testing automatizado con GdUnit4.

## Qué se agregó o modificó

- **Transiciones de escena** — sistema de transiciones suaves entre mapa, partida y resultados via `GameSceneRouter`; pantalla de transición intermedia.
- **Renovación gráfica completa** — nueva estética en intro, selector, mapa, progress bar, pregunta, vincular, completar palabra, lección completa y modalidad arrastre; nueva paleta de colores y título de nivel.
- **Felicitación por partida perfecta** — animación de estrellas y pantalla de cierre con contenedores diferenciados según rendimiento.
- **Mensaje de objetivo en Arrastre** — nuevo componente `DragObjectiveText` que muestra el tipo de comida y restricción al jugador durante la modalidad Arrastre; integrado con TypewriterEffect.
- **TypewriterEffect en preguntas y arrastre** — texto se escribe de forma progresiva para mayor enganche durante la lectura del enunciado.
- **Modalidad Completar Palabra** — nueva modalidad de juego completamente funcional y con nueva gráfica; carga de opciones desde JSON.
- **Tests automatizados con GdUnit4** — primera suite de pruebas unitarias sobre el pipeline de carga de preguntas (8 tests, todos passing).
- **Correcciones de bugs** — compatibilidad de `manager_level.gd` con la nueva escena de arrastre (sprites opcionales), errores de dimensiones en `pregunta.tscn`.

## Decisiones tomadas

- **Priorizar renovación estética** antes que abrir backend o nuevas restricciones alimentarias; la demo necesitaba polish visible.
- **Opción A de Entrega 1** — se completaron UNQ-142, UNQ-111/112/113, UNQ-102, UNQ-95 y UNQ-28.
- **TypewriterEffect como componente reutilizable** — compartido entre pregunta y arrastre sin duplicar código.
- **GdUnit4 como framework de testing** — instalado localmente, ignorado por git; los tests corren en CI.
- **No abrir backend todavía** — la demo sigue corriendo completamente en local; se mantiene sin dependencias externas.

## Desafíos técnicos

- Integrar transiciones de escena sin romper el flujo de carga de actividades ya existente.
- Mantener compatibilidad hacia atrás de `manager_level.gd` cuando Margo eliminó nodos de la escena de arrastre sin actualizar el script.
- Implementar `DragObjectiveText` como componente independiente del contenido hardcodeado, leyendo datos del JSON.
- Incorporar GdUnit4 v6.1.3 correctamente (v6.0.0 de AssetLib era incompatible con Godot 4.6.x).
- Normalizar el formato de datos de la modalidad Completar Palabra para que sea coherente con el resto de los modos vía JSON.

## Trazabilidad commit → ticket

| Commit | Descripción | Ticket(s) |
|---|---|---|
| `01db2dd` | fix(ci): Godot install directo para evitar timeout en pull | CI |
| `73174e4` | Opciones desde JSON (#25) | UNQ-125 |
| `76991a3` | Sistema de transiciones con GameSceneRouter (#26) | UNQ-111, UNQ-112, UNQ-113 |
| `b98b755` | Implementación de estrellas (#27) | UNQ-102, UNQ-101 |
| `48995fe` | Transiciones implementadas | UNQ-111 |
| `cd05ab4` | Transición corregida | UNQ-111 |
| `eacdc56` | Implementación de mensaje Arrastre (#28) | UNQ-142 |
| `93afea4` | Cambios en intro | UNQ-28 |
| `3fef3da` | Cambios en Selector | UNQ-28 |
| `b470dcd` | Mapa con título nuevo | UNQ-28 |
| `87c9ef7` | Progress bar actualizada | UNQ-28 |
| `7b54f54` | Lección completa con nueva gráfica | UNQ-28 |
| `e08982d` | Pregunta con cambios estéticos | UNQ-28 |
| `314088e` | Normalización datos modalidad Completar Palabra | UNQ-95 |
| `e3c7624` | Modificación DragObjectiveText | UNQ-142 |
| `d889d66` | TypewriterEffect en preguntas y arrastre | UNQ-142 |
| `970826f` | Cambios en arrastre (nueva estética) | UNQ-28 |
| `12bb0e0` | Felicitación con estrellas | UNQ-102 |
| `8292e68` | Título de nivel | UNQ-28 |
| `726bd5f` | Finalización de partida con contenedores | UNQ-102 |
| `7ecc60c` | Animación en finalización de partida | UNQ-102 |
| `90e1b99` | Completar palabra con nueva gráfica | UNQ-95 |
| `98d5f25` | Vincular con nueva estética | UNQ-28 |
| `8343778` | Tests de carga JSON con GdUnit4 (#29) | Calidad |
| `f2a8aa8` | fix: sprites opcionales en manager_level | Bug |
| `3820cfe` | fix: dimensiones pregunta y nombres JSON | Bug |

## Alcance de Entrega 2

| Bloque | Resultado | Estado |
|---|---|---|
| Transiciones de escena | Transiciones suaves entre mapa, partida y resultados | Listo |
| Renovación gráfica | Intro, selector, mapa, progreso, pregunta, arrastre, vincular, completar | Listo |
| Felicitación por partida perfecta | Estrellas y pantalla de cierre diferenciada | Listo |
| Mensaje de objetivo en Arrastre | DragObjectiveText con TypewriterEffect | Listo |
| Modalidad Completar Palabra | Nueva modalidad funcional con carga desde JSON | Listo |
| Testing automatizado | GdUnit4 con 8 tests de pipeline de preguntas | Listo |
| Estabilidad y bugs | Compatibilidad arrastre, dimensiones pregunta | Listo |

### Fuera de alcance

Backend, autenticación, leaderboard, base de datos y restricciones alimentarias adicionales (Cetogénica, Veganismo, Vegan-GF) no forman parte de Entrega 2. La demo sigue corriendo completamente en local.

## Documentación

- [User Stories](Entrega-2-User-Stories)
- [Arquitectura](Entrega-2-Arquitectura)
- [Decisiones](Entrega-2-Decisiones)
- [Evidencia](Entrega-2-Evidencia)
- [Próximos Pasos](Entrega-2-Proximos-Pasos)
