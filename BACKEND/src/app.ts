import cors from 'cors';
import express from 'express';
import { authRouter } from './modules/auth/auth.routes';
import { healthRouter } from './modules/health/health.routes';
import { profileRouter } from './modules/profile/profile.routes';
import { devProgresoRestriccionRouter, progresoRestriccionRouter } from './modules/progreso-restriccion/progreso-restriccion.routes';

export const app = express();

app.use(cors());
app.use(express.json());

app.use('/auth', authRouter);
app.use('/health', healthRouter);
app.use('/player', profileRouter);
app.use('/player', progresoRestriccionRouter);
app.use('/dev/player-progress', devProgresoRestriccionRouter);
