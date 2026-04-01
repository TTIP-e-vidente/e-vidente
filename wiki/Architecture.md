# 🏗️ Architecture

Guia tecnica de la estructura interna del proyecto e-vidente.

---

## 📦 Layers

### Game Layer (`project/`)
El núcleo del juego: escenas, lógica, assets.

```
project/
├── interface/          # UI y escenas de navegacion
│  ├── evidente.tscn    # Escena principal
│  ├── evidente.gd      # Controller principal
│  ├── libro*.tscn      # Vistas de libro/recetas
│  ├── opciones.tscn    # Settings/opciones
│  └── *.gd             # Scripts de logica
│
├── items/              # Base de datos de alimentos
│  ├── aceite.tres      # Recurso de alimento
│  ├── banana.tres      # Recurso de alimento
│  └── *.tres           # Cada alimento es un recurso
│
├── niveles/            # Configuracion de escenarios
│  └── [json/tres con niveles]
│
├── resources/          # Configuracion global
│  └── [settings/constants]
│
├── assets-sistema/     # Sprites, sonidos, fuentes
│  ├── iconos/
│  ├── interfaz/
│  ├── player/
│  ├── preguntas/
│  ├── sonidos/
│  └── ensenanza/
│
├── project.godot       # Configuracion del proyecto
└── export_presets.cfg  # Presets de export (web, desktop, etc)
```

### Resource Format

Cada alimento es un archivo `.tres` (TextResource):

```gdscript
# aceite.tres
[gd_resource type="Resource" script_class="Food"]
resource_name = "Aceite"

[resource]
name = "Aceite"
contains_gluten = false
contains_lactose = false
vegan = true
# ... otras propiedades
```

### Escena Principal

`evidente.tscn` es el hub central que:
- Carga en memoria base de alimentos
- Maneja transiciones entre vistas
- Controla logica de juego (puntos, rachas, etc)

---

## 🔄 Data Flow

```
User Input
    ↓
EventListener (en .gd)
    ↓
Game Logic (verificar validez de arrastre)
    ↓
Update State (puntos, items, inventory)
    ↓
Render Update (UI + feedback visual)
```

---

## 📊 Key Systems

### 1. Food System
- Cada alimento tiene propiedades: gluten, lactose, vegan, etc
- Los `items/*.tres` definen la "verdad" del alimento
- Las recetas son colecciones de items + condiciones

### 2. Level System
- Niveles especifican: personaje, condiciones alimentarias, items disponibles
- Punto de vittoria: preparar plato correcto según condiciones

### 3. UI System
- Libro: vista de informacion (lectura)
- Recetas: interfaz drag-drop para armar platos
- Opciones: settings y estadísticas

---

## 🎮 Godot 4.2 Setup

**GDScript** para toda la lógica.

**Nodes principales:**
- `Control` para UI
- `Node2D` para logica de juego
- `TextureRect` para assets visuales

---

## 🚀 Build & Export

**Web Export:** 
- Preset: "index"
- Output: `build/web/index.html`
- Usado por CI y deployments

**Local Testing:**
```bash
# En Godot Editor
F5 o Play button
```

---

## 🔗 Dependencias Externas

- **Godot 4.2:** Motor base
- **barichello/godot-ci:4.2:** Contenedor para builds automaticos
- **GitHub Actions:** CI/CD pipeline

Sin dependencias NPM/package.json en el proyecto core.
