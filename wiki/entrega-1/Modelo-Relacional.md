# Modelo Relacional lógico del flujo

Este documento propone una versión mínima y defendible del modelo relacional lógico. No describe una base de datos implementada ni obliga a usar SQL.

## MR 

### RECORRIDO

Representa cada trayecto temático de la demo.

Campos sugeridos:

- clave
- nombre
- condicion_base

### CAPITULO

Representa cada unidad jugable seleccionable dentro de un recorrido.

Campos sugeridos:

- id
- recorrido_clave
- indice
- categoria
- completado
- ensenanza_clave

### DESAFIO_ARRASTRE

Representa la configuración del desafío asociado a un capítulo.

Campos sugeridos:

- id
- capitulo_id
- cantidad_positivos
- cantidad_negativos

### ITEM_ARRASTRABLE

Representa cada alimento usado en los desafíos.

Campos sugeridos:

- id
- categoria
- es_positivo
- sprite_ref

### ITEM_CONDICION

Tabla auxiliar recomendada solo para evitar un atributo multivaluado de condiciones.

Campos sugeridos:

- item_id
- condicion

### ENSENANZA

Representa el cierre pedagógico de cada capítulo.

Campos sugeridos:

- clave
- contenido_ref


