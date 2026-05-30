# Decisiones — Entrega 2

## Criterio general del sprint

Durante esta iteración se priorizó la Opción A definida en los próximos pasos de Entrega 1: profundizar la experiencia dentro del mapa de Celiaquía. Consolidar el polish visual, las transiciones, las felicitaciones y la nueva modalidad de Completar Palabra. También se incorporó la primera infraestructura de testing automatizado.

---

## Decisiones tomadas

| Decisión | Motivo | Impacto | Pendiente |
|---|---|---|---|
| Implementar nueva modalidad de juego | Mayor jugabilidad | Mayor variabilidad en cuanto a modos de juego | No |
| Implementar GameSceneRouter como único punto de navegación | Evitar que cada escena manejara sus propias transiciones | Navegación centralizada, más fácil de mantener y extender | No |
| Incorporar GdUnit4 v6.1.3 localmente (ignorado en git) | v6.0.0 del AssetLib era incompatible con Godot 4.6.x (`get_as_text()` roto) | Tests corren correctamente en Godot 4.6.x; el plugin no se versiona | No |
| No abrir backend todavía | El sprint se enfocó en gameplay y estética; backend agrega complejidad sin impacto visible en la demo  | Demo sigue limpia y sin dependencias externas | Sí —  Entrega 3 |
| Priorizar renovación estética en todas las pantallas | Necesitaba coherencia visual | Experiencia visualmente consistente en todo el recorrido | No |
---

## Cambios de prioridad durante el sprint

Se priorizó durante el sprint:
- renovación visual completa y coherente;
- transiciones de escena como parte del polish;
- completar modalidades ya planificadas (Completar Palabra);
- primera cobertura de tests automatizados;
- corrección de bugs introducidos durante la renovación gráfica.

Quedaron para revisar después:
- Backend y autenticación;
- Otras restricciones alimentarias (Cetogénica, Veganismo, Vegan-GF);
- Perfil del usuario.
