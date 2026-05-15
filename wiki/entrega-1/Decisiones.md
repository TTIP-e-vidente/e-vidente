# Decisiones — Entrega 1

| Decisión | Motivo | Alternativa descartada | Impacto |
|---|---|---|---|
| Usar nodos del mapa como unidad de partida | El flujo mapa → nodo → modalidad es más flexible que capítulos fijos | Mantener el flujo por capítulo/libro de la POC | Permite agregar o quitar nodos sin romper el flujo base |
| Implementar tres modalidades (Plato, Pregunta, Vincular) | Cubrir distintos tipos de aprendizaje con la misma estructura de partida | Una sola modalidad para simplificar | Mayor variedad jugable; mayor complejidad de integración |
| Desacoplar contenido del código | El contenido en archivos externos permite editar sin recompilar | Contenido hardcodeado en scripts | Más fácil de escalar; requiere validación del formato JSON |
| Agregar sistemas de progreso visibles (racha, EXP, barra) | El jugador necesita feedback inmediato para sentir avance | Mostrar solo puntaje al final | Mejora la experiencia; añade lógica de estado adicional |
| Priorizar estabilidad sobre nuevas features | Entrega 1 requiere una demo defendible | Agregar más modalidades sin estabilizar las existentes | Demo más sólida; persistencia local queda como pendiente |

## Falta confirmar

- Persistencia local entre sesiones con SaveManager.
- Integración completa del resumen semanal dentro del flujo.
