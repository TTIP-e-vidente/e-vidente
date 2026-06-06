/**
 * Claves de restricciones alimentarias válidas en el sistema.
 * Deben coincidir con validRestrictions en validators.ts y con
 * los valores en restriction_node_config (DB).
 *
 * Los conteos de nodos por restricción viven en la tabla
 * restriction_node_config (migración 010), populada desde los
 * JSON de mapa de Godot (ej: celiaquia_mapa.json).
 */
export const VALID_RESTRICTIONS = ['CELIAQUIA', 'VEG', 'VYG', 'KETO'] as const;
export type Restriction = (typeof VALID_RESTRICTIONS)[number];
