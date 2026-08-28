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
 * Requires an Okoli membership, not merely an account.
 *
 * WHY CONTRIBUTING NEEDS THIS.
 *
 * Contributing used to be open to anybody, on the reasoning that an elder's
 * grandchild with a photograph on their phone should not have to register. It
 * is a fair instinct and it did not survive contact with what the archive
 * actually needs from a contribution.
 *
 * A photograph is only worth what is known about it. When the Preservation
 * Team cannot tell who is pictured, or where, or when, the only way to find out
 * is to ask the person who sent it — and an anonymous upload has nobody to ask.
 * The community also has to be able to weigh a claim about its own past against
 * who is making it, which a form fill cannot support.
 *
 * A membership costs a name and an email. It is not a paywall; it is the
 * difference between a photograph the archive can follow up on and one it
 * cannot.
 *
 * WHAT IT DOES NOT GATE. Reading. Every page of this archive stays open to
 * anybody, signed in or not — the point is to be read.
 */
export const requireMembership: Middleware = (next: Handler): Handler => {
  return async (context) => {
    if (!context.user) {
      throw new UnauthorizedError(
        'Please sign in to contribute. Contributions are tied to a member so the Preservation '
          + 'Team can ask you about what you have sent.',
      );
    }

    // An administrator or an editor is acting for the archive itself and does
    // not need a membership record to do their own job.
    if (hasPermission(context.user, 'submissions:review')) {
      return withNoStore(await next(context));
    }

    const row = await context.env.DB.prepare(
      'SELECT "membership_status" FROM "member_profiles" WHERE "user_id" = ? LIMIT 1',
    )
      .bind(context.user.id)
      .first<{ membership_status: string }>();

    if (!row) {
      throw new ForbiddenError(
        'Please complete your membership before contributing. It takes a moment, and it is what '
          + 'lets us credit your contribution and come back to you about it.',
      );
    }
    if (row.membership_status !== 'active') {
      throw new ForbiddenError('Your membership is not active, so contributions are paused.');
    }

    return withNoStore(await next(context));
  };
};

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
