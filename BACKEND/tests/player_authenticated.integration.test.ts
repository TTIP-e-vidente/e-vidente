import assert from 'assert/strict';
import { AddressInfo } from 'net';
import { app } from '../src/app';
import { pool } from '../src/config/database';

type JsonObject = Record<string, unknown>;

async function requestJson(
  baseUrl: string,
  path: string,
  options: RequestInit = {}
): Promise<{ status: number; body: JsonObject }> {
  const response = await fetch(`${baseUrl}${path}`, {
    ...options,
    headers: {
      'Content-Type': 'application/json',
      ...(options.headers ?? {})
    }
  });

  const text = await response.text();
  let body: JsonObject = {};
  try {
    body = text ? (JSON.parse(text) as JsonObject) : {};
  } catch {
    body = {};
  }

  return { status: response.status, body };
}

function getString(value: unknown): string {
  assert.equal(typeof value, 'string');
  return value as string;
}

async function run(): Promise<void> {
  const server = app.listen(0);
  const address = server.address() as AddressInfo;
  const baseUrl = `http://127.0.0.1:${address.port}`;
  const suffix = Date.now();
  const username = `player_auth_${suffix}`;
  const mail = `player_auth_${suffix}@test.com`;
  const otherUsername = `player_auth_other_${suffix}`;
  const otherMail = `player_auth_other_${suffix}@test.com`;
  const updatedMail = `updated_${suffix}@test.com`;
  const password = 'Password123';

  try {
    await pool.query(
      'DELETE FROM users WHERE username = ANY($1::text[]) OR mail = ANY($2::text[]);',
      [[username, otherUsername], [mail, updatedMail, otherMail]]
    );

    const registerResponse = await requestJson(baseUrl, '/auth/register', {
      method: 'POST',
      body: JSON.stringify({
        username,
        name: 'Player Auth',
        mail,
        password,
        birth_date: '2000-06-15'
      })
    });
    assert.equal(registerResponse.status, 201);
    const token = getString(registerResponse.body.accessToken);
    const headers = { Authorization: `Bearer ${token}` };

    const playerMeResponse = await requestJson(baseUrl, '/player/me', {
      method: 'GET',
      headers
    });
    assert.equal(playerMeResponse.status, 200);
    assert.equal((playerMeResponse.body.user as JsonObject).username, username);
    assert.equal('password_hash' in (playerMeResponse.body.user as JsonObject), false);
    assert.ok(playerMeResponse.body.profile);
    assert.ok(playerMeResponse.body.streak);

    const missingTokenResponse = await requestJson(baseUrl, '/player/me', { method: 'GET' });
    assert.equal(missingTokenResponse.status, 401);

    const missingProgressTokenResponse = await requestJson(baseUrl, '/player/me/progress', {
      method: 'GET'
    });
    assert.equal(missingProgressTokenResponse.status, 401);

    const missingRestrictionResponse = await requestJson(baseUrl, '/player/me/progress', {
      method: 'POST',
      headers,
      body: JSON.stringify({ expToAdd: 10 })
    });
    assert.equal(missingRestrictionResponse.status, 400);

    const invalidRestrictionResponse = await requestJson(baseUrl, '/player/me/progress', {
      method: 'POST',
      headers,
      body: JSON.stringify({ restriction: 'PALEO', expToAdd: 10 })
    });
    assert.equal(invalidRestrictionResponse.status, 400);

    const invalidAccuracyResponse = await requestJson(baseUrl, '/player/me/progress', {
      method: 'POST',
      headers,
      body: JSON.stringify({ restriction: 'CELIAQUIA', accuracy: 120 })
    });
    assert.equal(invalidAccuracyResponse.status, 400);

    const progressPayload = {
      restriction: 'CELIAQUIA',
      expToAdd: 10,
      nodeId: `demo_node_${suffix}`,
      gameType: 'quiz',
      accuracy: 90,
      completed: true,
      score: 100
    };
    const saveProgressResponse = await requestJson(baseUrl, '/player/me/progress', {
      method: 'POST',
      headers,
      body: JSON.stringify(progressPayload)
    });
    assert.equal(saveProgressResponse.status, 201);
    assert.equal((saveProgressResponse.body.user as JsonObject).username, username);

    const progressResponse = await requestJson(baseUrl, '/player/me/progress', {
      method: 'GET',
      headers
    });
    assert.equal(progressResponse.status, 200);
    assert.equal((progressResponse.body.user as JsonObject).username, username);
    assert.equal('password_hash' in (progressResponse.body.user as JsonObject), false);

    const progress = progressResponse.body.progress as JsonObject[];
    assert.equal(Array.isArray(progress), true);
    assert.equal(progress.some((row) => row.restriction_type === 'CELIAQUIA'), true);

    const completedNodes = progressResponse.body.completedNodes as JsonObject[];
    assert.equal(
      completedNodes.some((row) => row.node_id === progressPayload.nodeId),
      true
    );

    const sessions = progressResponse.body.recentGames as JsonObject[];
    assert.equal(sessions.some((row) => row.node_id === progressPayload.nodeId), true);

    const storedResult = await pool.query<{
      games_count: string;
      completed_nodes_count: string;
    }>(
      `
        SELECT
          COUNT(DISTINCT g.id)::text AS games_count,
          COUNT(DISTINCT hg.id)::text AS completed_nodes_count
        FROM users u
        LEFT JOIN games g ON g.user_id = u.id AND g.node_id = $2
        LEFT JOIN history_games hg ON hg.user_id = u.id AND hg.node_id = $2 AND hg.completed = true
        WHERE u.username = $1;
      `,
      [username, progressPayload.nodeId]
    );
    assert.equal(storedResult.rows[0].games_count, '1');
    assert.equal(storedResult.rows[0].completed_nodes_count, '1');

    // ── RunSummary full contract tests ────────────────────────────────────────

    // 1. POST accepts correctAnswers, wrongAnswers, durationSeconds, finishedAt
    const fullContractNodeId = `full_contract_node_${suffix}`;
    const finishedAtTimestamp = '2026-06-02T15:00:00.000Z';
    const fullRunSummaryPayload = {
      clientRunId: `client_run_${suffix}`,
      restriction: 'CELIAQUIA',
      expToAdd: 20,
      nodeId: fullContractNodeId,
      gameType: 'completar',
      accuracy: 80,
      completed: true,
      score: 200,
      correctAnswers: 16,
      wrongAnswers: 4,
      durationSeconds: 120,
      finishedAt: finishedAtTimestamp
    };
    const fullRunSummaryResponse = await requestJson(baseUrl, '/player/me/progress', {
      method: 'POST',
      headers,
      body: JSON.stringify(fullRunSummaryPayload)
    });
    assert.equal(fullRunSummaryResponse.status, 201);

    // 2. games stored the new fields
    const storedSessionResult = await pool.query<{
      correct_answers: number | null;
      wrong_answers: number | null;
      duration_seconds: number | null;
      finished_at: Date | null;
    }>(
      `SELECT correct_answers, wrong_answers, duration_seconds, finished_at
       FROM games
       WHERE user_id = (SELECT id FROM users WHERE username = $1) AND node_id = $2
       ORDER BY created_at DESC LIMIT 1;`,
      [username, fullContractNodeId]
    );
    assert.equal(storedSessionResult.rows[0].correct_answers, 16);
    assert.equal(storedSessionResult.rows[0].wrong_answers, 4);
    assert.equal(storedSessionResult.rows[0].duration_seconds, 120);
    assert.ok(storedSessionResult.rows[0].finished_at !== null);

    const beforeDuplicateResult = await pool.query<{
      session_count: string;
      total_exp: number;
      completed_games_count: number;
    }>(
      `
        SELECT
          COUNT(g.id)::text AS session_count,
          pr.total_exp,
          pr.completed_games_count
        FROM progress_restrictions pr
        LEFT JOIN games g
          ON g.progress_id = pr.id AND g.client_run_id = $3
        WHERE pr.user_id = (SELECT id FROM users WHERE username = $1)
          AND pr.restriction = $2
        GROUP BY pr.id, pr.total_exp, pr.completed_games_count;
      `,
      [username, 'CELIAQUIA', fullRunSummaryPayload.clientRunId]
    );

    const duplicateRunSummaryResponse = await requestJson(baseUrl, '/player/me/progress', {
      method: 'POST',
      headers,
      body: JSON.stringify(fullRunSummaryPayload)
    });
    assert.equal(duplicateRunSummaryResponse.status, 201);

    const afterDuplicateResult = await pool.query<{
      session_count: string;
      total_exp: number;
      completed_games_count: number;
    }>(
      `
        SELECT
          COUNT(g.id)::text AS session_count,
          pr.total_exp,
          pr.completed_games_count
        FROM progress_restrictions pr
        LEFT JOIN games g
          ON g.progress_id = pr.id AND g.client_run_id = $3
        WHERE pr.user_id = (SELECT id FROM users WHERE username = $1)
          AND pr.restriction = $2
        GROUP BY pr.id, pr.total_exp, pr.completed_games_count;
      `,
      [username, 'CELIAQUIA', fullRunSummaryPayload.clientRunId]
    );
    assert.equal(afterDuplicateResult.rows[0].session_count, '1');
    assert.equal(afterDuplicateResult.rows[0].total_exp, beforeDuplicateResult.rows[0].total_exp);
    assert.equal(
      afterDuplicateResult.rows[0].completed_games_count,
      beforeDuplicateResult.rows[0].completed_games_count
    );
    assert.equal(
      (duplicateRunSummaryResponse.body.game as JsonObject).clientRunId,
      fullRunSummaryPayload.clientRunId
    );

    // 3. GET /player/me/progress returns new fields in recentGames
    const progressWithNewFieldsResponse = await requestJson(baseUrl, '/player/me/progress', {
      method: 'GET',
      headers
    });
    const recentSessionsWithNewFields = progressWithNewFieldsResponse.body.recentGames as JsonObject[];
    const storedSessionInResponse = recentSessionsWithNewFields.find(
      (s) => s.node_id === fullContractNodeId
    );
    assert.ok(storedSessionInResponse, 'session with fullContractNodeId not found in recentGames');
    assert.equal(storedSessionInResponse.correct_answers, 16);
    assert.equal(storedSessionInResponse.wrong_answers, 4);
    assert.equal(storedSessionInResponse.duration_seconds, 120);
    assert.ok(storedSessionInResponse.finished_at !== null);

    // 4. completed_games_count increments when completed=true
    const progressAfterCompleted = progressWithNewFieldsResponse.body.progress as JsonObject[];
    const celiaquiaAfterCompleted = progressAfterCompleted.find(
      (p) => p.restriction_type === 'CELIAQUIA'
    ) as JsonObject;
    const completedGamesCountAfterFullRun = Number(celiaquiaAfterCompleted.completed_games_count);
    assert.ok(
      completedGamesCountAfterFullRun >= 2,
      `expected >= 2 completed_games_count, got ${completedGamesCountAfterFullRun}`
    );

    // 5. completed_games_count does NOT increment when completed=false
    const incompletePayload = {
      restriction: 'CELIAQUIA',
      expToAdd: 5,
      nodeId: `incomplete_node_${suffix}`,
      gameType: 'quiz',
      accuracy: 30,
      completed: false,
      score: 40
    };
    const incompleteResponse = await requestJson(baseUrl, '/player/me/progress', {
      method: 'POST',
      headers,
      body: JSON.stringify(incompletePayload)
    });
    assert.equal(incompleteResponse.status, 201);
    const progressAfterIncompleteResponse = await requestJson(baseUrl, '/player/me/progress', {
      method: 'GET',
      headers
    });
    const celiaquiaAfterIncomplete = (
      progressAfterIncompleteResponse.body.progress as JsonObject[]
    ).find((p) => p.restriction_type === 'CELIAQUIA') as JsonObject;
    assert.equal(
      Number(celiaquiaAfterIncomplete.completed_games_count),
      completedGamesCountAfterFullRun,
      'completed_games_count should not increment for completed=false'
    );

    // 6. completedNode is set on first completion
    assert.ok(
      fullRunSummaryResponse.body.completedNode !== null,
      'completedNode should be non-null on first completion'
    );

    // 7+8. Replay with better score updates best_score; worse score does not drop it
    const replayNodeId = `replay_node_${suffix}`;
    const firstReplayResponse = await requestJson(baseUrl, '/player/me/progress', {
      method: 'POST',
      headers,
      body: JSON.stringify({
        restriction: 'CELIAQUIA',
        expToAdd: 10,
        nodeId: replayNodeId,
        gameType: 'quiz',
        score: 100,
        accuracy: 70,
        completed: true
      })
    });
    assert.equal(firstReplayResponse.status, 201);
    assert.ok(
      firstReplayResponse.body.completedNode !== null,
      'first completion: completedNode should be non-null'
    );

    const betterScoreResponse = await requestJson(baseUrl, '/player/me/progress', {
      method: 'POST',
      headers,
      body: JSON.stringify({
        restriction: 'CELIAQUIA',
        expToAdd: 10,
        nodeId: replayNodeId,
        gameType: 'quiz',
        score: 150,
        accuracy: 85,
        completed: true
      })
    });
    assert.equal(betterScoreResponse.status, 201);
    assert.equal(
      betterScoreResponse.body.completedNode,
      null,
      'replay: completedNode should be null (not a new completion)'
    );
    const bestScoreAfterBetter = await pool.query<{ best_score: number }>(
      `SELECT best_score FROM history_games
       WHERE user_id = (SELECT id FROM users WHERE username = $1) AND node_id = $2;`,
      [username, replayNodeId]
    );
    assert.equal(bestScoreAfterBetter.rows[0].best_score, 150, 'best_score should update to 150');

    const worseScoreResponse = await requestJson(baseUrl, '/player/me/progress', {
      method: 'POST',
      headers,
      body: JSON.stringify({
        restriction: 'CELIAQUIA',
        expToAdd: 5,
        nodeId: replayNodeId,
        gameType: 'quiz',
        score: 50,
        accuracy: 40,
        completed: true
      })
    });
    assert.equal(worseScoreResponse.status, 201);
    const bestScoreAfterWorse = await pool.query<{ best_score: number }>(
      `SELECT best_score FROM history_games
       WHERE user_id = (SELECT id FROM users WHERE username = $1) AND node_id = $2;`,
      [username, replayNodeId]
    );
    assert.equal(
      bestScoreAfterWorse.rows[0].best_score,
      150,
      'best_score should not drop after worse replay'
    );

    // 9. Replay with better accuracy updates best_accuracy
    const accuracyNodeId = `accuracy_node_${suffix}`;
    await requestJson(baseUrl, '/player/me/progress', {
      method: 'POST',
      headers,
      body: JSON.stringify({
        restriction: 'CELIAQUIA',
        expToAdd: 10,
        nodeId: accuracyNodeId,
        gameType: 'quiz',
        score: 80,
        accuracy: 60,
        completed: true
      })
    });
    await requestJson(baseUrl, '/player/me/progress', {
      method: 'POST',
      headers,
      body: JSON.stringify({
        restriction: 'CELIAQUIA',
        expToAdd: 10,
        nodeId: accuracyNodeId,
        gameType: 'quiz',
        score: 80,
        accuracy: 95,
        completed: true
      })
    });
    const bestAccuracyResult = await pool.query<{ best_accuracy: string }>(
      `SELECT best_accuracy FROM history_games
       WHERE user_id = (SELECT id FROM users WHERE username = $1) AND node_id = $2;`,
      [username, accuracyNodeId]
    );
    assert.ok(
      parseFloat(bestAccuracyResult.rows[0].best_accuracy) >= 95,
      `best_accuracy should be >= 95, got ${bestAccuracyResult.rows[0].best_accuracy}`
    );

    // 9b. Replay worse accuracy keeps best but updates last_accuracy
    const replayAccuracyNodeId = `replay_accuracy_node_${suffix}`;
    await requestJson(baseUrl, '/player/me/progress', {
      method: 'POST',
      headers,
      body: JSON.stringify({
        restriction: 'CELIAQUIA',
        expToAdd: 10,
        nodeId: replayAccuracyNodeId,
        gameType: 'quiz',
        score: 80,
        accuracy: 100,
        completed: true
      })
    });
    await requestJson(baseUrl, '/player/me/progress', {
      method: 'POST',
      headers,
      body: JSON.stringify({
        restriction: 'CELIAQUIA',
        expToAdd: 5,
        nodeId: replayAccuracyNodeId,
        gameType: 'quiz',
        score: 20,
        accuracy: 26,
        completed: true
      })
    });
    const replayAccuracyResult = await pool.query<{
      best_accuracy: string;
      last_accuracy: string;
    }>(
      `SELECT best_accuracy, last_accuracy FROM history_games
       WHERE user_id = (SELECT id FROM users WHERE username = $1) AND node_id = $2;`,
      [username, replayAccuracyNodeId]
    );
    assert.equal(
      parseFloat(replayAccuracyResult.rows[0].best_accuracy),
      100,
      'best_accuracy should remain 100 after worse replay'
    );
    assert.equal(
      parseFloat(replayAccuracyResult.rows[0].last_accuracy),
      26,
      'last_accuracy should reflect the latest replay (26)'
    );
    const gamesAfterReplay = await pool.query<{ accuracy: string }>(
      `SELECT accuracy FROM games
       WHERE user_id = (SELECT id FROM users WHERE username = $1) AND node_id = $2
       ORDER BY created_at DESC
       LIMIT 1;`,
      [username, replayAccuracyNodeId]
    );
    assert.equal(
      parseFloat(gamesAfterReplay.rows[0].accuracy),
      26,
      'latest games row should store accuracy=26'
    );
    const progressAfterReplay = await requestJson(baseUrl, '/player/me/progress', {
      method: 'GET',
      headers
    });
    assert.equal(progressAfterReplay.status, 200);
    const replayNode = (progressAfterReplay.body.completedNodes as Array<{
      node_id: string;
      best_accuracy: string;
      last_accuracy: string;
    }>).find((node) => node.node_id === replayAccuracyNodeId);
    assert.ok(replayNode, 'completedNodes should include replay node');
    assert.equal(parseFloat(replayNode!.best_accuracy), 100);
    assert.equal(parseFloat(replayNode!.last_accuracy), 26);

    // 10. correctAnswers negative → 400 VALIDATION_ERROR
    const negativeCorrectAnswers = await requestJson(baseUrl, '/player/me/progress', {
      method: 'POST',
      headers,
      body: JSON.stringify({ restriction: 'CELIAQUIA', expToAdd: 5, correctAnswers: -1 })
    });
    assert.equal(negativeCorrectAnswers.status, 400);
    assert.equal(negativeCorrectAnswers.body.code, 'VALIDATION_ERROR');

    // 11. wrongAnswers negative → 400 VALIDATION_ERROR
    const negativeWrongAnswers = await requestJson(baseUrl, '/player/me/progress', {
      method: 'POST',
      headers,
      body: JSON.stringify({ restriction: 'CELIAQUIA', expToAdd: 5, wrongAnswers: -1 })
    });
    assert.equal(negativeWrongAnswers.status, 400);
    assert.equal(negativeWrongAnswers.body.code, 'VALIDATION_ERROR');

    // 12. durationSeconds negative → 400 VALIDATION_ERROR
    const negativeDuration = await requestJson(baseUrl, '/player/me/progress', {
      method: 'POST',
      headers,
      body: JSON.stringify({ restriction: 'CELIAQUIA', expToAdd: 5, durationSeconds: -1 })
    });
    assert.equal(negativeDuration.status, 400);
    assert.equal(negativeDuration.body.code, 'VALIDATION_ERROR');

    // 13. Reset Celiaquía borra history_games y deja solo nodos post-reset
    const resetNodeIds = [
      `reset_node_a_${suffix}`,
      `reset_node_b_${suffix}`,
      `reset_node_c_${suffix}`
    ];
    for (const nodeId of resetNodeIds) {
      const resetSeedResponse = await requestJson(baseUrl, '/player/me/progress', {
        method: 'POST',
        headers,
        body: JSON.stringify({
          restriction: 'CELIAQUIA',
          expToAdd: 5,
          nodeId,
          gameType: 'quiz',
          accuracy: 80,
          completed: true,
          score: 80
        })
      });
      assert.equal(resetSeedResponse.status, 201);
    }

    const beforeResetProgress = await requestJson(baseUrl, '/player/me/progress', {
      method: 'GET',
      headers
    });
    assert.equal(beforeResetProgress.status, 200);
    const beforeResetNodes = beforeResetProgress.body.completedNodes as JsonObject[];
    assert.ok(
      resetNodeIds.every((nodeId) => beforeResetNodes.some((row) => row.node_id === nodeId)),
      'completedNodes should include all seeded reset nodes'
    );

    const resetProgressResponse = await requestJson(baseUrl, '/player/me/progress/reset', {
      method: 'POST',
      headers,
      body: JSON.stringify({ restriction: 'CELIAQUIA' })
    });
    assert.equal(resetProgressResponse.status, 200);
    assert.equal((resetProgressResponse.body.completedNodes as JsonObject[]).length, 0);

    const celiaquiaProgressAfterReset = await pool.query<{
      completed_nodes_count: number;
      total_exp: number;
    }>(
      `
        SELECT pr.completed_nodes_count, pr.total_exp
        FROM progress_restrictions pr
        JOIN users u ON u.id = pr.user_id
        WHERE u.username = $1
          AND pr.restriction = 'CELIAQUIA';
      `,
      [username]
    );
    assert.equal(celiaquiaProgressAfterReset.rows[0].completed_nodes_count, 0);
    assert.equal(celiaquiaProgressAfterReset.rows[0].total_exp, 0);

    const completedHistoryAfterReset = await pool.query<{ count: string }>(
      `
        SELECT COUNT(*)::text AS count
        FROM history_games hg
        JOIN progress_restrictions pr ON pr.id = hg.progress_id
        JOIN users u ON u.id = pr.user_id
        WHERE u.username = $1
          AND pr.restriction = 'CELIAQUIA'
          AND hg.node_id IS NOT NULL
          AND hg.completed = true;
      `,
      [username]
    );
    assert.equal(completedHistoryAfterReset.rows[0].count, '0');

    const postResetNodeId = `post_reset_node_${suffix}`;
    const postResetSaveResponse = await requestJson(baseUrl, '/player/me/progress', {
      method: 'POST',
      headers,
      body: JSON.stringify({
        restriction: 'CELIAQUIA',
        expToAdd: 10,
        nodeId: postResetNodeId,
        gameType: 'quiz',
        accuracy: 90,
        completed: true,
        score: 90
      })
    });
    assert.equal(postResetSaveResponse.status, 201);

    const afterOneNodeProgress = await requestJson(baseUrl, '/player/me/progress', {
      method: 'GET',
      headers
    });
    assert.equal(afterOneNodeProgress.status, 200);
    const afterOneNodeCompleted = afterOneNodeProgress.body.completedNodes as JsonObject[];
    assert.equal(afterOneNodeCompleted.length, 1);
    assert.equal(afterOneNodeCompleted[0].node_id, postResetNodeId);

    const patchProfileResponse = await requestJson(baseUrl, '/player/me', {
      method: 'PATCH',
      headers,
      body: JSON.stringify({
        name: 'Player Auth Updated',
        mail: updatedMail,
        birth_date: '1999-01-01'
      })
    });
    assert.equal(patchProfileResponse.status, 200);
    assert.equal((patchProfileResponse.body.user as JsonObject).name, 'Player Auth Updated');
    assert.equal((patchProfileResponse.body.user as JsonObject).mail, updatedMail);
    assert.equal((patchProfileResponse.body.user as JsonObject).birth_date, '1999-01-01');
    assert.equal((patchProfileResponse.body.user as JsonObject).email_notifications_enabled, false);
    assert.ok(patchProfileResponse.body.verification);
    const verification = patchProfileResponse.body.verification as JsonObject;
    assert.equal(verification.mail_changed, true);
    assert.ok(patchProfileResponse.body.profile);
    assert.ok(patchProfileResponse.body.streak);

    const storedUser = await pool.query<{ name: string; mail: string; birth_date: string }>(
      `
        SELECT name, mail, birth_date::text
        FROM users
        WHERE username = $1;
      `,
      [username]
    );
    assert.equal(storedUser.rows[0].name, 'Player Auth Updated');
    assert.equal(storedUser.rows[0].mail, updatedMail);
    assert.equal(storedUser.rows[0].birth_date, '1999-01-01');

    const disableNotificationsResponse = await requestJson(baseUrl, '/player/me', {
      method: 'PATCH',
      headers,
      body: JSON.stringify({ email_notifications_enabled: false })
    });
    assert.equal(disableNotificationsResponse.status, 200);
    assert.equal(
      (disableNotificationsResponse.body.user as JsonObject).email_notifications_enabled,
      false
    );

    const storedNotifications = await pool.query<{ email_notifications_enabled: boolean }>(
      'SELECT email_notifications_enabled FROM users WHERE username = $1;',
      [username]
    );
    assert.equal(storedNotifications.rows[0].email_notifications_enabled, false);

    const otherRegisterResponse = await requestJson(baseUrl, '/auth/register', {
      method: 'POST',
      body: JSON.stringify({
        username: otherUsername,
        name: 'Other Player',
        mail: otherMail,
        password
      })
    });
    assert.equal(otherRegisterResponse.status, 201);

    const duplicateMailResponse = await requestJson(baseUrl, '/player/me', {
      method: 'PATCH',
      headers,
      body: JSON.stringify({ mail: otherMail })
    });
    assert.equal(duplicateMailResponse.status, 409);
    assert.equal(duplicateMailResponse.body.code, 'DUPLICATE_MAIL');

    const emptyPatchResponse = await requestJson(baseUrl, '/player/me', {
      method: 'PATCH',
      headers,
      body: JSON.stringify({})
    });
    assert.equal(emptyPatchResponse.status, 400);
    assert.equal(emptyPatchResponse.body.code, 'INVALID_BODY');

    console.log('player authenticated integration test passed');
  } finally {
    await pool.query(
      'DELETE FROM users WHERE username = ANY($1::text[]) OR mail = ANY($2::text[]);',
      [[username, otherUsername], [mail, updatedMail, otherMail]]
    );
    await new Promise<void>((resolve, reject) => {
      server.close((error) => (error ? reject(error) : resolve()));
    });
    await pool.end();
  }
}

run().catch(async (error) => {
  console.error(error);
  process.exit(1);
});
