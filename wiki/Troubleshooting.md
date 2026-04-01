# 🔧 Troubleshooting

Guia de diagnostico y soluciones a problemas comunes en desarrollo de e-vidente.

---

## ❌ Godot Issues

### El proyecto no importa
**Sintomas:**
- Godot se traba al importar
- Error: "Error loading script"

**Causas comunes:**
1. Archivos .gd con syntax invalido
2. Referencias a archivos eliminados
3. `.godot/` cache corrupto

**Solucion:**
```bash
# Opcion 1: Limpiar cache
rm -r project/.godot/

# Opcion 2: Forzar re-import en Godot
# Menu: Project > Tools > Reimport
# Luego: Project > Reload Current Project
```

### "Missing resources" o "Can't find resource"
**Sintomas:**
- Error runtime en pantalla
- Assets no cargan

**Solucion:**
1. Verificar ruta de archivo (case-sensitive en Linux/Mac)
2. Revisar que archivos .tres existan
3. Godot → Project → Tools → Reimport

### Escenas se ven cortadas o deformadas
**Solucion:**
- Verificar canvas size en `project.godot`
- Revisar anchors/margins en Control nodes
- Scene > Fit to Parent (Ctrl+Shift+F)

---

## ❌ Export Issues

### Build web falla con "Export preset not found"
**Error completo:**
```
ERROR: export: Preset 'index' not found in export presets.cfg
```

**Solucion:**
1. Abrir Godot
2. Project > Export...
3. Crear preset "index" (Web)
4. Setup templates web: Help > Manage Export Templates → Download

### Export genera archivo pero CI no lo encuentra
**Causa:** Godot exporta a carpeta inesperada (preset export_path)

**Fix:**
```bash
# Revisar ubicacion real
find . -name "index.html" -type f

# Si esta en project/export/ en lugar de build/web/
# El CI intenta copiarla, pero verifica si succede
```

### Web build no carga en navegador
**Sintomas:**
- Pantalla blanca o error en console del navegador

**Diagnostico:**
1. Abrir DevTools (F12)
2. Console tab → buscar errores
3. Network tab → verificar que .pck y .wasm cargen

**Causas comunes:**
- CORS bloqueando assets (local testing)
- Path relativo invalido en HTML
- Falta .pck o .wasm

---

## ❌ CI Issues

### CI falla con "quality: wiki/Bitacora.md missing"
**Causa:** Archivo no existe en repo

**Solucion:**
```bash
git add wiki/Bitacora.md
git commit -m "Add Bitacora template"
```

### CI quality warning "Project files changed without wiki updates"
**Significado:** Tocaste `project/` pero no actualizaste wiki

**Solucion:**
1. Abrir `wiki/Bitacora.md`
2. Agregar entrada con timestamp y cambio
3. Commit + push

### CI build-web falla pero local funciona
**Causa comun:** Templates web faltantes en contenedor Docker

**Ver logs:**
1. GitHub > Actions > [tu workflow]
2. build-web > Export Web build
3. Buscar "ERROR" en output

**Solucion temporal:**
- Asegurar `export_presets.cfg` tiene export_path = "build/web"

---

## ❌ Git Issues

### "Permission denied" al push
**Causa:** SSH key no configurada o HTTPS token vencido

**Fix SSH:**
```bash
ssh-keygen -t ed25519
# Luego agregar public key a GitHub Settings > SSH Keys
```

### "Your branch is ahead of origin by X commits"
**Significado:** Hiciste commits locales pero no pushaste

```bash
git push origin [tu-rama]
```

### Accidental commit que querés sacar
```bash
# Si NO hiciste push aun:
git reset --soft HEAD~1    # Deshacer pero mantener cambios

# Si YA hiciste push:
git revert HEAD            # Crear commit inverso
git push origin [rama]
```

---

## ❌ Wiki Issues

### Wiki links rotos (404)
**Causa:** Nombre de archivo o capitalizacion incorrecta

**Chequeo:**
- Links deben coincidier exactamente con filenames
- Ejemplos validos:
  - `[Link](Home)` → `wiki/Home.md`
  - `[Link](Architecture)` → `wiki/Architecture.md`

---

## 🎯 Debugging Tips

### 1. Verificar estado del repositorio
```bash
git status                 # Cambios locales
git log --oneline -n 10    # Ultimos commits
git diff HEAD              # Cambios sin stagear
```

### 2. Revisar output de CI
- GitHub > [repo] > Actions > [ultimo workflow]
- Expandir job fallido
- Buscar "error" o "failed"

### 3. Godot Console Output
- Godot > Abrir el proyecto
- Debugger > Console tab
- Revisar errors/warnings

### 4. Network DevTools (web export)
- F12 (en navegador)
- Network tab
- Filtrar por "Failed" para cargas fallidas

---

## 🆘 Si nada funciona

1. **Limpiar todo:**
   ```bash
   git clean -fd              # Borrar archivos no tracked
   git reset --hard HEAD      # Descartar cambios
   rm -rf project/.godot/     # Limpiar cache Godot
   ```

2. **Re-clonar si es necesario:**
   ```bash
   cd ..
   rm -rf e-vidente
   git clone https://github.com/TTIP-e-vidente/e-vidente.git
   ```

3. **Consultar con el team:**
   - Abrir Issue en GitHub con description clara
   - Incluir: SO, version Godot, error exacto
   - Adjuntar logs si es posible

---

## 📞 Quick Reference

| Problema | Comando rápido | Docs |
|---|---|---|
| "Project not found" | `godot --path project &` | [Getting Started](Getting-Started) |
| Build web sin output | Revisar `export_presets.cfg` | [CI](CI) |
| Wiki warning | Actualizar `wiki/Bitacora.md` | [Bitacora](Bitacora) |
| Godot cache corrupto | `rm -rf .godot/` | [Troubleshooting](#limpiar-todo) |
