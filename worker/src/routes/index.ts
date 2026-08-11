import type { RouteDefinition } from '../types/api';
import { Router } from '../middleware/router';
import { publicRoutes } from './public.routes';
import { authRoutes } from './auth.routes';
import { contributeRoutes } from './contribute.routes';
import { editorialRoutes } from './editorial.routes';
import { adminRoutes } from './admin.routes';

/**
 * The complete route table.
 *
 * Registration order matters: more specific paths go in before the generated
 * catch-alls, so `/api/language/categories` is not swallowed by
 * `/api/language/:identifier`.
 *
 * The three protected surfaces are separate on purpose:
 *
 *   /api/contribute/*  anyone, rate-limited, everything lands pending review
 *   /api/editorial/*   the Editorial Team — the website's content, nothing more
 *   /api/admin/*       administration — users, roles, security, the audit trail
 *
 * An editorial account cannot reach `/api/admin/*`, because those routes
 * require permissions no editorial role is granted.
 */
export function buildRouter(): Router {
  const router = new Router();

  router.registerAll(authRoutes);
  router.registerAll(contributeRoutes);
  router.registerAll(editorialRoutes);
  router.registerAll(adminRoutes);
  router.registerAll(publicRoutes);

  return router;
}

export const allRoutes: RouteDefinition[] = [
  ...authRoutes,
  ...contributeRoutes,
  ...editorialRoutes,
  ...adminRoutes,
  ...publicRoutes,
];
