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
├── niveles/            # Datos y escenas de niveles
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

### Sistema de niveles

- Cada nivel define condiciones alimentarias, items disponibles y contexto del reto.
- El objetivo es construir el plato correcto según esas restricciones.

### Sistema de interfaz

- `libro*.tscn` concentra la parte más informativa.
- Las vistas de recetas resuelven el drag and drop y el feedback de juego.
- `opciones.tscn` reúne ajustes y pantallas secundarias.

### Sistema de persistencia local

- `SaveManager` funciona como autoload.
- Guarda perfil local, historial, metadata y varias partidas por perfil.
- `Global` exporta e importa progreso para separar runtime y almacenamiento.
- `intro.tscn` y `archivero.tscn` son las dos vistas principales de ese flujo.

Más detalle en [Persistencia Local](Persistencia-Local).

## Stack técnico

- Godot 4.6.2.
- GDScript para la lógica del proyecto.
- GitHub Actions para CI.
- `barichello/godot-ci:4.6.2-stable` para validación y export headless.

## Build y export

El export web usa el preset `index` y deja la salida en `build/web/index.html` cuando corre bien. Esa salida se verifica y se publica como artifact en la CI.
