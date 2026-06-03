import { Request, Response } from 'express';
import { sendError } from '../../shared/http/send-error';
import { sendResponse } from '../../shared/http/send-response';
import { forgotPassword, login, register, resetPassword } from './auth.service';

export async function registerController(request: Request, response: Response): Promise<void> {
  try {
    const result = await register(request.body);
    sendResponse(response, 201, result);
  } catch (error) {
    sendError(response, error);
  }
}

export async function loginController(request: Request, response: Response): Promise<void> {
  try {
    const result = await login(request.body);
    sendResponse(response, 200, result);
  } catch (error) {
    sendError(response, error);
  }
}

export function meController(request: Request, response: Response): void {
  sendResponse(response, 200, { user: request.user });
}

export function logoutController(_request: Request, response: Response): void {
  sendResponse(response, 200, {
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
    sendResponse(response, 200, result);
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
    sendResponse(response, 200, result);
  } catch (error) {
    sendError(response, error);
  }
}
