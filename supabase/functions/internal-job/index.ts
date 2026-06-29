import { handleCors, jsonResponse, errorResponse } from '../_shared/cors.ts';
import {
  proxyLeaderboardRefresh,
  runPendingWelcomeJob,
  runRetryFailedEmailJob,
  runStreakEmailJob,
} from '../_shared/jobs/email-jobs.ts';

const ALLOWED_JOBS = new Set([
  'streak-emails',
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

    if (!ALLOWED_JOBS.has(job)) {
      return errorResponse(400, `Unknown job: ${job || '(empty)'}`);
    }

    console.log(`[internal-job] start ${job}`);

    if (job === 'streak-emails') {
      const result = await runStreakEmailJob();
      console.log(`[internal-job] done ${job}`, JSON.stringify(result));
      return jsonResponse(result);
    }

    if (job === 'retry-failed-emails') {
      const result = await runRetryFailedEmailJob();
      console.log(`[internal-job] done ${job}`, JSON.stringify(result));
      return jsonResponse(result);
    }

    if (job === 'outbound-emails') {
      const welcome = await runPendingWelcomeJob();
      const streak = await runStreakEmailJob();
      const retry = await runRetryFailedEmailJob();
      const result = { welcome, streak, retry };
      console.log(`[internal-job] done ${job}`, JSON.stringify(result));
      return jsonResponse(result);
    }

    const result = await proxyLeaderboardRefresh();
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
