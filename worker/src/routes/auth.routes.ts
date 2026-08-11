import type { RouteDefinition } from '../types/api';
import { login, logout, me, refresh, register } from '../controllers/auth.controller';
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
    middleware: [rateLimit({ scope: 'register', limit: 5, windowSeconds: 3600 })],
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
];
