import type { Handler, Middleware } from '../types/api';
import type { Permission, RoleSlug } from '../types/auth';
import { ROLES } from '../types/auth';
import { ForbiddenError, UnauthorizedError } from '../utils/errors';
import { hasAnyPermission, hasPermission } from '../services/auth.service';

/**
 * Authorisation middleware.
 *
 * Note the ordering rule enforced across the whole API: authentication runs
 * once, globally, in `index.ts` so that `context.user` is always populated.
 * These wrappers only decide whether the already-resolved caller may proceed.
 */

/** Requires any signed-in account. */
export const requireAuth: Middleware = (next: Handler): Handler => {
  return async (context) => {
    if (!context.user) throw new UnauthorizedError('Please sign in to continue.');
    const response = await next(context);
    return withNoStore(response);
  };
};

/** Requires a specific permission, e.g. `history:create`. */
export function requirePermission(permission: Permission): Middleware {
  return (next: Handler): Handler => {
    return async (context) => {
      if (!context.user) throw new UnauthorizedError('Please sign in to continue.');
      if (!hasPermission(context.user, permission)) {
        throw new ForbiddenError('You do not have permission to perform this action.');
      }
      return withNoStore(await next(context));
    };
  };
}

/** Requires at least one of several permissions. */
export function requireAnyPermission(permissions: Permission[]): Middleware {
  return (next: Handler): Handler => {
    return async (context) => {
      if (!context.user) throw new UnauthorizedError('Please sign in to continue.');
      if (!hasAnyPermission(context.user, permissions)) {
        throw new ForbiddenError('You do not have permission to perform this action.');
      }
      return withNoStore(await next(context));
    };
  };
}

/** Requires one of the listed roles. Super Admin always passes. */
export function requireRole(...roles: RoleSlug[]): Middleware {
  return (next: Handler): Handler => {
    return async (context) => {
      const user = context.user;
      if (!user) throw new UnauthorizedError('Please sign in to continue.');
      const permitted =
        user.roles.includes(ROLES.SUPER_ADMIN) || roles.some((role) => user.roles.includes(role));
      if (!permitted) {
        throw new ForbiddenError('You do not have permission to perform this action.');
      }
      return withNoStore(await next(context));
    };
  };
}

/**
 * Every authenticated response is marked `no-store`.
 *
 * Without this, a shared cache in front of the API could serve one
 * administrator's draft content to the next visitor.
 */
function withNoStore(response: Response): Response {
  const headers = new Headers(response.headers);
  headers.set('cache-control', 'no-store');
  return new Response(response.body, {
    status: response.status,
    statusText: response.statusText,
    headers,
  });
}
