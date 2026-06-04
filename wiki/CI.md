# CI

PR a `main` o `dev` (y `workflow_dispatch` manual).

| Workflow | Archivo | Qué hace |
|----------|---------|----------|
| Technical Health | `ci.yml` | Estructura (`check-structure-guardrails.sh`) + lint si hay ESLint |
| Gameplay Smoke | `gameplay-smoke-pr.yml` | Import headless + `vertical_slice_smoke_test.gd` |
| Docs PR | `docs-pr.yml` | Docs base + cambios en código requieren nota en wiki |

Godot 4.6.2 en CI. Smoke vía `scripts/run-godot-validation.sh` (path `juego/`).

**Si falla import:** parse, autoload o ruta rota.  
**Si falla smoke:** se rompió el slice celiaquía (splash → gameplay).  
**Docs PR:** tocar `wiki/Bitacora-Entrega-3.md` (o otro `wiki/Bitacora*.md`) + algún `.md` en wiki/docs.  
**Logs:** artifact `gameplay-smoke-logs-run-*` (14 días).

## Local

```sh
sh scripts/run-godot-validation.sh --run smoke godot
```

```powershell
./scripts/run-godot-validation.ps1 -Mode smoke
```
