import assert from 'assert/strict';
import { pool } from '../src/config/database';

async function run(): Promise<void> {
  const username = `integration_player_${Date.now()}`;

  try {
    const userResult = await pool.query<{ id: string; username: string }>(
      `
        INSERT INTO users (username, name)
        VALUES ($1, 'Integration Player')
        RETURNING id, username;
      `,
      [username]
    );
    const user = userResult.rows[0];

    const profileResult = await pool.query<{ id: string; exp_count: number }>(
      `
        INSERT INTO profiles (user_id, exp_count, current_restriction)
        VALUES ($1, 20, 'CELIAQUIA')
        RETURNING id, exp_count;
      `,
      [user.id]
    );
    const profile = profileResult.rows[0];

    const streakResult = await pool.query<{ id: string; current_count: number }>(
      `
        INSERT INTO streaks (current_count, best_count, last_activity_day)
        VALUES (1, 1, CURRENT_DATE)
        RETURNING id, current_count;
      `,
      []
    );
    const streak = streakResult.rows[0];

    await pool.query(
      `
        UPDATE profiles
        SET streak_id = $2
        WHERE id = $1;
      `,
      [profile.id, streak.id]
    );

    const progressResult = await pool.query<{
      id: string;
      restriction_type: string;
      total_exp: number;
    }>(
      `
        INSERT INTO progress_restrictions (
          user_id,
          profile_id,
          restriction,
          total_exp,
          completed_nodes_count,
          completed_games_count
        )
        VALUES ($1, $2, 'CELIAQUIA', 20, 1, 1)
        RETURNING id, restriction AS restriction_type, total_exp;
      `,
      [user.id, profile.id]
    );
    const progress = progressResult.rows[0];

    const historyResult = await pool.query<{ id: string }>(
      `
        INSERT INTO history_games (
          progress_id, user_id, node_id, node_type, completed, best_score, best_accuracy, completed_at
        )
        VALUES ($1, $2, 'integration_node', 'quiz', true, 10, 90, now())
        RETURNING id;
      `,
      [progress.id, user.id]
    );
    const history = historyResult.rows[0];

    const gameResult = await pool.query<{
      id: string;
      accuracy: string;
      completed: boolean;
    }>(
      `
        INSERT INTO games (
          history_id,
          user_id,
          progress_id,
          game_type,
          node_id,
          accuracy,
          completed,
          score,
          completed_at
        )
        VALUES ($1, $2, $3, 'quiz', 'integration_node', 90, true, 10, now())
        RETURNING id, accuracy, completed;
      `,
      [history.id, user.id, progress.id]
    );
    const game = gameResult.rows[0];

    const readResult = await pool.query<{
      username: string;
      profile_id: string;
      streak_id: string;
      restriction_type: string;
      game_id: string;
      history_id: string;
      accuracy: string;
      completed: boolean;
    }>(
      `
        SELECT
          u.username,
          p.id AS profile_id,
          s.id AS streak_id,
          pr.restriction AS restriction_type,
          g.id AS game_id,
          hg.id AS history_id,
          g.accuracy,
          g.completed
        FROM users u
        JOIN profiles p ON p.user_id = u.id
        JOIN streaks s ON s.id = p.streak_id
        JOIN progress_restrictions pr ON pr.profile_id = p.id
        JOIN history_games hg ON hg.progress_id = pr.id
        JOIN games g ON g.history_id = hg.id
        WHERE u.username = $1;
      `,
      [username]
    );

    assert.equal(readResult.rowCount, 1);
    assert.equal(readResult.rows[0].username, user.username);
    assert.equal(readResult.rows[0].profile_id, profile.id);
    assert.equal(readResult.rows[0].streak_id, streak.id);
    assert.equal(readResult.rows[0].restriction_type, 'CELIAQUIA');
    assert.equal(readResult.rows[0].game_id, game.id);
    assert.equal(readResult.rows[0].history_id, history.id);
    assert.equal(Number(readResult.rows[0].accuracy), 90);
    assert.equal(readResult.rows[0].completed, true);
    assert.equal(profile.exp_count, 20);
    assert.equal(streak.current_count, 1);

    console.log('postgres.integration.test.ts OK');
  } finally {
    await pool.query(`DELETE FROM users WHERE username = $1;`, [username]);
    await pool.end();
  }
}

run().catch((error) => {
  console.error(error);
  process.exit(1);
});
