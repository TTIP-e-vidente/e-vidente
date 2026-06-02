import { Router } from 'express';
import {
  loginController,
  logoutController,
  meController,
  registerController
} from '../controllers/auth.controller';
import { authenticateToken } from '../middlewares/authenticate_token';

export const authRouter = Router();

authRouter.post('/register', registerController);
authRouter.post('/login', loginController);
authRouter.get('/me', authenticateToken, meController);
authRouter.post('/logout', authenticateToken, logoutController);
