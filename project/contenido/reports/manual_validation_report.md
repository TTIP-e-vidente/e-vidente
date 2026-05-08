# Manual Validation Report

Fecha: 2026-05-08

Scope validado en esta fase:
- flujo congelado para demo documentado
- mapa expandido de 18 a 30 nodos
- nuevos pools de quiz, match y drag validados por JSON
- polish visual/UX selectivo en drag, enseñanza, match y mapa
- smoke end to end actualizado con nodos 19, 25 y 30

## Estado final

- El flujo de contenido/mapa quedó congelado y documentado en `project/README.md`.
- El mapa de celiaquía quedó en 30 nodos jugables sin cambios de arquitectura.
- La validación barata de contenido terminó en `CONTENT_VALIDATION=OK`.
- El smoke real de vertical slice terminó en `SMOKE_EXIT=0`.

Comandos de validación usados:

```powershell
$map = Get-Content -Raw 'project/contenido/mapa/celiaquia_mapa.json' | ConvertFrom-Json
$quiz = Get-Content -Raw 'project/contenido/mapa/preguntas.json' | ConvertFrom-Json
$match = Get-Content -Raw 'project/contenido/mapa/vinculaciones.json' | ConvertFrom-Json
$drag = Get-Content -Raw 'project/contenido/mapa/arrastres.json' | ConvertFrom-Json
# validación de conteos, shape del JSON y cobertura exacta de requests random
```

```powershell
& 'C:/Users/Equipo/AppData/Local/Programs/GodotCLI42/Godot_v4.2.2-stable_win64_console.exe' --headless --path project -s res://tests/vertical_slice_smoke_test.gd
```

## Flujo congelado

Regla de esta etapa:
- El JSON manda.
- Los scripts sólo traducen ese JSON a una partida jugable.
- No se tocaron loaders ni `ActivityAdapter` en esta fase.

Flujo operativo congelado:
1. `CargadorDeMapa` lee `res://contenido/mapa/celiaquia_mapa.json`.
2. `MapNodeData` representa cada nodo.
3. `ArmadorDePartida` arma el plan final del nodo.
4. `NodeContentLoader` busca la activity.
5. `ActivityAdapter` adapta al minijuego runtime.
6. `AbridorDeNodoJugable` abre el game actual.
7. `ContinuidadDePartidaDeNodo` avanza o completa el nodo.
8. `AvanceDeNodo` persiste el progreso.

## Expansión del mapa

Mapa actual:
- 30 nodos
- `MapLoad nodes=30`

Nodos nuevos agregados:
- `celiaquia_19_cocina_segura`
- `celiaquia_20_contaminacion_cruzada`
- `celiaquia_21_utensilios_y_cocina`
- `celiaquia_22_comer_fuera`
- `celiaquia_23_restaurante_seguro`
- `celiaquia_24_productos_industriales`
- `celiaquia_25_etiquetas_y_trazas`
- `celiaquia_26_decisiones_confusas`
- `celiaquia_27_riesgos_ocultos`
- `celiaquia_28_desafio_integrador_1`
- `celiaquia_29_desafio_integrador_2`
- `celiaquia_30_desafio_final_extendido`

Soporte visual del mapa:
- `MapBoard.tscn` pasó a 30 slots visibles.
- se agregaron los nodos visuales 27, 28, 29 y 30.
- se amplió el alto del contenido scrolleable.
- se reforzó el contraste entre nodo disponible, completado y bloqueado.

## Contenido agregado

Conteos finales validados:
- quizzes: 22
- arrastres: 16
- vinculaciones: 12

Quizzes nuevos:
- `quiz_trazas_gluten`
- `quiz_restaurante_preguntar`
- `quiz_aceite_compartido`
- `quiz_salsa_soja`
- `quiz_rotulo_preventivo`
- `quiz_producto_artesanal`
- `quiz_freidora_compartida`
- `quiz_harina_maiz_segura`
- `quiz_embutidos_riesgo`
- `quiz_postre_industrial`

Vinculaciones nuevas:
- `match_cocina_segura_avanzada`
- `match_comer_fuera_seguro`
- `match_trazas_y_etiquetas`
- `match_riesgos_ocultos`
- `match_decisiones_seguras`

Arrastres nuevos:
- `drag_desayuno_dificil`
- `drag_colacion_dificil`
- `drag_bebida_normal`

## Polish selectivo aplicado

Drag:
- drop correcto con bounce corto
- drop incorrecto con shake corto y retorno a origen
- retorno a origen más rápido fuera del target válido

Enseñanza:
- overlay semitransparente detrás del asset o tarjeta textual
- entrada con fade/scale suave
- fallback textual sigue activo cuando no hay asset

Match:
- feedback label más legible y con color semántico
- animación corta al crear vínculo
- se eliminó el error de `MethodTweener` duro en las líneas del match

Mapa:
- 4 slots nuevos hasta 30
- estado disponible más cálido
- estado bloqueado más apagado para lectura más rápida

## Validación funcional

### Validación de contenido
- Resultado: OK
- Evidencia final: `CONTENT_VALIDATION=OK`
- Cobertura validada:
  - 30 nodos en mapa
  - `answer` presente en `options` para quiz
  - matches con al menos 2 pares
  - cada request random `{ type, difficulty }` con al menos un candidato exacto

### Smoke end to end
- Resultado: OK
- Evidencia final: `SMOKE_EXIT=0`
- El smoke actualizado valida:
  - mapa con 30 nodos
  - nodo 1
  - nodo 5 con variación real
  - match d2 en nodo 6
  - match d3 en nodo 14
  - nodo 18
  - nodo 19
  - nodo 25
  - nodo 30

### Nodo 19
- Resultado: OK
- Flujo observado: match + drag + quiz, con cierre de nodo y retorno al mapa.
- Corrida observada:
  - `match_alimentos`
  - `drag_desayuno_normal`
  - `quiz_natural_vs_industrial`
- Evidencia relevante:
  - `[RunPlan] node=celiaquia_19_cocina_segura ...`
  - `[ManualValidation] node=celiaquia_19_cocina_segura scene=match ...`
  - `[ManualValidation] node=celiaquia_19_cocina_segura scene=drag ...`
  - `[ManualValidation] node=celiaquia_19_cocina_segura scene=quiz ...`
  - `[NodeComplete] node=celiaquia_19_cocina_segura`

### Nodo 25
- Resultado: OK
- Flujo observado: match + drag + quiz, con cierre de nodo y retorno al mapa.
- Corrida observada:
  - `match_etiquetas_seguridad`
  - `drag_desayuno_dificil`
  - `quiz_rotulo_preventivo`
- Evidencia relevante:
  - `[RunPlan] node=celiaquia_25_etiquetas_y_trazas ...`
  - `[ManualValidation] node=celiaquia_25_etiquetas_y_trazas scene=match ...`
  - `[ManualValidation] node=celiaquia_25_etiquetas_y_trazas scene=drag ...`
  - `[ManualValidation] node=celiaquia_25_etiquetas_y_trazas scene=quiz ...`
  - `[NodeComplete] node=celiaquia_25_etiquetas_y_trazas`

### Nodo 30
- Resultado: OK
- Flujo observado: match + drag + quiz, con cierre de nodo y retorno al mapa.
- Corrida observada:
  - `match_trazas_y_etiquetas`
  - `drag_desayuno_dificil`
  - `quiz_embutidos_riesgo`
- Evidencia relevante:
  - `[RunPlan] node=celiaquia_30_desafio_final_extendido ...`
  - `[ManualValidation] node=celiaquia_30_desafio_final_extendido scene=match ...`
  - `[ManualValidation] node=celiaquia_30_desafio_final_extendido scene=drag ...`
  - `[ManualValidation] node=celiaquia_30_desafio_final_extendido scene=quiz ...`
  - `[NodeComplete] node=celiaquia_30_desafio_final_extendido`

## Cambios concretos aplicados

Producción:
- `res://contenido/mapa/celiaquia_mapa.json`
  - expansión a 30 nodos
- `res://contenido/mapa/preguntas.json`
  - +10 quizzes
- `res://contenido/mapa/vinculaciones.json`
  - +5 matches
- `res://contenido/mapa/arrastres.json`
  - +3 drags
- `res://mapas/MapBoard.tscn`
  - slots visuales 27..30
- `res://mapas/LevelNode.gd`
  - mejora visual de estados básicos
- `res://items/ItemLevel.gd`
  - feedback drag correcto/incorrecto
- `res://niveles/nivel_1/Level.gd`
  - overlay y entrada de enseñanza
- `res://niveles/nivel_1/Level.tscn`
  - backdrop de enseñanza y limpieza de animación vacía
- `res://vincular/vincular_conceptos.gd`
  - feedback visual y animación de vínculo

Documentación y tests:
- `project/README.md`
  - flujo congelado para demo
- `res://tests/vertical_slice_smoke_test.gd`
  - actualizado a mapa de 30 nodos y validación de 19, 25 y 30

## Pendientes priorizados

1. Bajo riesgo, alto ruido: falta el mp3 `simple-relaxing-guitar-loop-60828.mp3` y sigue apareciendo warning de carga en el drag.
2. Bajo riesgo, medio ruido: siguen apareciendo warnings de `grab_focus` sobre controles sin `focus_mode` habilitado.
3. Bajo riesgo, medio ruido: el match ya no tira `MethodTweener` error, pero todavía aparecen warnings de `Target object freed before starting` al cerrar algunas tweens tardías.
4. Bajo riesgo, medio ruido: Godot sigue reportando `ObjectDB instances leaked at exit` al salir del smoke.
5. Muy bajo riesgo, cosmético: siguen apareciendo `ItemMismatch` en algunos recursos visuales legacy (`panqueques`/`panqueque`, `medialunas`/`medialuna`).

## Cierre

- Vertical slice expandida y estable para demo.
- Flujo congelado respetado.
- Mapa en 30 nodos reales.
- Más variedad real en quiz, drag y match.
- Polish visual/UX aplicado sin cambiar arquitectura.
- Validación de contenido: OK.
- Smoke final: `SMOKE_EXIT=0`.