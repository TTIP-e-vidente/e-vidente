# User Stories — Entrega 1

## Resumen

Estas historias fueron simplificadas para que reflejen el alcance real y defendible de la demo. La prioridad no es mostrar una plataforma completa, sino una base jugable clara, con evidencia concreta en código y sin inventar componentes no confirmados.

## US-01 — Elegir un capítulo jugable

**Actor:** Jugador  
**Funcionalidad:** Seleccionar un capítulo habilitado desde el recorrido.  
**Valor:** Entrar al juego de forma simple y entender qué contenido puede jugar.

### Criterios de aceptación

- Dado un recorrido disponible,
- Cuando el jugador abre el libro correspondiente,
- Entonces puede seleccionar un capítulo habilitado.

### Evidencia

- [project/interface/libro.gd](../../project/interface/libro.gd)
- [project/interface/libro-vegan.gd](../../project/interface/libro-vegan.gd)
- [project/interface/Libro-Vegan-GF.gd](../../project/interface/Libro-Vegan-GF.gd)
- [project/niveles/global.gd](../../project/niveles/global.gd)

### Estado

Confirmada.

## US-02 — Resolver un desafío de arrastre

**Actor:** Jugador  
**Funcionalidad:** Completar una actividad de clasificación de alimentos.  
**Valor:** Aprender contenido alimentario mediante una interacción directa.

### Criterios de aceptación

- Dado un capítulo activo,
- Cuando el jugador arrastra ítems al área de juego,
- Entonces la actividad valida la acción y permite completar el desafío.

### Evidencia

- [project/niveles/nivel_1/Level.gd](../../project/niveles/nivel_1/Level.gd)
- [project/niveles/manager_level.gd](../../project/niveles/manager_level.gd)
- [project/resources/level_resource.gd](../../project/resources/level_resource.gd)
- [project/resources/level_item.gd](../../project/resources/level_item.gd)
- [project/items/ItemLevel.gd](../../project/items/ItemLevel.gd)

### Estado

Confirmada.

## US-03 — Ver el progreso del recorrido

**Actor:** Jugador  
**Funcionalidad:** Reconocer qué capítulos completó y cuáles siguen disponibles.  
**Valor:** Entender su avance sin necesitar infraestructura adicional.

### Criterios de aceptación

- Dado un capítulo completado,
- Cuando el jugador vuelve al libro,
- Entonces el estado de desbloqueo refleja el avance alcanzado.

### Evidencia

- [project/niveles/global.gd](../../project/niveles/global.gd)
- [project/interface/libro.gd](../../project/interface/libro.gd)
- [project/niveles/nivel_1/Level.gd](../../project/niveles/nivel_1/Level.gd)

### Estado

Confirmada.

## US-04 — Recibir un cierre pedagógico al terminar

**Actor:** Jugador  
**Funcionalidad:** Ver una enseñanza asociada al capítulo al completar la actividad.  
**Valor:** Vincular el resultado del juego con el contenido educativo.

### Criterios de aceptación

- Dado un capítulo resuelto correctamente,
- Cuando el jugador llega al cierre de la actividad,
- Entonces se muestra una enseñanza antes de continuar.

### Evidencia

- [project/niveles/nivel_1/Level.gd](../../project/niveles/nivel_1/Level.gd)
- [project/niveles/ensenanzas.gd](../../project/niveles/ensenanzas.gd)
- [project/niveles/ensenanzaveganismo.gd](../../project/niveles/ensenanzaveganismo.gd)

### Estado

Confirmada.

## US-05 — Retomar progreso local entre sesiones

**Actor:** Jugador  
**Funcionalidad:** Recuperar avance guardado al volver a entrar.  
**Valor:** No perder contexto entre partidas.

### Criterios de aceptación

- Dado un progreso guardado localmente,
- Cuando el jugador vuelve a abrir la demo,
- Entonces puede continuar desde un estado previo.

### Evidencia

- [Bitacora.md](../Bitacora.md)
- [Persistencia-Local.md](../Persistencia-Local.md)

### Estado

Falta confirmar.

Motivo: en esta rama no se encontró `SaveManager.gd` ni otra implementación verificable de persistencia local explícita.

## US-06 — Abrir un nodo y recorrer juegos internos

**Actor:** Jugador  
**Funcionalidad:** Iniciar un nodo jugable que organice varias modalidades.  
**Valor:** Tener una experiencia más cercana al recorrido completo planteado en producto.

### Criterios de aceptación

- Dado un nodo del mapa,
- Cuando el jugador lo abre,
- Entonces puede atravesar una secuencia de juegos internos hasta completar el nodo.

### Evidencia

- [Bitacora.md](../Bitacora.md)
- [Architecture.md](../Architecture.md)

### Estado

Falta confirmar.

Motivo: los componentes técnicos citados en la wiki para este flujo no están presentes en `project/` dentro de esta rama.

Falta confirmar:
- Referencia formal de ticket o ID externo del bug.

## US-09 — Validaciones CI / smoke

**Como** equipo de desarrollo,  
**quiero** validar el flujo mínimo jugable de forma automática,  
**para** reducir el riesgo de romper la demo.

### Descripción

Se consolidó un esquema de CI por objetivos con un smoke test enfocado en el recorrido crítico.

### Valor que aporta

Detecta regresiones tempranas en navegación y apertura de gameplay antes de mergear.

### Criterios de aceptación

- Dado un cambio en pull request,
- Cuando corren los workflows de validación,
- Entonces se ejecutan checks de documentación, salud técnica y flujo jugable mínimo.

### Evidencia

- [Bitacora.md](../Bitacora.md)
- [CI.md](../CI.md)
- [.github/workflows/docs-pr.yml](../../.github/workflows/docs-pr.yml)
- [.github/workflows/ci.yml](../../.github/workflows/ci.yml)
- [.github/workflows/gameplay-smoke-pr.yml](../../.github/workflows/gameplay-smoke-pr.yml)
- [project/tests/vertical_slice_smoke_test.gd](../../project/tests/vertical_slice_smoke_test.gd)

### Estado

Parcial.

Falta confirmar:
- Fecha de consolidación final del esquema de workflows actual.
