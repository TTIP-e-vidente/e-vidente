# Entrega 1 — E-VIDENTE

## Resumen ejecutivo

En esta iteración se consolidó una demo local jugable centrada en un flujo simple y defendible: elegir un capítulo, resolver una actividad de arrastre, recibir una enseñanza al completar la actividad y ver el avance reflejado en el desbloqueo secuencial del recorrido.

El valor de Entrega 1 está en mostrar una base jugable clara, con contenido cargado desde `Resources .tres` y reglas de progreso visibles en código. No se presenta como una solución enterprise ni como una arquitectura cerrada de producción: backend, base de datos real, autenticación online, leaderboard y servicios remotos quedan fuera de alcance.

También se ordenó la documentación para distinguir entre dos niveles de evidencia: lo que está confirmado por archivos presentes en esta rama y lo que todavía aparece en wiki o Bitácora pero quedó marcado como "Falta confirmar".

## Alcance de Entrega 1

### Confirmado en esta rama

| Área | Resultado | Evidencia |
|---|---|---|
| Gameplay base | Selección de capítulo y desafío de arrastre | [entrega-1/User-Stories.md](entrega-1/User-Stories.md) |
| Contenido | Uso de `LevelResource`, `LevelItem` y archivos `.tres` | [entrega-1/Evidencia.md](entrega-1/Evidencia.md) |
| Progreso visible | Desbloqueo secuencial de capítulos completados | [entrega-1/Casos-de-Uso.md](entrega-1/Casos-de-Uso.md) |
| Cierre pedagógico | Enseñanza asociada al capítulo completado | [entrega-1/User-Stories.md](entrega-1/User-Stories.md) |
| Trazabilidad | MER, arquitectura y decisiones alineadas al código real | [entrega-1/Arquitectura.md](entrega-1/Arquitectura.md) |

### Documentado pero falta confirmar en esta rama

| Tema | Estado |
|---|---|
| Flujo `MapScene.gd` → nodo jugable → partida por nodo | Falta confirmar |
| Persistencia local con `SaveManager.gd` | Falta confirmar |
| Modalidades `pregunta.gd` y `vincular_conceptos.gd` | Falta confirmar |
| Carga de contenido por JSON dentro de `project/` | Falta confirmar |

## Documentación de la entrega

- [User Stories](entrega-1/User-Stories.md)
- [Casos de Uso](entrega-1/Casos-de-Uso.md)
- [Arquitectura de Entrega 1](entrega-1/Arquitectura.md)
- [Evidencia](entrega-1/Evidencia.md)
- [Decisiones tomadas](entrega-1/Decisiones.md)
- [Próximos pasos](entrega-1/Proximos-Pasos.md)

## Relación con documentación general

- [MER lógico](Modelo-Entidad-Relacion.md)
- [MR lógico](entrega-1/Modelo-Relacional.md)
- [Arquitectura general](Architecture.md)
- [Bitácora](Bitacora.md)
- [CI](CI.md)

## Estado del MER para defensa

Para TTIP conviene defender un MER lógico simple, centrado en `RECORRIDO`, `CAPITULO`, `DESAFIO_ARRASTRE`, `ITEM_ARRASTRABLE`, `CONDICION_DIETETICA` y `ENSENANZA`. Las entidades de persistencia local, mapa, nodo jugable y modalidades adicionales siguen documentadas, pero marcadas como "Falta confirmar" cuando no hay archivo verificable en esta rama.

## Pendientes realistas para Entrega 2

- Confirmar o descartar el flujo `MapScene.gd` y los componentes de partida por nodo si viven en otra rama.
- Incorporar evidencia visual de la demo: capturas o video corto.
- Definir si habrá persistencia local real o si por ahora alcanza con progreso en memoria durante la sesión.
- Evaluar si `Pregunta` y `VinculacionConceptos` entran en el alcance consolidado o quedan como siguiente iteración.

## Pendientes antes de mostrar al tutor

- [ ] Llevar capturas de pantalla del flujo confirmado: selección de capítulo, actividad, enseñanza y retorno.
- [ ] Verificar manualmente que el MER y el MR no afirmen implementación SQL ni backend.
- [ ] Revisar que todo lo no comprobado siga marcado como "Falta confirmar".
- [ ] Tener preparada una explicación breve de por qué Entrega 1 es una demo local en Godot y no una plataforma online.
