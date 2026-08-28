import type { RouteDefinition } from '../types/api';
import { login, logout, me, refresh, register } from '../controllers/auth.controller';
import {
  checkResetToken,
  forgotPassword,
  resetPassword,
} from '../controllers/password-reset.controller';
import { requireAuth } from '../middleware/auth';
import { rateLimit } from '../middleware/rate-limit';

/**
 * Authentication endpoints.
 *
 * Sign-in and registration are rate-limited: they are the two routes where a
 * script would otherwise be able to guess passwords or create accounts in bulk.
 */
export const authRoutes: RouteDefinition[] = [
  {
    method: 'POST',
    path: '/api/auth/register',
    handler: register,
    // Five an hour per address was too tight for this community. Mobile
    // networks here put many people behind one carrier-grade NAT address, so a
    // family or a village hall registering together would have shared a single
    // allowance and the sixth person would have been turned away as an abuser.
    //
    // Twenty still stops casual scripted signup, and the real protection is
    // Cloudflare's own rate limiting at the edge rather than this counter,
    // which lives in one isolate's memory.
    middleware: [rateLimit({ scope: 'register', limit: 20, windowSeconds: 3600 })],
    description: 'Create a contributor account',
  },
  {
    method: 'POST',
    path: '/api/auth/login',
    handler: login,
    middleware: [rateLimit({ scope: 'login', limit: 10, windowSeconds: 900 })],
    description: 'Sign in and receive an access token',
  },
  {
    method: 'POST',
    path: '/api/auth/refresh',
    handler: refresh,
    middleware: [rateLimit({ scope: 'refresh', limit: 60, windowSeconds: 3600 })],
    description: 'Exchange a refresh token for a new session',
  },
  {
    method: 'POST',
    path: '/api/auth/logout',
    handler: logout,
    description: 'End the current session',
  },
  {
    method: 'GET',
    path: '/api/auth/me',
    handler: me,
    middleware: [requireAuth],
    description: 'The signed-in user, their roles and their permissions',
  },

  // --- Password reset ------------------------------------------------------
  // Rate limited hard: this endpoint sends messages to real people, so it is
  // the one an abuser would use to flood somebody's inbox.
  {
    method: 'POST',
    path: '/api/auth/forgot-password',
    handler: forgotPassword,
    middleware: [rateLimit({ scope: 'forgot-password', limit: 5, windowSeconds: 900 })],
    description: 'Request a password reset link',
  },
  {
    method: 'GET',
    path: '/api/auth/reset-password/:token',
    handler: checkResetToken,
    middleware: [rateLimit({ scope: 'reset-check', limit: 30, windowSeconds: 900 })],
    description: 'Check whether a reset link is still valid',
  },
  {
    method: 'POST',
    path: '/api/auth/reset-password',
    handler: resetPassword,
    middleware: [rateLimit({ scope: 'reset-password', limit: 10, windowSeconds: 900 })],
    description: 'Set a new password using a reset link',
  },
];
