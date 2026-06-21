-- Preparación del sistema de leaderboard para scopes por restricción.
--
-- En lugar de hard-codear restricciones en la DB, se amplía la tabla
-- leaderboard_meta para aceptar cualquier scope dinámico.
-- Los scopes 'restriction:CELIAQUIA', 'restriction:BAJA_VISION', etc.
-- se insertan automáticamente cuando se ejecuta el refresh por restricción.
--
-- Esta migración solo crea el índice funcional necesario para que los scopes
-- por restricción sean eficientes: filtra por progress_restrictions + users
-- para el ranking de XP dentro de una restricción específica.

-- Índice en progress_restrictions para acelerar los rankings por restricción
CREATE INDEX IF NOT EXISTS idx_progress_restrictions_restriction_exp
  ON progress_restrictions(restriction, exp_count DESC);

-- Anotación: cuando el backend genera un scope 'restriction:CELIAQUIA',
-- simplemente hace un INSERT en leaderboard_meta y un INSERT en
-- leaderboard_snapshots con scope = 'restriction:CELIAQUIA'.
-- No requiere cambios en el esquema — el sistema ya es extensible.
COMMENT ON TABLE leaderboard_meta IS
  'Tracking de salud de los snapshots del leaderboard. '
  'scope puede ser: global_xp | streak | restriction:{tipo}';
