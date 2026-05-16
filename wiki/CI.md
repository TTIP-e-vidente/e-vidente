# 🔄 Integración Continua

Documentación de los workflows de GitHub Actions activos en el proyecto.

---

## 🎯 Objetivo

Detectar problemas **antes de mergear** sin bloquear iteraciones. Todos los workflows corren en PR hacia `main` o `dev`.

---

## 📋 Workflows activos

| Workflow | Archivo | Cuándo corre | Qué protege |
|---|---|---|---|
| **Technical Health** | `ci.yml` | PR a main/dev + manual | Estructura del repo y linting |
| **Gameplay Smoke PR** | `gameplay-smoke-pr.yml` | PR a main/dev + manual | Que el proyecto abra y el slice principal llegue a gameplay |
| **Docs PR** | `docs-pr.yml` | PR a main/dev | Que el PR tenga documentación suficiente |

---

## 1️⃣ Technical Health (`ci.yml`)

**Jobs:**

### `structure` — Estructura del repo

- Valida que existan los directorios y archivos críticos esperados
- Script: `scripts/ci/check-structure-guardrails.sh`

### `lint` — Linting

- Ejecuta ESLint si existe `package.json` con config ESLint
- Script: `scripts/ci/check-lint-guardrails.sh`

**Warnings comunes:**
- Directorio o archivo crítico faltante → revisar `check-structure-guardrails.sh`

---

## 2️⃣ Gameplay Smoke PR (`gameplay-smoke-pr.yml`)

**Contenedor:** `barichello/godot-ci:4.6.2`
**Timeout:** 12 minutos

**Qué hace:**
1. Import headless: `godot --headless --path project --editor --quit`
2. Vertical slice smoke test: `godot --headless --path project -s res://tests/vertical_slice_smoke_test.gd`

**Flujo que cubre:** `Splash → Intro → Selector → Archivero → Libro → Gameplay`

**Baseline:** track `celiaquia`, capítulo `1`

**Si falla `Import headless`** → problema antes del gameplay (parse error, autoload, ruta rota)
**Si falla `Gameplay smoke test`** → se rompió el slice principal

**Logs:** se suben como artifact `gameplay-smoke-logs-run-N-attempt-N` (14 días de retención)

---

## 3️⃣ Docs PR (`docs-pr.yml`)

**Qué hace:**
- Verifica que existan los archivos de documentación base
- Chequea que el PR incluya actualizaciones de docs si tocó código
- Scripts: `scripts/ci/check-docs-guardrails.sh` + `scripts/ci/check-pr-docs.sh`

---

## 🟢 🟡 🔴 Cómo interpretar resultados

| Estado | Significa | Acción |
|---|---|---|
| ✅ Todos pasan | Todo bien | Listo para merge |
| ❌ `structure` falla | Falta dir/archivo crítico | Revisar `check-structure-guardrails.sh` |
| ❌ `lint` falla | Error de linting | Corregir antes de merge |
| ❌ `Import headless` falla | Error en proyecto Godot | Corregir parse error o autoload roto |
| ❌ `Gameplay smoke` falla | Se rompió el flujo principal | Revisar escena o contrato mínimo del slice |
| ❌ `Docs PR` falla | PR sin documentación suficiente | Agregar entrada en Bitácora o docs |

---

## 🔧 Correr localmente

```sh
# Smoke test
sh scripts/run-godot-validation.sh --run smoke godot
```

```powershell
# PowerShell
./scripts/run-godot-validation.ps1 -Mode smoke
```
