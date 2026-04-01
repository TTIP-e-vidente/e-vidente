# CI

Esta pagina explica que hace el workflow de integracion continua en este repositorio.

## Objetivo

Detectar problemas temprano sin bloquear iteraciones cuando el contexto del proyecto aun esta en evolucion.

## Workflow actual

Archivo: `.github/workflows/ci.yml`

Se ejecuta en:

- push
- pull_request
- workflow_dispatch

### Jobs

1. quality (non-blocking)
- Valida estructura minima del repositorio.
- Ejecuta ESLint solo si existe configuracion Node + ESLint.
- Verifica baseline de documentacion (README, wiki/Home, wiki/Bitacora).
- Emite recordatorio si hubo cambios en project/ sin cambios en wiki/.
- Publica un resumen rapido en GITHUB_STEP_SUMMARY.

2. validate
- Corre en contenedor `barichello/godot-ci:4.2`.
- Hace checkout.
- Usa cache para import data de Godot.
- Ejecuta import headless del proyecto.

3. build-web
- Depende de validate y quality.
- Exporta build web a build/web.
- Si Godot exporta en otra carpeta, intenta normalizar copia.
- Verifica salida (html y paquete web) en modo no bloqueante.

## Que es bloqueante y que no

- quality: no bloquea (usa continue-on-error en pasos).
- validate: bloqueante.
- build-web: bloqueante en export principal; verificacion final es de advertencia.

## Como leer resultados

- Fallo en validate o build-web: requiere correccion antes de merge.
- Warnings en quality: no frenan merge, pero indican deuda tecnica/documental.

## Mantenimiento recomendado

- Si cambias estructura del repo, actualizar listas REQUIRED_DIRS y REQUIRED_FILES.
- Si adoptas lint JS/TS, mantener package.json y config ESLint validos.
- Cuando cambies gameplay, escenas o assets en project/, sumar nota en Bitacora.
