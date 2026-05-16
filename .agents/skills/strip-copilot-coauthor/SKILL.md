---
name: strip-copilot-coauthor
description: "Remueve automaticamente trailers Co-authored-by de Copilot/Autopilot en commits y limpia historial de dev cuando sea necesario."
license: MIT
compatibility: Git repository
metadata:
  author: local
  version: "1.0"
  type: utility
  mode: assistive
  domain: git
---

# Strip Copilot Co-Author

Usar esta skill cuando se pida:
- quitar co-authors de Copilot/Autopilot en una rama,
- prevenir que vuelvan a aparecer en commits nuevos,
- preparar una rama para PR sin trailers de Copilot/Autopilot.

## Objetivo

Eliminar lineas de trailer con este patron (case-insensitive):

`Co-authored-by: ...copilot...`

`Co-authored-by: ...autopilot...`

## Flujo recomendado

1. Crear backup de la rama antes de reescritura.
2. Limpiar historial de la rama objetivo en el rango seguro (normalmente `main..dev`).
3. Forzar push con `--force-with-lease`.
4. Dejar hook de `commit-msg` activo para prevenir recurrencias.

## Comandos de limpieza de historial (rama actual)

```bash
git branch backup/<rama>-before-strip-$(date +%Y%m%d)
git filter-branch --force --msg-filter "perl -ne 'print unless /^Co-authored-by:.*(?:copilot|autopilot)/i'" main..HEAD
git push origin HEAD --force-with-lease
```

## Hook preventivo

Este repositorio incluye `.githooks/commit-msg` para limpiar trailers antes de crear el commit.

Activacion local:

```bash
git config core.hooksPath .githooks
```

Verificacion:

```bash
git config --get core.hooksPath
```

## Verificacion final

```bash
git log main..HEAD --grep='Co-authored-by:.*(copilot|autopilot)' -i --extended-regexp --format='%H %s'
```

El resultado debe ser vacio.
