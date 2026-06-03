import { Router } from 'express';
import {
  getDevProgresoRestriccionController,
  getProgresoRestriccionController,
  postDevProgresoRestriccionController,
  postProgresoRestriccionController
} from './progreso-restriccion.controller';
import { authenticateToken } from '../../shared/middlewares/authenticate-token';

export const progresoRestriccionRouter = Router();

// Endpoints montados en /player por app.ts
progresoRestriccionRouter.get('/me/progress', authenticateToken, getProgresoRestriccionController);
progresoRestriccionRouter.post('/me/progress', authenticateToken, postProgresoRestriccionController);

// Dev endpoints montados en /dev/progreso-restriccion por app.ts
export const devProgresoRestriccionRouter = Router();
devProgresoRestriccionRouter.post('/', postDevProgresoRestriccionController);
devProgresoRestriccionRouter.get('/:username', getDevProgresoRestriccionController);
