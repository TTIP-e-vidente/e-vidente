import { Request, Response } from 'express';
import { sendError } from '../../shared/http/send_error';
import { forgotPassword, login, register, resetPassword } from './auth.service';

export async function registerController(request: Request, response: Response): Promise<void> {
  try {
    const result = await register(request.body);
    response.status(201).json(result);
  } catch (error) {
    sendError(response, error);
  }
}

export async function loginController(request: Request, response: Response): Promise<void> {
  try {
    const result = await login(request.body);
    response.status(200).json(result);
  } catch (error) {
    sendError(response, error);
  }
}

export function meController(request: Request, response: Response): void {
  response.status(200).json({ user: request.user });
}

export function logoutController(_request: Request, response: Response): void {
  response.status(200).json({
    status: 'ok',
    message: 'Logout handled client-side'
  });
}

export async function forgotPasswordController(
  request: Request,
  response: Response
): Promise<void> {
  try {
    const result = await forgotPassword(request.body ?? {});
    response.status(200).json(result);
  } catch (error) {
    sendError(response, error);
  }
}

export async function resetPasswordController(
  request: Request,
  response: Response
): Promise<void> {
  try {
    const result = await resetPassword(request.body ?? {});
    response.status(200).json(result);
  } catch (error) {
    sendError(response, error);
  }
}
