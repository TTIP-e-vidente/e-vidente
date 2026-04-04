# 🔄 CI Pipeline

Documentacion del workflow de integracion continua (GitHub Actions).

---

## 🎯 Objetivo

Detectar problemas **temprano** sin bloquear iteraciones, usando validaciones no disruptivas.

## ⚙️ Configuracion

**Archivo:** `.github/workflows/ci.yml`

**Se ejecuta en:**
- `push` (cualquier rama)
- `pull_request` (cualquier rama)
- `workflow_dispatch` (manual)

**Concurrencia:** Solo una ejecucion por rama activa (cancela anteriores)

---

## 📊 Pipeline de Jobs

### 1️⃣ `quality` — Guardrails (Non-blocking) ⚠️

**Que hace:**
- ✓ Valida estructura minima del repo (directorios y archivos esperados)
- ✓ Ejecuta ESLint si existe config Node + ESLint
- ✓ Verifica documentacion base (README, wiki/Home, wiki/Bitacora)
- ✓ Emite recordatorio si hubo cambios en `project/` sin cambios en `wiki/`
- ✓ Genera resumen de calidad

**Bloquea?** NO — todos los pasos usan `continue-on-error`

**Warnings comunes:**
- "Missing required file wiki/Bitacora.md" → crear el archivo
- "Project files changed without wiki updates" → agregar entrada en Bitacora

---

### 2️⃣ `validate` — Godot Import + Save Tests (Blocking) ✅

**Que hace:**
- Corre en contenedor `barichello/godot-ci:4.2`
- Descarga proyecto
- ReUtiliza cache de imports previos
- Ejecuta import headless: `godot --headless --path project --editor --quit`
- Ejecuta smoke test de guardado local: `godot --headless --path project -s res://tests/save_manager_smoke_test.gd`
- Ejecuta test de validaciones y recarga desde disco: `godot --headless --path project -s res://tests/save_manager_validation_test.gd`
- Ejecuta test de contrato de señales del save: `godot --headless --path project -s res://tests/save_manager_signal_contract_test.gd`
- Ejecuta test de migracion desde saves legacy: `godot --headless --path project -s res://tests/save_manager_legacy_migration_test.gd`

**Bloquea?** SI — Si falla, detiene resto de pipeline

**Razon de fallo comun:**
- Archivos Godot (.tscn, .gd) con syntax invalido
- Paths rotos en escenas
- El flujo de registro/login/guardado local deja de funcionar
- Las validaciones del registro/login o la recarga del save quedaron inconsistentes

---

### 3️⃣ `build-web` — Export Web (Blocking) ✅

**Dependencias:** Espera a `validate` + `quality`

**Que hace:**
- Importa proyecto (cached)
- Exporta a preset "index" → `build/web/index.html`
- Si Godot lo exporta a otro lugar, intenta copiar
- Verifica salida (*.html + *.pck/zip existentes)

**Bloquea?** SI en export; NO en verificacion final

**Razon de fallo comun:**
- `export_presets.cfg` sin preset "index"
- Templates web faltantes en contenedor Godot

---

## 🟢 🟡 🔴 Como interpretar resultados

| Estado | Significa | Accion |
|---|---|---|
| ✅ Todos pasan | Todo bien | Listo para merge |
| ⚠️ quality warnings | Deuda documental | Considerar fix pero no bloquea |
| ❌ validate falla | Error en proyecto Godot o en smoke test | Corregir antes de merge |
| ❌ build-web falla | Export no funciona | Revisar export_presets.cfg |

---

## 🔧 Mantenimiento

Si cambias estructura del repo:

```bash
# Editar .github/workflows/ci.yml
# Actualizar listas REQUIRED_DIRS y REQUIRED_FILES

REQUIRED_DIRS=(
  ".github/workflows"
  "project"
  "project/interface"
  # Agregar aqui si creas nuevas carpetas criticas
)
```

Si adoptas linting:
- Mantener `package.json` y config ESLint validos
- Actualizar pasos de quality job

Si changes gameplay/escenas:
- Siempre sumar nota en `wiki/Bitacora.md`
