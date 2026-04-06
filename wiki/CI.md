# CI Pipeline

El workflow de CI busca dos cosas: detectar roturas temprano y mantener el repo en un estado publicable sin meter fricción innecesaria en el trabajo diario.

## Archivo y disparadores

El workflow vive en `.github/workflows/ci.yml` y corre en tres casos:

- `push`
- `pull_request`
- `workflow_dispatch`

También usa concurrencia por rama para cancelar ejecuciones viejas cuando entra un commit nuevo.

## Jobs actuales

### `quality`

Es el job más liviano y no bloquea el pipeline.

Revisa:

- estructura mínima del repo
- documentación base (`README.md`, `wiki/Home.md`, `wiki/Bitacora.md`)
- ESLint si el repo llegara a tener configuración Node válida
- recordatorios cuando hay cambios en `project/` sin cambios en `wiki/`

Si falla algo acá, normalmente no es un error de runtime sino una deuda de documentación o de orden del repo.

### `validate`

Este job sí bloquea. Corre dentro de `barichello/godot-ci:4.6.2-stable`.

Hace lo siguiente:

- importa el proyecto en modo headless
- corre smoke test de guardado local
- valida perfil, avatar y recarga desde disco
- valida el contrato de señales de `SaveManager`
- prueba la migración desde saves legacy
- prueba el overlay de Archivero
- prueba el flujo de Intro para continuar la ultima partida o ir al selector de modos
- prueba el guardado rápido desde nivel

Cuando falla, casi siempre el problema está en alguno de estos puntos:

- sintaxis GDScript o escenas rotas
- rutas inválidas en `.tscn`
- regresiones en persistencia local
- cambios de UI que rompen el flujo que cubren los tests

### `build-web`

Este job espera a `validate` y `quality`.

Su trabajo es:

- importar el proyecto
- exportar el preset `index`
- normalizar la salida en `build/web/index.html`
- verificar que haya artefactos de export razonables
- subir `build/web` como artifact de GitHub Actions

El workflow actual no despliega a GitHub Pages. Hoy el resultado del build web queda como artifact descargable.

## Validacion local recomendada

Para no depender solo de CI, conviene correr localmente la misma suite antes de pushear.

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
sh scripts/run-godot-validation.sh --run godot
```

Y si queres incluir export web en Windows:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run-godot-validation.ps1 -IncludeExport
```

## Cómo leer una falla

- Si falla `quality`, suele ser una deuda de documentación o estructura.
- Si falla `validate`, hay una rotura real en el proyecto o en los tests headless.
- Si falla `build-web`, el export dejó de ser consistente y hay que revisar `export_presets.cfg` o la salida del preset.

## Mantenimiento

Si cambia la estructura del repo, hay que revisar las listas `REQUIRED_DIRS` y `REQUIRED_FILES` del job `quality`.

Si cambia un flujo importante del juego, conviene sumar o ajustar un test headless en `project/tests/`.

Si cambia el export web, hay que revisar tanto `export_presets.cfg` como la ruta final que usa el workflow para publicar el artifact.
