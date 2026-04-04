# 🚀 Getting Started

Guia corta para iniciar desarrollo sobre e-vidente sin friccion.

---

## 📋 Requisitos previos

- **Godot:** 4.2 exacto  
- **Git:** instalado y configurado  
- **Acceso:** permisos en el repositorio (push/PR)  


## ⬇️ Clonar y abrir

```bash
# 1. Clonar
git clone https://github.com/TTIP-e-vidente/e-vidente.git
cd e-vidente

# 2. Activar hooks locales
powershell -ExecutionPolicy Bypass -File scripts/setup-git-hooks.ps1

# 3. Abrir en Godot
# - Abrir Godot Hub o Godot Editor
# - Project > Import  
# - Navegar a: project/project.godot
# - Select Version > Godot 4.2 → Import & Edit

# 4. Godot completara importacion inicial (~1-2 min)
```

## 🗂️ Directorio clave

| Directorio | Proposito |
|---|---|
| `project/` | Juego Godot: escenas, scripts, recursos |
| `project/interface/` | Escenas y logica de UI |
| `project/items/` | Datos de alimentos (.tres) |
| `project/niveles/` | Configuraciones de niveles/escenarios |
| `project/resources/` | Configuracion general |
| `wiki/` | Esta documentacion (Markdown) |
| `.github/workflows/` | Pipeline de CI (GitHub Actions) |

## 🔄 Flujo de trabajo recomendado

```
1. git checkout -b feature/nombre
   └─ Crear rama de trabajo

2. [Editar en Godot]
   └─ Cambios pequenos y testados

3. git add . && git commit -m "Descripcion clara"
   └─ Si tocaste project/, actualizar wiki/Bitacora.md

4. [Verificar en Godot]
   └─ Abrir proyecto, revisar que no haya errores criticos

5. git push origin feature/nombre
   └─ Subir cambios

6. [Abrir PR en GitHub]
   └─ Describir cambio en la PR
```

## ✅ Checklist antes de PR

- [ ] El proyecto abre en Godot sin errores criticos
- [ ] Las escenas se ven como esperado
- [ ] Probaste cambios funcionales localmente
- [ ] La descripcion de la PR es clara
- [ ] Si cambiaste `project/`, actualizaste `wiki/Bitacora.md`
- [ ] CI pasa: validate ✅ + build-web ✅

## 🐛 Troubleshooting

### "Proyecto no importa"
- Verifica que `project/project.godot` exista
- Intenta borrar `.godot/` y re-importar

### "Error: Missing resources"
- Ejecutar import forzado: Godot → Project → Tools → Reimport

### "Export falla con index.html missing"
- Revisar `export_presets.cfg` tiene ruta correcta
- Ver resultado en `build/web` y en `project/export/`

### "Warning de wiki en CI"
- Tocaste archivos en `project/` sin cambios en wiki
- Agregar breve entrada en `wiki/Bitacora.md`
