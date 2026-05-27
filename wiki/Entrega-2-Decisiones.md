# Decisiones — Entrega 2

## Criterio general del sprint

Durante esta iteración se priorizó la Opción A definida en los próximos pasos de Entrega 1: profundizar la experiencia dentro del mapa de Celiaquía. La decisión fue no abrir infraestructura externa (backend, autenticación) y en cambio consolidar el polish visual, las transiciones, las felicitaciones y la nueva modalidad de Completar Palabra. También se incorporó la primera infraestructura de testing automatizado.

---

## Decisiones tomadas

| Decisión | Motivo | Alternativa descartada | Impacto | Pendiente |
|---|---|---|---|---|
| Elegir Opción A de Entrega 1 | El juego necesitaba más polish visible antes de abrir infraestructura | Opción B (backend) o Opción C (otras restricciones) | Demo más sólida y defendible en entregas académicas | No |
| Implementar GameSceneRouter como único punto de navegación | Evitar que cada escena manejara sus propias transiciones | Mantener cambios de escena directos | Navegación centralizada, más fácil de mantener y extender | No |
| Crear TypewriterEffect como componente reutilizable | Se necesitaba el efecto tanto en Pregunta como en Arrastre | Implementar inline en cada modalidad por separado | Código sin duplicación; el efecto es consistente en todo el juego | No |
| Reemplazar Globo texto/Meal y Globo texto/Condition con DragObjectiveText | Los nodos viejos eran Sprite2D sin texto dinámico; el nuevo lee desde JSON | Mantener los sprites hardcodeados | El mensaje del objetivo ahora es completamente configurable por nodo | No |
| Incorporar GdUnit4 v6.1.3 localmente (ignorado en git) | v6.0.0 del AssetLib era incompatible con Godot 4.6.x (`get_as_text()` roto) | Usar v6.0.0 del AssetLib o no tener tests | Tests corren correctamente en Godot 4.6.x; el plugin no se versiona | No |
| No abrir backend todavía | El sprint se enfocó en gameplay y estética; backend agrega complejidad sin impacto visible en la demo | Abrir UNQ-90 / UNQ-91 en este sprint | Demo sigue limpia y sin dependencias externas | Sí — próximo candidato para Entrega 3 |
| Priorizar renovación estética en todas las pantallas | La demo se iba a presentar al profesor y necesitaba coherencia visual | Actualizar solo las pantallas más visibles | Experiencia visualmente consistente en todo el recorrido | No |
| Hacer makeovers de diseño coordindados entre ambos integrantes | Margo trabajó estética, Agustín trabajó funcionalidad y tests | División arbitraria de tareas | División clara de responsabilidades sin conflictos | No |

---

## Bugs que influyeron en decisiones

| Commit / tema | Problema detectado | Decisión asociada | Impacto |
|---|---|---|---|
| `970826f` Cambios en arrastre | Margo eliminó `Globo texto/Meal` y `Globo texto/Condition` sin actualizar `manager_level.gd` | Hacer esos sprites opcionales en `_conectar_escena_nodos()` | El nivel de arrastre vuelve a cargar correctamente |
| `3820cfe` Errores dimensiones pregunta | Boton2 en `pregunta.tscn` quedó con dimensiones incorrectas y sin nodos hijo `TextoOpcion` | Restaurar dimensiones originales y agregar `TextoOpcion` igual que Boton3/4/5 | Los botones de 2 opciones vuelven a verse correctamente |
| GdUnit4 v6.0.0 incompatible | `get_as_text()` rompía al cargar en Godot 4.6.x | Instalar v6.1.3 manualmente desde GitHub | Tests funcionan sin errores |

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
- Modalidad selector de imágenes (UNQ-99);
- Pérdida de racha (UNQ-149);
- Perfil del usuario.
