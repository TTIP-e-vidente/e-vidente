import { handleCors, jsonResponse, errorResponse } from '../_shared/cors.ts';
import {
  runLeaderboardRefreshJob,
  runPendingWelcomeJob,
  runRetryFailedEmailJob,
  runStreakAtRiskEmailJob,
  runStreakEmailJob,
  runStreakLastChanceEmailJob,
  runStreakLostEmailJob,
} from '../_shared/jobs/email-jobs.ts';

const ALLOWED_JOBS = new Set([
  'streak-emails',
  'streak-at-risk-emails',
  'streak-last-chance-emails',
  'streak-lost-emails',
  'retry-failed-emails',
  'outbound-emails',
  'refresh-leaderboard',
]);

function isAuthorized(req: Request): boolean {
  const expected = Deno.env.get('EMAIL_CRON_SECRET')?.trim();
  if (!expected) {
    return false;
  }
  const provided = req.headers.get('X-Job-Secret')?.trim();
  return provided === expected;
}

Deno.serve(async (req) => {
  const cors = handleCors(req);
  if (cors) {
    return cors;
  }

  if (req.method !== 'POST') {
    return errorResponse(405, 'Method not allowed');
  }

  if (!isAuthorized(req)) {
    return errorResponse(401, 'Unauthorized job secret');
  }

  try {
    const body = (await req.json().catch(() => ({}))) as Record<string, unknown>;
    const job = typeof body.job === 'string' ? body.job.trim() : '';
    const onlyUserId = typeof body.onlyUserId === 'string' ? body.onlyUserId.trim() : undefined;
    const retryBatchLimit = typeof body.retryBatchLimit === 'number' && body.retryBatchLimit > 0
      ? Math.floor(body.retryBatchLimit)
      : undefined;
    const scope = onlyUserId || retryBatchLimit
      ? { onlyUserId, retryBatchLimit }
      : undefined;

    if (!ALLOWED_JOBS.has(job)) {
      return errorResponse(400, `Unknown job: ${job || '(empty)'}`);
    }

    console.log(`[internal-job] start ${job}${onlyUserId ? ` onlyUserId=${onlyUserId}` : ''}`);

    if (job === 'streak-emails') {
      const result = await runStreakEmailJob(undefined, scope);
      console.log(`[internal-job] done ${job}`, JSON.stringify(result));
      return jsonResponse(result);
    }

    if (job === 'streak-at-risk-emails') {
      const result = await runStreakAtRiskEmailJob(undefined, scope);
      console.log(`[internal-job] done ${job}`, JSON.stringify(result));
      return jsonResponse(result);
    }

    if (job === 'streak-last-chance-emails') {
      const result = await runStreakLastChanceEmailJob(undefined, scope);
      console.log(`[internal-job] done ${job}`, JSON.stringify(result));
      return jsonResponse(result);
    }

    if (job === 'streak-lost-emails') {
      const result = await runStreakLostEmailJob(undefined, scope);
      console.log(`[internal-job] done ${job}`, JSON.stringify(result));
      return jsonResponse(result);
    }

    if (job === 'retry-failed-emails') {
      const result = await runRetryFailedEmailJob(scope);
      console.log(`[internal-job] done ${job}`, JSON.stringify(result));
      return jsonResponse(result);
    }

    if (job === 'outbound-emails') {
      const welcome = await runPendingWelcomeJob();
      const atRisk = await runStreakAtRiskEmailJob(undefined, scope);
      const lastChance = await runStreakLastChanceEmailJob(undefined, scope);
      const lost = await runStreakLostEmailJob(undefined, scope);
      const retry = await runRetryFailedEmailJob(scope);
      const result = { welcome, atRisk, lastChance, lost, retry };
      console.log(`[internal-job] done ${job}`, JSON.stringify(result));
      return jsonResponse(result);
    }

    const result = await runLeaderboardRefreshJob();
    console.log(`[internal-job] done ${job}`, JSON.stringify(result));
    return jsonResponse(result);
  } catch (error) {
    console.error('[internal-job]', error);
    return errorResponse(
      500,
      error instanceof Error ? error.message : 'Internal server error',
    );
  }
});
