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

`evidente.tscn` es la escena de arranque configurada en `project.godot`.

No es el menu principal. Su rol actual es mas acotado: funciona como portada animada y deriva a `intro.tscn`.

`intro.tscn` es el menu principal real. Desde ahi se abre `selector.tscn`, que decide si el jugador entra al flujo de recetas, al modo preguntas o reanuda el ultimo punto guardado.

`GameSceneRouter.gd` concentra la navegacion principal entre escenas para que el recorrido se pueda seguir sin buscar `change_scene_to_file()` repartidos por todo el proyecto.

## Cómo seguir el flujo en código

Si queres reconstruir el recorrido completo leyendo el menor numero posible de archivos, hoy conviene seguir este orden:

1. `interface/evidente.gd`: portada animada de arranque.
2. `niveles/intro.gd`: menu principal.
3. `niveles/selector.gd`: selector entre recetas, preguntas y continuar.
4. `interface/Archivero.gd`: hub visible del save local y entrada al flujo de recetas.
5. `interface/libro.gd`: selector de capitulos por track.
6. `niveles/nivel_1/Level.gd`: shell comun de cualquier nivel jugable.
7. `niveles/manager_level.gd`: orquestador runtime de la corrida activa.
8. `niveles/mechanics/PlateSortMechanicController.gd`: mecanica jugable actual.
9. `interface/SaveManager.gd`: persistencia local y resume.
10. `niveles/global.gd`: metadata de tracks, catalogo y progreso en memoria.

En la practica, casi todo el flujo visible de la app sale de esa cadena.

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

- `evidente.tscn` es la portada animada.
- `intro.tscn` es el menu principal.
- `selector.tscn` separa recetas, preguntas y continuar.
- `GameSceneRouter.gd` centraliza la navegacion principal.
- `Archivero` concentra el resumen de guardado y el acceso visible al perfil local.
- `libro*.tscn` muestran los capitulos habilitados de cada track.
- `Level.gd` y `ManagerLevel.gd` separan flujo visible de escena y armado runtime del nivel.
- `opciones.tscn` reune ajustes y pantallas secundarias.

### Sistema de preguntas

- `preguntas/` concentra un modo de quiz separado del loop principal de recetas.
- El contenido se define con recursos `Preguntas` agrupados en `ThemePreg`.
- La estructura ya contempla variantes de texto, imagen, audio y video para cada pregunta.
- `selector.tscn` puede abrir `pregunta.tscn` como flujo aparte.

### Sistema de persistencia local

- `SaveManager` funciona como autoload y es la unica fachada publica del save local.
- El modelo activo ya no expone slots reales: persiste un unico save local con `profile`, `progress`, `history`, `resume_state` y `save_meta`.
- `interface/save_local/data/` normaliza payloads viejos y absorbe compatibilidad con saves legacy.
- `interface/save_local/progress/` resuelve progreso, historial y resume.
- `interface/save_local/persistence/` carga, escribe y recupera el save en disco.
- `Global` mantiene el progreso runtime en memoria; `SaveManager` lo serializa y lo restaura.
- `selector.tscn`, `Archivero`, `auth.tscn` y `Level.gd` son los puntos visibles donde ese flujo aparece en pantalla.

Más detalle en [Persistencia Local](Persistencia-Local).

## Stack técnico

- Godot 4.6.2.
- GDScript para la lógica del proyecto.
- GitHub Actions para CI.
- `barichello/godot-ci:4.6.2` para validación y export headless.

## Build y export

El export web usa el preset `index` y deja la salida en `build/web/index.html` cuando corre bien. Esa salida se verifica y se publica como artifact en la CI.
