import cors from 'cors';
import express from 'express';
import { authRouter } from './routes/auth.routes';
import { healthRouter } from './routes/health.routes';
import { playerRouter } from './routes/player.routes';
import { playerProgressRouter } from './routes/player_progress.routes';

export const app = express();

app.use(cors());
app.use(express.json());

app.use('/auth', authRouter);
app.use('/health', healthRouter);
app.use('/player', playerRouter);
app.use('/dev/player-progress', playerProgressRouter);
