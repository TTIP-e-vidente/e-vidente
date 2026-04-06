# Wiki de e-vidente

Esta wiki reúne la documentación técnica y funcional del proyecto.

e-vidente es un juego de puzzle educativo sobre alimentación, restricciones alimentarias y conciencia nutricional.

## Por dónde empezar

- [Getting Started](Getting-Started): preparación del entorno y puesta en marcha local.
- [Architecture](Architecture): estructura general del proyecto y ubicación de los sistemas principales.
- [Persistencia Local](Persistencia-Local): perfil local, guardado de partidas y reanudación.
- [CI](CI): validaciones automáticas y export web.
- [Bitacora](Bitacora): cambios recientes y decisiones que conviene dejar registradas.

## Estructura del proyecto

```
e-vidente/
├── project/          # Juego Godot 4.6.2
│  ├── interface/     # Escenas y UI
│  ├── items/         # Recursos de alimentos
│  ├── niveles/       # Datos de escenarios
│  └── resources/     # Configuración
├── wiki/             # Documentación del proyecto
├── .github/          # GitHub Actions
└── README.md         # Resumen general del repo
```

## Forma de trabajo

1. Crear una rama para el cambio.
2. Hacer cambios chicos y fáciles de revisar.
3. Probar en Godot antes de abrir el PR.
4. Si el cambio toca `project/` y afecta un flujo real, dejar una nota en [Bitacora](Bitacora).
5. Revisar la CI y corregir cualquier fallo antes de mergear.

## Estado general

- La wiki funciona como documentación viva del repo.
- La CI valida estructura, documentación, tests de guardado y export web.
- La persistencia local está documentada y cubierta por tests headless.
- El criterio general sigue siendo el mismo: cambios cortos, trazables y bien entendidos.
