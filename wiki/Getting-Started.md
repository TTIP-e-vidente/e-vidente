# Getting Started

Guia corta para iniciar trabajo sobre e-vidente sin friccion.

## Requisitos

- Godot 4.2 o compatible con el proyecto.
- Git instalado.
- Acceso al repositorio y permisos para push/PR.

## Clonar y abrir

1. Clonar el repositorio.
2. Abrir Godot y seleccionar Import.
3. Elegir project/project.godot.
4. Confirmar que Godot complete la importacion inicial.

## Estructura minima

- project/: juego, escenas, scripts y recursos.
- wiki/: documentacion operativa y de seguimiento.
- .github/workflows/: pipelines de CI.

## Flujo de trabajo sugerido

1. Crear rama de feature/fix.
2. Implementar cambios en bloques pequenos.
3. Si tocas project/, actualizar wiki/Home o wiki/Bitacora.
4. Abrir PR y revisar la ejecucion de CI.

## Checklist antes de PR

- El proyecto abre sin errores criticos en Godot.
- El cambio esta descrito en la PR.
- La wiki refleja cambios funcionales o tecnicos.
- CI ejecuta validate y build-web correctamente.

## Problemas comunes

- Faltan archivos esperados por CI: revisar estructura en project/ y wiki/.
- Export web sin index.html: verificar preset de export y salida final.
- Warning de wiki reminder: agregar nota breve en Bitacora.
