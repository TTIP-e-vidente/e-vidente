import cors from 'cors';
import express from 'express';
import { authRouter } from './modules/auth/auth.routes';
import { internalJobsRouter } from './modules/email/email.jobs.routes';
import { internalEmailRouter } from './modules/email/email.internal.routes';
import { devEmailRouter } from './modules/email/email.routes';
import { publicEmailRouter } from './modules/email/email.public.routes';
import { healthRouter } from './modules/health/health.routes';
import { imageRouter } from './modules/image/image.routes';
import { leaderboardRouter } from './modules/leaderboard/leaderboard.routes';
import { profileRouter } from './modules/profile/profile.routes';
import { devProgresoRestriccionRouter, progresoRestriccionRouter } from './modules/progreso-restriccion/progreso-restriccion.routes';

export const app = express();

app.use(cors());
// Limit aumentado a 5mb para soportar imágenes de avatar en base64.
app.use(express.json({ limit: '5mb' }));

app.use('/auth', authRouter);
app.use('/health', healthRouter);
app.use('/internal/jobs', internalJobsRouter);
app.use('/internal/email', internalEmailRouter);
app.use('/leaderboard', leaderboardRouter);
app.use('/player', imageRouter);
app.use('/player', profileRouter);
app.use('/player', progresoRestriccionRouter);
app.use('/public/email', publicEmailRouter);

if (process.env.NODE_ENV !== 'production') {
  app.use('/dev/player-progress', devProgresoRestriccionRouter);
  app.use('/dev/email', devEmailRouter);
}
