# Getting Started

Esta guía sirve para levantar el proyecto por primera vez sin perder tiempo en vueltas innecesarias.

## Requisitos

- Godot 4.6.2 estable.
- Git instalado y configurado.
- Acceso al repositorio para trabajar con ramas y pull requests.

## Clonar e importar el proyecto

Primero, clonar el repo y activar los hooks locales:

```bash
git clone https://github.com/TTIP-e-vidente/e-vidente.git
cd e-vidente
powershell -ExecutionPolicy Bypass -File scripts/setup-git-hooks.ps1
```

Después, importar el proyecto en Godot:

1. Abrir Godot Hub o el editor.
2. Ir a `Project > Import`.
3. Seleccionar `project/project.godot`.
4. Abrirlo con Godot 4.6.2.
5. Esperar la importación inicial.

## Carpetas importantes

| Carpeta | Uso |
|---|---|
| `project/` | Juego Godot: escenas, scripts y recursos |
| `project/interface/` | Escenas y lógica de UI |
| `project/items/` | Datos de alimentos (`.tres`) |
| `project/niveles/` | Configuración de niveles y escenarios |
| `project/resources/` | Configuración general |
| `wiki/` | Documentación del proyecto |
| `.github/workflows/` | Workflow de CI |

## Flujo recomendado

1. Crear una rama de trabajo, por ejemplo `feature/nombre` o `fix/nombre`.
2. Hacer cambios chicos y probarlos dentro del editor.
3. Committear con un mensaje claro.
4. Si el cambio afecta el juego o el flujo de trabajo, actualizar `wiki/Bitacora.md`.
5. Abrir el pull request cuando el cambio ya esté probado.

## Antes de abrir un PR

- [ ] El proyecto abre en Godot sin errores críticos.
- [ ] Las escenas modificadas funcionan como se esperaba.
- [ ] Los cambios se probaron localmente.
- [ ] La descripción del PR explica qué cambió y por qué.
- [ ] Si hubo cambios relevantes en `project/`, quedó registro en `wiki/Bitacora.md`.
- [ ] La CI pasa completa (`validate` y `build-web`).

## Problemas comunes

### El proyecto no importa

- Verificar que `project/project.godot` exista.
- Borrar `.godot/` y volver a importar si la caché quedó en mal estado.

### Faltan recursos

- Forzar una reimportación desde `Project > Tools > Reimport`.

### El export web no genera `index.html`

- Revisar `export_presets.cfg`.
- Verificar si la salida quedó en `build/web` o en alguna carpeta de export alternativa.

### La CI marca falta de actualización en la wiki

- Eso suele pasar cuando hubo cambios en `project/` sin reflejo en `wiki/`.
- En ese caso, alcanza con dejar una nota breve en `wiki/Bitacora.md`.
