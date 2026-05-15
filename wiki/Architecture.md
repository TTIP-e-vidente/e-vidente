# ≡ƒÅù∩╕Å C├│mo Funciona E-VIDENTE

Te mostramos visualmente c├│mo est├í armado el proyecto, d├│nde vive cada cosa importante, y c├│mo todo se conecta.

> Si necesit├ís entender "por qu├⌐" de cambios grandes, mir├í los [ADR/](adr/).  
> Si necesit├ís saber qu├⌐ cambi├│ ├║ltimamente, mir├í [Bitacora.md](Bitacora.md).

---

## El Flujo en 2 Minutos

As├¡ funciona el juego desde que lo abr├¡s:

1. Primero ves el splash (la pantalla de bienvenida con el logo animado)
2. Despu├⌐s el men├║ principal
3. Eleg├¡s qu├⌐ quer├⌐s hacer: jugar, preguntas, o retomar donde dejaste
4. Si jug├ís, ves un mapa, entras a un nivel, y jug├ís
5. Al terminar, se guarda todo en el disco y ves la pantalla de racha

Ac├í est├í el diagrama visualizado:

```mermaid
flowchart TD
    A["≡ƒÄ¼ Splash<br/>evidente.tscn"] -->|bounce_button| B["≡ƒÅá Main Menu<br/>intro.tscn"]
    B -->|jugar| C["≡ƒÄ» Mode Selector<br/>selector.tscn"]
    C -->|choose| D{Flujo}
    D -->|Recipes| E["≡ƒôû Track Book<br/>libro.gd"]
    D -->|Quiz| F["Γ¥ô Questions<br/>pregunta.gd"]
    D -->|Resume| G["ΓÅ«∩╕Å Last Save<br/>SaveManager"]
    E -->|open_chapter| H["≡ƒôì Map/Level<br/>MapScene.gd"]
    H -->|start| I["≡ƒÄ« Gameplay<br/>Level.gd"]
    F -->|answer_q| I
    I -->|complete| J["≡ƒÄë Streak Feedback<br/>ProgressManagerRacha.gd"]
    I -->|save| K["≡ƒÆ╛ Persistence<br/>SaveManager"]
    J -->|continue| L["Γå⌐∩╕Å Back to Menu<br/>GameSceneRouter"]
    K -->|disk| M["≡ƒôü Local Storage"]
    style A fill:#ff9900
    style B fill:#ff9900
    style C fill:#ff9900
    style I fill:#66cc66
    style K fill:#6666cc
```

---

## Ruta R├ípida Para Exponer (5 Minutos)

Si esto lo vas a mostrar en clase, segu├¡ este orden:

1. Diagrama principal de flujo (arriba): explica el recorrido completo.
2. Tabla de "Si necesit├ís cambiar algo": muestra c├│mo ubicarse r├ípido en el c├│digo.
3. Sistemas clave: audio, guardado, navegaci├│n y racha.

Con esa secuencia, cualquiera entiende el proyecto sin perderse en detalles t├⌐cnicos.

---

## D├│nde Vive Cada Cosa

Versi├│n corta para ubicarte r├ípido:

| ├ürea | Componentes principales | Para qu├⌐ sirve |
|---|---|---|
| Entrada y Men├║ | `interface/evidente.gd`, `interface/intro.gd`, `niveles/selector.gd` | Arranque y navegaci├│n inicial |
| Progreso y Guardado | `interface/SaveManager.gd`, `niveles/global.gd`, `interface/save_local/*` | Guardar, recuperar y consultar avance |
| Gameplay | `niveles/nivel_1/Level.gd`, `niveles/manager_level.gd`, `niveles/mechanics/*` | Flujo jugable y l├│gica de mec├ínicas |
| Preguntas | `preguntas/pregunta.gd`, `preguntas/QuestionJsonLoader.gd` | Modalidad `quiz_choice` |
| Contenido de nodos | `contenido/nodos/*.json`, `sistemas/contenido/CargadorDeContenidoDeNodo.gd` | Contenido de nivel y nodos jugables por JSON |
| Mapa | `mapas/MapScene.gd`, `mapas/LevelNode.gd`, `mapas/MapNodeData.gd` | Navegaci├│n visual por cap├¡tulos |
| Audio | `managers/MusicManager.gd` | M├║sica de fondo y continuidad |
| UI de progreso | `interface/components/Racha.tscn`, `interface/components/ProgressManagerRacha.gd` | Feedback de racha y estado |

Si necesit├ís detalle carpeta por carpeta, se puede expandir en una secci├│n aparte. Por ahora dejamos lo esencial para que sea m├ís f├ícil de leer.

---

## Si Necesit├ís Cambiar Algo, ┬┐Por D├│nde Empiezo?

Ac├í te decimos "si quer├⌐s cambiar X cosa, toca este archivo":

| Si quer├⌐s cambiar... | Toca aqu├¡ | Dificultad | D├│nde est├í el detalle |
|---|---|---|---|
| ≡ƒÄ╡ La m├║sica de fondo | `managers/MusicManager.gd` | Γ¡É f├ícil | Ver resumen en [Bitacora.md](Bitacora.md) |
| ≡ƒÅá El men├║ principal (botones, colores, etc) | `interface/intro.gd` | Γ¡É f├ícil | Solo UI, nada de l├│gica |
| ≡ƒÄ» El selector de modos | `interface/selector.gd` | Γ¡É f├ícil | Botones + eventos |
| ≡ƒôû Los libros / selecci├│n de cap├¡tulos | `interface/libro.gd` | Γ¡É f├ícil | Genera botones din├ímicamente |
| ≡ƒÄ« C├│mo funciona un nivel (lo que ves cuando jug├ís) | `niveles/nivel_1/Level.gd` | Γ¡ÉΓ¡É medio | Es el template para todos los niveles |
| ≡ƒÄ« La mec├ínica de gameplay (validaci├│n de comida, scoring) | `niveles/mechanics/PlateSortMechanicController.gd` | Γ¡ÉΓ¡ÉΓ¡É dif├¡cil | L├│gica compleja |
| ≡ƒÆ╛ C├│mo guardamos el progreso | `interface/SaveManager.gd` | Γ¡ÉΓ¡ÉΓ¡É dif├¡cil | Serializaci├│n y compatibilidad |
| ≡ƒôè El progreso que ves en pantalla | `niveles/global.gd` | Γ¡ÉΓ¡É medio | M├⌐todos para preguntar si completaste cosas |
| ≡ƒÅâ La racha diaria (contadores, l├│gica) | `niveles/progress/GameStreakTracker.gd` | Γ¡É f├ícil | Timestamps + regla simple |
| ≡ƒù║∩╕Å El mapa visual | `mapas/MapScene.gd` | Γ¡ÉΓ¡É medio | C├│mo se ve cada nivel, si est├í desbloqueado |
| ≡ƒìÄ Los alimentos (propiedades, condiciones) | `items/*.tres` | Γ¡É f├ícil | Son Resources con datos |
| ≡ƒîê Los colores de la app | `colours/miPaleta.gd` | Γ¡É f├ícil | Cambias ac├í y cambia todo |
| ≡ƒÄ¢∩╕Å El cat├ílogo de tracks (celiaquia, veganismo, etc) | `niveles/GameTrackCatalog.gd` | Γ¡ÉΓ¡É medio | 4 tracks: define cu├íl es cu├íl |
| ≡ƒöä Navegar entre pantallas | `niveles/GameSceneRouter.gd` | Γ¡É f├ícil | Todos los `change_scene` en un lugar |
| ≡ƒöº C├│mo se valida el proyecto autom├íticamente | `.github/workflows/` | Γ¡ÉΓ¡ÉΓ¡É dif├¡cil | Pipelines complejos |

---

## C├│mo Fluyen los Datos

Esto es simplificado, pero as├¡ es c├│mo funciona:

```mermaid
flowchart LR
    A["≡ƒæå Input<br/>Mouse/Key"] -->|evento| B["≡ƒÄ» Script<br/>de Escena"]
    B -->|validar| C["Γ£à L├│gica<br/>de Negocio"]
    C -->|actualizar| D["≡ƒÆ╛ Estado<br/>Global + SaveManager"]
    D -->|emit| E["≡ƒÄ¿ Feedback<br/>Visual + Sonoro"]
    E -->|se ve| F["≡ƒæü∩╕Å Jugador"]
    F -->|reacciona| A
    style A fill:#66cc66
    style B fill:#ff9900
    style C fill:#ff9900
    style D fill:#6666cc
    style E fill:#ff6666
    style F fill:#66cc66
```

---

## Los 6 Sistemas Clave

### ≡ƒÄ╡ Audio - M├║sica Centralizada

**D├│nde**: `managers/MusicManager.gd` Γ¡É  
**Qu├⌐ hace**: Un solo gestor que maneja toda la m├║sica del juego. Cuando termina una canci├│n, la reinicia autom├íticamente. Sin silencios inc├│modos en sesiones largas.

**Lo importante**:
- M├║sica se reinicia sola
- Control├ís volumen desde un lugar
- Transiciones suaves

**C├│mo se usa**:
```gdscript
MusicManager.reproducir_musica("ruta/cancion.ogg")
MusicManager.establecer_volumen(0.8)
```

[Resumen del cambio](Bitacora.md#lo-que-pas├│-recientemente)

---

### ≡ƒÆ╛ Persistencia - D├│nde Guardamos Todo

**D├│nde**: `interface/SaveManager.gd` Γ¡É  
**Qu├⌐ hace**: Punto ├║nico por donde pasa TODO lo que guardamos. Perfil, progreso, historial.

**Lo importante**:
- Un solo lugar para guardar
- Maneja m├║ltiples sesiones
- Cuida compatibilidad con guardos viejos

**C├│mo se usa**:
```gdscript
SaveManager.load_data()
SaveManager.save_data()
SaveManager.is_level_completed("celiaquia", 1)
```

[Deep dive del guardado](Persistencia-Local.md)

---

### ≡ƒÄ« Navegaci├│n - El Control de Tr├ífico

**D├│nde**: `niveles/GameSceneRouter.gd` Γ¡É  
**Qu├⌐ hace**: Hub central que maneja TODOS los cambios entre pantallas. Todo pasa por aqu├¡.

**Lo importante**:
- Un solo lugar para entender la navegaci├│n
- M├ís f├ícil debuggear si algo falla
- Pas├ís contexto entre pantallas

**C├│mo se usa**:
```gdscript
GameSceneRouter.go_to_main_menu(get_tree())
GameSceneRouter.go_to_map(get_tree())
GameSceneRouter.go_to_track_level(get_tree(), track_key, level_num)
```

---

### ≡ƒÅâ Racha Diaria - El Contador

**D├│nde**: `niveles/progress/GameStreakTracker.gd` Γ¡É  
**Qu├⌐ hace**: L├│gica de la racha. Si jug├ís hoy sube +1. Si pas├│ m├ís de un d├¡a, se reinicia.

**Lo importante**:
- Usa timestamps Unix para precisi├│n
- L├│gica simple pero poderosa
- F├ícil de testear

**La regla**:
```
d├¡as_pasados = (hoy - ├║ltima_fecha) / 86400
if d├¡as_pasados == 1: racha += 1
if d├¡as_pasados == 0: racha se mantiene
if d├¡as_pasados > 1: racha = 1
```

---

### ≡ƒìÄ Alimentos - Propiedades Centralizadas

**D├│nde**: `items/*.tres`  
**Qu├⌐ hace**: Cada alimento es un archivo con sus propiedades. Gluten s├¡/no, vegano s├¡/no, etc.

**Lo importante**:
- Una sola fuente de verdad por alimento
- F├ícil agregar m├ís
- La l├│gica los lee din├ímicamente

**Qu├⌐ guardan**:
- Condiciones (restricciones)
- Tracks permitidos
- Nombre, descripci├│n, imagen

---

### ≡ƒîê Paleta de Colores - Un Solo Lugar

**D├│nde**: `colours/miPaleta.gd`  
**Qu├⌐ hace**: Todos los colores de la app en un archivo. Cambias ac├í y cambian en todo.

**Lo importante**:
- Consistencia en todo
- Si necesit├ís naranja, busc├ís 1 solo lugar
- DRY (Don't Repeat Yourself)

**C├│mo se usa**:
```gdscript
var color = miPaleta.naranja_tierra
self.modulate = color
```

---

## C├│mo Aprender el C├│digo

### Ruta trainee para mapa y niveles

Si quer├⌐s tocar solo mapa, nodos jugables por JSON o niveles sin entender todo el repo, segu├¡ este orden:

1. `mapas/MapBoard.tscn` - d├│nde est├ín los nodos visibles.
2. `mapas/LevelNode.gd` - qu├⌐ datos tiene cada nodo.
3. `niveles/nodos/*.json` - contenido de nodos jugables.
4. `preguntas/pregunta.gd` o `mapas/DragDropNode.gd` - c├│mo se consume el JSON seg├║n la modalidad.
5. `niveles/nivel_1/Level.gd` - nivel visible.
6. `niveles/manager_level.gd` - armado real de la sesi├│n.

No necesit├ís leerlo TODO de una. Depende cu├ínto tiempo tengas:

**10 minutos**: Le├⌐ lo que est├ís leyendo ahora. Mir├í el Mermaid de arriba. Ya sab├⌐s c├│mo funciona todo.

**30 minutos**: Lee [Home.md](Home.md) completo. Abr├¡ `interface/evidente.gd` en tu editor y le├⌐ hasta `_ready()`. Hace lo mismo con `niveles/GameSceneRouter.gd` completo. Ya sab├⌐s c├│mo arranca y navega.

**1 hora**: Segu├¡ la ruta:
1. `interface/evidente.gd` - C├│mo arranca
2. `niveles/intro.gd` - El men├║
3. `niveles/selector.gd` - El selector
4. `interface/SaveManager.gd` - El guardado
5. `interface/libro.gd` - Cap├¡tulos
6. `niveles/nivel_1/Level.gd` - C├│mo se juega
7. `niveles/manager_level.gd` - Orquestaci├│n

Despu├⌐s, los docs te dan contexto:
- [Persistencia Local](Persistencia-Local.md) - Deep dive del guardado
- [Bitacora.md](Bitacora.md) - Qu├⌐ cambi├│ y cu├índo
- [adr/](adr/) - Decisiones importantes

---

## Otros Docs

| Doc | Qu├⌐ Es | Cu├índo |
|---|---|---|
| [Home.md](Home.md) | ├ìndice | Primero |
| [Getting-Started.md](Getting-Started.md) | Setup | Primera vez |
| [Modelo-Entidad-Relacion.md](Modelo-Entidad-Relacion.md) | MER l├│gico editable | Entrega TTIP |
| [Persistencia-Local.md](Persistencia-Local.md) | Deep dive | Trabajando con saves |
| [CI.md](CI.md) | Validaciones | Cuando falla un check |
| [Bitacora.md](Bitacora.md) | Historial | Buscando "cu├índo cambi├│ X" |
| [adr/](adr/) | Decisiones | "Por qu├⌐ se hizo as├¡" |

---

## Convenciones en el C├│digo

**Nombres**: Expl├¡cito > Cr├¡ptico
- Γ£à `background_music`
- Γ¥î `bgm`
- Γ£à `_play_level_audio()`
- Γ¥î `_playAudio()`

**Estructura t├¡pica**:
```gdscript
extends Node
class_name MiClase

# === Signals ===
signal algo_pas├│

# === Constants ===
const MI_VALOR = 42

# === Exports ===
@export var configurable := 0

# === Private Variables ===
var _estado := "inicial"

# === Lifecycle ===
func _ready() -> void:
    pass

# === Public API ===
func hacer_algo() -> void:
    pass

# === Private Helpers ===
func _ayudante() -> void:
    pass
```

**Comentarios**:
- Γ£à `## Descripci├│n clara` (docstring)
- Γ£à `# L├│gica compleja explicada` (├║til)
- Γ¥î `# increment x` (obvio, no necesita)

---

## Links ├Ütiles

- **Repositorio**: https://github.com/TTIP-e-vidente/e-vidente
- **Godot**: https://godotengine.org/download/windows/
- **Godot Docs**: https://docs.godotengine.org/en/stable/
- **GDScript**: https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/
