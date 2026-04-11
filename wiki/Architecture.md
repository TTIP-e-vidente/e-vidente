# Architecture

Esta página resume cómo está organizado el proyecto y dónde conviene tocar cada parte.

## Estructura general

La mayor parte del trabajo vive dentro de `project/`.

```
project/
├── interface/          # UI y escenas de navegación
│  ├── evidente.tscn    # Escena principal
│  ├── evidente.gd      # Script principal
│  ├── libro*.tscn      # Vistas de libro y recetas
│  ├── opciones.tscn    # Menú de opciones
│  └── *.gd             # Scripts de UI y flujo
│
├── items/              # Recursos de alimentos
│  └── *.tres
│
├── niveles/            # Catálogo, escenas y mecánicas de niveles
├── preguntas/          # Modo quiz y recursos de preguntas
├── resources/          # Configuración general
├── assets-sistema/     # Sprites, sonido y material visual
├── project.godot       # Configuración del proyecto
└── export_presets.cfg  # Presets de export
```

## Recursos de alimentos

Cada alimento está definido como un `.tres`. Ahí vive la verdad del dato: si contiene gluten, si tiene lactosa, si es vegano y cualquier otra propiedad que el juego necesite consultar.

## Escena principal

`evidente.tscn` funciona como hub del juego. Desde ahí se cargan recursos, se coordinan transiciones entre vistas y se sostiene parte del estado general del recorrido.

## Flujo de datos

El flujo general del juego es bastante directo:

```
Input del jugador
    ↓
Script de escena
    ↓
Lógica de validación
    ↓
Actualización de estado
    ↓
Feedback visual y sonoro
```

## Sistemas principales

### Sistema de alimentos

- Los `items/*.tres` describen cada alimento.
- Las recetas y reglas de validación se apoyan en esos datos.
- Los pools jugables ahora se resuelven por track a partir del catalogo de items y del metadata del propio alimento.
- Los foods nuevos pueden entrar automaticamente en celiaquia, veganismo y mixto si sus `condiciones` estan bien cargadas; para tracks ambiguos como cetogenica se puede usar `allowed_track_keys` o `blocked_track_keys` en el propio item.
- Las listas gigantes dentro de `level_*.tres` siguen sirviendo como fallback y ponderacion legacy, pero agregar una comida nueva ya no deberia requerir editar esos recursos a mano.

### Sistema de niveles

- Cada nivel define condiciones alimentarias, items disponibles y contexto del reto.
- `GameTrackCatalog` centraliza los cuatro recorridos jugables: celiaquia, veganismo, veganismo + celiaquia y cetogenica.
- La mecánica principal integrada hoy sigue siendo armar el plato correcto según esas restricciones.

### Sistema de interfaz

- `intro.tscn`, `archivero.tscn` y `libro*.tscn` concentran la navegación principal.
- Las vistas de recetas resuelven el drag and drop y el feedback de juego.
- El rediseño reciente simplificó el acceso a jugar, el resumen de guardado y la edición del perfil local.
- `opciones.tscn` reúne ajustes y pantallas secundarias.

### Sistema de preguntas

- `preguntas/` concentra un modo de quiz separado del loop principal de recetas.
- El contenido se define con recursos `Preguntas` agrupados en `ThemePreg`.
- La estructura ya contempla variantes de texto, imagen, audio y video para cada pregunta.
- `selector.tscn` puede abrir `pregunta.tscn` como flujo aparte.

### Sistema de persistencia local

- `SaveManager` funciona como autoload.
- Guarda perfil local, historial, metadata y una partida retomable en el flujo visible.
- `Global` exporta e importa progreso para separar runtime y almacenamiento.
- `intro.tscn` y `archivero.tscn` son las dos vistas principales de ese flujo.

Internamente el save mantiene una sesion activa y respaldo en disco, pero la documentacion funcional del juego asume un unico flujo de Guardar y Retomar.

Más detalle en [Persistencia Local](Persistencia-Local).

## Stack técnico

- Godot 4.6.2.
- GDScript para la lógica del proyecto.
- GitHub Actions para CI.
- `barichello/godot-ci:4.6.2` para validación y export headless.

## Build y export

El export web usa el preset `index` y deja la salida en `build/web/index.html` cuando corre bien. Esa salida se verifica y se publica como artifact en la CI.
