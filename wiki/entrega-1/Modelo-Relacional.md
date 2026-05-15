# Modelo Relacional lógico del flujo

Este documento propone una versión mínima y defendible del modelo relacional lógico. No describe una base de datos implementada ni obliga a usar SQL. Solo muestra cómo podría organizarse la información si en una etapa futura se quisiera persistir el flujo principal.

## Criterio TTIP

- Mantener el MR chico y legible.
- Evitar duplicar entidades que hoy no aportan claridad.
- No bajar a tablas cosas que en Entrega 1 todavía están "Falta confirmar".
- Si un atributo es multivaluado en el MER, separar una tabla auxiliar solo si mejora claridad.

## MR mínimo sugerido

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

## Relaciones mínimas

- un `RECORRIDO` contiene varios `CAPITULO`;
- un `CAPITULO` tiene un `DESAFIO_ARRASTRE`;
- un `DESAFIO_ARRASTRE` usa varios `ITEM_ARRASTRABLE`;
- un `ITEM_ARRASTRABLE` puede relacionarse con varias condiciones mediante `ITEM_CONDICION`;
- un `CAPITULO` puede mostrar una `ENSENANZA`.

## Qué no conviene bajar todavía al MR

Estas entidades pueden mantenerse fuera del MR de defensa hasta tener confirmación técnica más fuerte:

- `JUGADOR` separado de `PERFIL_LOCAL`;
- `MAPA` separado de `CAPITULO` o `NODO_JUGABLE`;
- `PARTIDA_GUARDADA` separada de `PROGRESO`;
- `JUEGO_INTERNO` y sus especializaciones si el flujo por nodo no está confirmado en esta rama;
- `RACHA`, salvo que exista implementación concreta y aporte valor a la explicación.

## Diferencia con el MER

El MER muestra conceptos del negocio. El MR propone una posible organización lógica de datos, pero sin afirmar implementación real.

- [MER lógico](../Modelo-Entidad-Relacion.md)
- [Arquitectura del flujo](Arquitectura.md)

## Recomendación de defensa

Si el tutor pide un MR, conviene mostrar este modelo mínimo. Si pide más detalle sobre persistencia local, la respuesta correcta es que esa parte sigue "Falta confirmar" en esta rama y por eso no se la baja todavía a tablas separadas.