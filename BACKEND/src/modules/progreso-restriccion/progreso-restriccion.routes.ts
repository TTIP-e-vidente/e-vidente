import { Router } from 'express';
import {
  getDevProgresoRestriccionController,
  getProgresoRestriccionController,
  postBatchProgresoRestriccionController,
  postDevProgresoRestriccionController,
  postProgressResetController,
  postProgresoRestriccionController
} from './progreso-restriccion.controller';
import { authenticateToken } from '../../shared/middlewares/authenticate-token';

export const progresoRestriccionRouter = Router();

// Endpoints montados en /player por app.ts
progresoRestriccionRouter.get('/me/progress', authenticateToken, getProgresoRestriccionController);
progresoRestriccionRouter.post('/me/progress', authenticateToken, postProgresoRestriccionController);
progresoRestriccionRouter.post('/me/progress/reset', authenticateToken, postProgressResetController);
progresoRestriccionRouter.post('/me/progress/batch', authenticateToken, postBatchProgresoRestriccionController);

// Dev endpoints montados en /dev/progreso-restriccion por app.ts
export const devProgresoRestriccionRouter = Router();
devProgresoRestriccionRouter.post('/', postDevProgresoRestriccionController);
devProgresoRestriccionRouter.get('/:username', getDevProgresoRestriccionController);
