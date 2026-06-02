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
        INSERT INTO player_profiles (user_id, exp_count, current_restriction)
        VALUES ($1, 20, 'CELIAQUIA')
        RETURNING id, exp_count;
      `,
      [user.id]
    );
    const profile = profileResult.rows[0];

    const streakResult = await pool.query<{ id: string; current_count: number }>(
      `
        INSERT INTO player_streaks (user_id, current_count, best_count, last_activity_day)
        VALUES ($1, 1, 1, CURRENT_DATE)
        RETURNING id, current_count;
      `,
      [user.id]
    );
    const streak = streakResult.rows[0];

    const progressResult = await pool.query<{
      id: string;
      restriction_type: string;
      total_exp: number;
    }>(
      `
        INSERT INTO player_progress (
          user_id,
          restriction_type,
          total_exp,
          completed_nodes_count,
          completed_games_count
        )
        VALUES ($1, 'CELIAQUIA', 20, 1, 1)
        RETURNING id, restriction_type, total_exp;
      `,
      [user.id]
    );
    const progress = progressResult.rows[0];

    const gameSessionResult = await pool.query<{
      id: string;
      accuracy: string;
      completed: boolean;
    }>(
      `
        INSERT INTO game_sessions (
          user_id,
          progress_id,
          game_type,
          node_id,
          accuracy,
          completed,
          score,
          completed_at
        )
        VALUES ($1, $2, 'quiz', 'integration_node', 90, true, 10, now())
        RETURNING id, accuracy, completed;
      `,
      [user.id, progress.id]
    );
    const gameSession = gameSessionResult.rows[0];

    const completedNodeResult = await pool.query<{ id: string; node_id: string }>(
      `
        INSERT INTO completed_nodes (
          user_id,
          progress_id,
          node_id,
          node_type,
          best_score,
          best_accuracy
        )
        VALUES ($1, $2, 'integration_node', 'quiz', 10, 90)
        RETURNING id, node_id;
      `,
      [user.id, progress.id]
    );
    const completedNode = completedNodeResult.rows[0];

    const readResult = await pool.query<{
      username: string;
      profile_id: string;
      streak_id: string;
      restriction_type: string;
      game_session_id: string;
      completed_node_id: string;
      accuracy: string;
      completed: boolean;
    }>(
      `
        SELECT
          u.username,
          pp.id AS profile_id,
          ps.id AS streak_id,
          pg.restriction_type,
          gs.id AS game_session_id,
          cn.id AS completed_node_id,
          gs.accuracy,
          gs.completed
        FROM users u
        JOIN player_profiles pp ON pp.user_id = u.id
        JOIN player_streaks ps ON ps.user_id = u.id
        JOIN player_progress pg ON pg.user_id = u.id
        JOIN game_sessions gs ON gs.progress_id = pg.id
        JOIN completed_nodes cn ON cn.progress_id = pg.id
        WHERE u.username = $1;
      `,
      [username]
    );

    assert.equal(readResult.rowCount, 1);
    assert.equal(readResult.rows[0].username, user.username);
    assert.equal(readResult.rows[0].profile_id, profile.id);
    assert.equal(readResult.rows[0].streak_id, streak.id);
    assert.equal(readResult.rows[0].restriction_type, 'CELIAQUIA');
    assert.equal(readResult.rows[0].game_session_id, gameSession.id);
    assert.equal(readResult.rows[0].completed_node_id, completedNode.id);
    assert.equal(Number(readResult.rows[0].accuracy), 90);
    assert.equal(readResult.rows[0].completed, true);
    assert.equal(profile.exp_count, 20);
    assert.equal(streak.current_count, 1);
    assert.equal(progress.total_exp, 20);
    assert.equal(completedNode.node_id, 'integration_node');
    assert.equal(gameSession.completed, true);

    console.log('postgres integration test passed');
  } finally {
    await pool.query('DELETE FROM users WHERE username = $1;', [username]);
    await pool.end();
  }
}

run().catch(async (error) => {
  console.error(error);
  await pool.end();
  process.exit(1);
});
