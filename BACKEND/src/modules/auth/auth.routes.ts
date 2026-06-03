import { Router } from 'express';
import {
  forgotPasswordController,
  loginController,
  logoutController,
  meController,
  registerController,
  resetPasswordController
} from './auth.controller';
import { authenticateToken } from '../../shared/middlewares/authenticate-token';

export const authRouter = Router();

authRouter.post('/register', registerController);
authRouter.post('/login', loginController);
authRouter.post('/forgot-password', forgotPasswordController);
authRouter.post('/reset-password', resetPasswordController);
authRouter.get('/me', authenticateToken, meController);
authRouter.post('/logout', authenticateToken, logoutController);
