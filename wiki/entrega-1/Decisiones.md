# Decisiones tomadas — Entrega 1

| Decisión | Motivo | Alternativa descartada | Impacto |
|---|---|---|---|
| Priorizar demo local en Godot | Entrega 1 necesita una defensa clara y jugable sin abrir infraestructura innecesaria | Presentar backend, servicios online o SQL sin implementación real | El alcance queda más honesto y más fácil de defender |
| Defender el flujo por capítulo antes que el flujo por nodo | El código confirmado muestra capítulos seleccionados desde libros, no un mapa completo implementado en esta rama | Forzar la narrativa de `MapScene.gd` como si ya estuviera cerrada | La arquitectura queda alineada con la evidencia real |
| Usar `Resources .tres` como base de contenido actual | Los capítulos y alimentos ya se modelan mediante `LevelResource`, `LevelItem` e ítems `.tres` | Afirmar que el contenido ya depende de JSON dentro de esta rama | El discurso técnico se simplifica y evita contradicciones |
| Separar "confirmado" de "Falta confirmar" en toda la wiki | Había documentación que mezclaba implementación real con alcance esperado | Mantener un único discurso que sobrevende el estado del proyecto | Mejora la trazabilidad y reduce riesgos en la defensa |
| Mantener un MER lógico y simple | TTIP pide claridad de negocio, no scripts convertidos en tablas | Hacer un DER físico o modelar clases técnicas como entidades | El modelo se entiende mejor y suena menos sobredimensionado |
| Dejar persistencia local como pendiente verificable | La documentación la menciona, pero la implementación explícita no aparece en esta rama | Declararla como completa sin prueba suficiente | Se evita afirmar features no comprobadas |

## Desafíos técnicos y documentales

- Parte de la wiki describe un flujo más amplio que el visible hoy en `project/`.
- Varios archivos mencionados en arquitectura, historias y evidencia no existen en esta rama.
- Fue necesario bajar el nivel de abstracción para que Entrega 1 no parezca una solución más grande de lo que realmente es.

## Evidencia base

- [Bitacora.md](../Bitacora.md)
- [Modelo-Entidad-Relacion.md](../Modelo-Entidad-Relacion.md)
- [project/niveles/global.gd](../../project/niveles/global.gd)
- [project/niveles/manager_level.gd](../../project/niveles/manager_level.gd)
- [project/niveles/nivel_1/Level.gd](../../project/niveles/nivel_1/Level.gd)

## Falta confirmar

- Fecha y rama de consolidación del flujo mapa → nodo → partida por nodo.
- Persistencia local explícita con `SaveManager.gd` o equivalente.
- Modalidades adicionales y su integración final en esta rama.
