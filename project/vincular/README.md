# Vincular Conceptos

## Que hace

Esta mecanica muestra tarjetas de conceptos a la izquierda y a la derecha. El jugador elige una izquierda, luego una derecha, crea vinculos y confirma si las relaciones son correctas.

## Archivo principal

`vincular_conceptos.gd` orquesta la escena:

- carga la sesion jugable;
- carga el JSON con `CargadorDeContenidoDeNodo.gd`;
- configura tarjetas;
- maneja seleccion y vinculos;
- valida respuestas;
- guarda progreso;
- continua el flujo posterior del juego.

## Tarjeta ConceptoItem

`concept_item.gd` guarda el estado minimo de cada tarjeta:

- `concept_id`
- `texto`
- `lado`
- `par_key`
- `vinculada_con`
- `tiene_error`
- `animar_vinculo`

La regla importante es:

`es_correcta()` compara `par_key` con la tarjeta vinculada.

## Flujo de lectura

1. `_ready()` prepara nodos, botones y sesion.
2. `_cargar_datos_de_vinculacion()` lee el JSON.
3. `_aplicar_runtime_en_escena()` toma los conceptos y configura la escena.
4. `_configurar_lado()` carga datos en cada `ConceptoItem`.
5. `seleccionar_izquierda()` guarda la tarjeta izquierda actual.
6. `vincular_con_derecha()` crea o reemplaza el vinculo.
7. `confirmar()` marca aciertos/errores.
8. `_actualizar_visual()` refresca tarjetas, lineas, botones y areas de click.
9. `_finalizar_vinculacion()` guarda progreso y pasa al flujo posterior.

## Como se evita usar dos veces una derecha

Antes de vincular, `quitar_vinculo_anterior_de(derecha)` busca si esa derecha ya estaba usada por otra izquierda y limpia ese vinculo.

## Que NO tocar antes de demo

- No tocar guardado.
- No tocar navegacion post-juego.
- No tocar `Global`.
- No tocar `SaveManager`.
- No tocar `PostGameFlowController`.
- No cambiar nodos de la escena.
- No cambiar formato JSON.
- No crear managers ni Resources nuevos.

## Tests recomendados

- `contenido_vinculacion_json_test.gd`
- `vincular_conceptos_scene_test.gd`
- `vertical_slice_smoke_test.gd`
