# Sistemas / Contenido

## Archivo de entrada oficial

El punto de entrada para cargar contenido jugable es:

`CargadorDeContenidoDeNodo.gd`

Usalo cuando una escena o test necesita leer el JSON de un nodo jugable.

## Flujo de carga

1. `CargadorDeContenidoDeNodo.gd` recibe una ruta `json_path`.
2. `AdaptadorContenidoViejo.gd` normaliza rutas viejas y formatos legacy.
3. `CargadorDeContenidoDeNodo.gd` lee el JSON.
4. `AdaptadorContenidoViejo.gd` adapta el shape viejo al shape oficial si hace falta.
5. `ValidadorDeContenidoDeNodo.gd` valida campos obligatorios y contenido por modo.
6. `ValidadorDeContenidoDeNodo.gd` devuelve una version limpia.
7. El minijuego convierte ese nodo limpio a su runtime si necesita un formato propio.

## Que se valida

`ValidadorDeContenidoDeNodo.gd` valida:

- campos base: `id`, `theme`, `title`, `difficulty`, `mode`, `content`;
- que `content` sea un objeto;
- datos especificos de `quiz_choice`;
- datos especificos de `drag_drop`;
- datos especificos de `vinculacion_conceptos`.

## Que se adapta

`AdaptadorContenidoViejo.gd` existe para que la demo siga aceptando contenido anterior:

- rutas viejas como `res://niveles/nodos/`;
- rutas viejas como `res://preguntas/json_nodos/`;
- JSON plano de preguntas;
- shapes legacy con bloques `node`, `activity`, `question`, `selection` o `drag_and_drop`.

## Que es legacy

Legacy es compatibilidad para contenido viejo. No es la ruta ideal para escribir contenido nuevo.

Contenido nuevo deberia vivir en:

`res://contenido/nodos/`

Y deberia usar el shape oficial:

- `id`
- `theme`
- `title`
- `difficulty`
- `mode`
- `content`

## Que formato espera cada minijuego

- `quiz_choice`: usa `content.question`, `content.correct_answer`, `content.wrong_options` y `content.visual_resource`.
- `drag_drop`: usa `content.instruction`, `content.targets`, `content.items`, `content.success_message` y `content.error_message`.
- `vinculacion_conceptos`: usa `content.instruccion`, `content.conceptos_izquierda`, `content.conceptos_derecha`, `content.retroalimentacion_ok` y `content.ensenanza`.

## Que NO tocar antes de demo

- No cambiar el formato JSON oficial.
- No borrar `AdaptadorContenidoViejo.gd` sin migrar todo el contenido viejo.
- No cambiar nombres de `mode`.
- No cambiar las claves que consumen los minijuegos.
- No mover JSON de lugar.
- No crear otro pipeline de carga.
- No tocar `Global` ni `SaveManager` desde esta carpeta.

## Tests recomendados

Despues de tocar contenido, correr:

- `contenido_vinculacion_json_test.gd`
- `plan_de_partida_de_nodo_test.gd`
- `partida_de_nodo_multiple_test.gd`
- `vincular_conceptos_scene_test.gd`
- `vertical_slice_smoke_test.gd`
