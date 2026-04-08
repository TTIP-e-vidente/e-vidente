# Getting Started

Esta guia sirve para levantar el proyecto por primera vez sin perder tiempo en vueltas innecesarias.

## Requisitos

- Godot 4.6.2 estable.
- Git instalado y configurado.
- Acceso al repositorio para trabajar con ramas y pull requests.

## Clonar e importar el proyecto

```bash
git clone https://github.com/TTIP-e-vidente/e-vidente.git
cd e-vidente
```

Despues, importar el proyecto en Godot:

1. Abrir Godot Hub o el editor.
2. Ir a `Project > Import`.
3. Seleccionar `project/project.godot`.
4. Abrirlo con Godot 4.6.2.
5. Esperar la importacion inicial.

## Carpetas importantes

| Carpeta | Uso |
|---|---|
| `project/` | Juego Godot: escenas, scripts y recursos |
| `project/interface/` | Escenas y logica de UI |
| `project/items/` | Datos de alimentos (`.tres`) |
| `project/niveles/` | Configuracion de niveles y escenarios |
| `project/resources/` | Configuracion general |
| `wiki/` | Documentacion del proyecto |
| `.github/workflows/` | Workflow de CI |

## Flujo recomendado

1. Crear una rama de trabajo, por ejemplo `feature/nombre` o `fix/nombre`.
2. Hacer cambios chicos y probarlos dentro del editor.
3. Si tocaste escenas, recursos o flujos jugables, correr la validacion local antes del push.
4. Committear con un mensaje claro.
5. Si el cambio afecta el juego o el flujo de trabajo, actualizar `wiki/Bitacora.md`.
6. Abrir el pull request cuando el cambio ya este probado.

## Validacion local recomendada

En Windows:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run-godot-validation.ps1
```

Si `godot` no esta en PATH:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run-godot-validation.ps1 -GodotCommand "C:\ruta\a\Godot_v4.6.2-stable_win64.exe"
```

En shell:

```bash
sh scripts/run-godot-validation.sh --run full godot
```

## Antes de abrir un PR

- [ ] El proyecto abre en Godot sin errores criticos.
- [ ] Las escenas modificadas funcionan como se esperaba.
- [ ] Los cambios se probaron localmente.
- [ ] La descripcion del PR explica que cambio y por que.
- [ ] Si hubo cambios relevantes en `project/`, quedo registro en `wiki/Bitacora.md`.
- [ ] La CI pasa en `Guardrails` y `Core Validation`.

`Optional Web Export Build` es manual y no forma parte del gate normal del PR.

## Problemas comunes

### El proyecto no importa

- Verificar que `project/project.godot` exista.
- Borrar `project/.godot/` y volver a importar si la cache quedo en mal estado.

### Faltan recursos

- Forzar una reimportacion desde `Project > Tools > Reimport`.

### El export web no genera `index.html`

- Revisar `project/export_presets.cfg`.
- Verificar si la salida quedo en `build/web` o en alguna carpeta de export alternativa.

### La CI marca falta de actualizacion en la wiki

- Eso suele pasar cuando hubo cambios en `project/` sin reflejo en `wiki/`.
- En ese caso, alcanza con dejar una nota breve en `wiki/Bitacora.md`.