import cors from 'cors';
import express from 'express';
import { authRouter } from './modules/auth/auth.routes';
import { healthRouter } from './modules/health/health.routes';
import { playerRouter } from './modules/player/player.routes';
import { playerProgressRouter } from './modules/player/player_progress.routes';

export const app = express();

app.use(cors());
app.use(express.json());

app.use('/auth', authRouter);
app.use('/health', healthRouter);
app.use('/player', playerRouter);
app.use('/dev/player-progress', playerProgressRouter);
