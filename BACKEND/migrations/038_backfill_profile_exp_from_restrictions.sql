-- 038_backfill_profile_exp_from_restrictions.sql
--
-- Corrige la desincronización entre profiles.exp_count y progress_restrictions.total_exp.
--
-- Contexto del bug:
--   * El leaderboard global y el "EXP total" del perfil leen profiles.exp_count,
--     un contador denormalizado que solo se INCREMENTA (addProfileExp) al guardar
--     progreso online.
--   * El XP real por restricción vive en progress_restrictions.total_exp.
--   * Datos que llegaron por seed/import/migración legacy (o restablecimientos
--     previos) dejaron profiles.exp_count = 0 aunque total_exp > 0.
--   * El leaderboard filtra `WHERE COALESCE(exp_count, 0) > 0`, así que esos
--     jugadores quedaban EXCLUIDOS del ranking (solo aparecía quien jugó online),
--     y su perfil mostraba el ranking vacío / en 0.
--
-- Este backfill recalcula exp_count desde la fuente de verdad (la suma de total_exp
-- de todas las restricciones del usuario). A partir de acá, el reset de progreso
-- mantiene el invariante vía recomputeProfileExpFromRestrictions().
--
-- Tras aplicar esta migración conviene refrescar el snapshot del leaderboard
-- (job `refresh-leaderboard` o esperar al cron horario) para reflejar los cambios.

UPDATE profiles p
SET
  exp_count = COALESCE((
    SELECT SUM(pr.total_exp)
    FROM progress_restrictions pr
    WHERE pr.user_id = p.user_id
  ), 0),
  updated_at = now()
WHERE exp_count IS DISTINCT FROM COALESCE((
  SELECT SUM(pr.total_exp)
  FROM progress_restrictions pr
  WHERE pr.user_id = p.user_id
), 0);
