import { UserRepository } from '../repositories/user.repository';
import type { Env } from '../types/env';
import type {
  AuthenticatedUser,
  Permission,
  RoleSlug,
  TokenClaims,
} from '../types/auth';
import { can, canAny } from './permissions';
import { ForbiddenError, UnauthorizedError } from '../utils/errors';
import {
  hashPassword,
  requireSecret,
  sha256,
  signJwt,
  timingSafeEqual,
  verifyJwt,
  verifyPassword,
} from '../utils/crypto';
import { newId } from '../utils/id';

export interface IssuedTokens {
  accessToken: string;
  refreshToken: string;
  expiresIn: number;
  sessionId: string;
}

/**
 * Authentication and authorisation.
 *
 * Two rules hold everywhere in this file:
 *  1. Authorisation decisions are made here, on the server. The Flutter client
 *     mirrors the role list only to decide what to draw.
 *  2. Failure messages never distinguish "no such account" from "wrong
 *     password", so the archive cannot be used to enumerate community members.
 */
export class AuthService {
  private readonly users: UserRepository;

  constructor(private readonly env: Env) {
    this.users = new UserRepository(env.DB);
  }

  private get secret(): string {
    return requireSecret(this.env.JWT_SECRET, 'JWT_SECRET');
  }

  private get accessTtl(): number {
    return Number(this.env.ACCESS_TOKEN_TTL_SECONDS) || 3600;
  }

  private get refreshTtl(): number {
    return Number(this.env.REFRESH_TOKEN_TTL_SECONDS) || 2_592_000;
  }

  async register(values: {
    email: string;
    password: string;
    displayName: string;
  }): Promise<string> {
    const existing = await this.users.findByEmail(values.email);
    if (existing) {
      // Deliberately vague: confirming the address exists would leak membership.
      throw new UnauthorizedError('That account could not be created. Please try a different email address.');
    }
    const { hash, salt } = await hashPassword(values.password);
    const userId = await this.users.create({
      email: values.email,
      display_name: values.displayName,
      password_hash: hash,
      password_salt: salt,
      status: 'active',
    });

    // No role is assigned here, and no `contributor` role exists to assign any
    // more. Registering IS joining: the caller follows this with
    // `MembershipService.ensureMembership`, which creates the profile and
    // grants `okoli_member` — the role that actually carries the permission to
    // contribute.
    //
    // Kept out of this method because creating a membership needs a handle, a
    // membership number and an audit entry, and none of that belongs to
    // authentication.
    return userId;
  }

  async authenticate(email: string, password: string): Promise<AuthenticatedUser> {
    const record = await this.users.findByEmail(email);
    if (!record || !record.password_hash || !record.password_salt) {
      // Spend roughly the same time as a real verification so that response
      // timing does not reveal whether the address is registered.
      await hashPassword(password);
      throw new UnauthorizedError('The email address or password is incorrect.');
    }
    if (record.status !== 'active') {
      throw new ForbiddenError('This account is not active. Please contact an administrator.');
    }

    const ok = await verifyPassword(password, record.password_hash, record.password_salt);
    if (!ok) throw new UnauthorizedError('The email address or password is incorrect.');

    await this.users.recordLogin(record.id);
    return this.buildAuthenticatedUser(record.id, record.email, record.display_name, record.status);
  }

  async issueTokens(
    userId: string,
    email: string,
    context: { userAgent: string | null; ipHash: string | null },
  ): Promise<IssuedTokens> {
    const sessionId = newId();
    const issuedAt = Math.floor(Date.now() / 1000);

    const accessToken = await signJwt(
      { sub: userId, email, typ: 'access', iat: issuedAt, exp: issuedAt + this.accessTtl, sid: sessionId } satisfies TokenClaims,
      this.secret,
    );

    const refreshToken = await signJwt(
      { sub: userId, email, typ: 'refresh', iat: issuedAt, exp: issuedAt + this.refreshTtl, sid: sessionId } satisfies TokenClaims,
      this.secret,
    );

    // Only a digest of the refresh token is stored, so a leaked database
    // snapshot cannot be replayed as a session.
    await this.users.createSession({
      id: sessionId,
      userId,
      refreshTokenHash: await sha256(refreshToken),
      userAgent: context.userAgent,
      ipHash: context.ipHash,
      expiresAt: new Date((issuedAt + this.refreshTtl) * 1000).toISOString(),
    });

    return { accessToken, refreshToken, expiresIn: this.accessTtl, sessionId };
  }

  /** Resolves a bearer token to a user, or `null` for anonymous traffic. */
  async resolveUser(authorizationHeader: string | null): Promise<AuthenticatedUser | null> {
    if (!authorizationHeader?.toLowerCase().startsWith('bearer ')) return null;
    const token = authorizationHeader.slice(7).trim();
    if (token === '') return null;

    const claims = await verifyJwt<TokenClaims>(token, this.secret);
    if (!claims || claims.typ !== 'access') return null;

    // A revoked session must stop working immediately, even though the token
    // itself has not expired.
    const session = await this.users.findSession(claims.sid);
    if (!session || session.revoked_at !== null) return null;
    if (Date.parse(session.expires_at) <= Date.now()) return null;

    const record = await this.users.findById(claims.sub);
    if (!record || record.status !== 'active') return null;

    return this.buildAuthenticatedUser(record.id, record.email, record.display_name, record.status);
  }

  async refresh(refreshToken: string): Promise<{ user: AuthenticatedUser; tokens: IssuedTokens } | null> {
    const claims = await verifyJwt<TokenClaims>(refreshToken, this.secret);
    if (!claims || claims.typ !== 'refresh') return null;

    const session = await this.users.findSession(claims.sid);
    if (!session || session.revoked_at !== null) return null;
    if (Date.parse(session.expires_at) <= Date.now()) return null;

    // The presented token must be the exact one this session was issued for —
    // a valid signature alone is not enough once a session has been rotated.
    if (!timingSafeEqual(await sha256(refreshToken), session.refresh_token_hash)) return null;

    const record = await this.users.findById(claims.sub);
    if (!record || record.status !== 'active') return null;

    // Rotate: the old session is retired and a new one issued, so a stolen
    // refresh token is usable at most once.
    await this.users.revokeSession(claims.sid);
    const tokens = await this.issueTokens(record.id, record.email, {
      userAgent: session.user_agent,
      ipHash: session.ip_hash,
    });
    const user = await this.buildAuthenticatedUser(record.id, record.email, record.display_name, record.status);
    return { user, tokens };
  }

  async logout(sessionId: string): Promise<void> {
    await this.users.revokeSession(sessionId);
  }

  async sessionIdFromToken(token: string): Promise<string | null> {
    const claims = await verifyJwt<TokenClaims>(token, this.secret);
    return claims?.sid ?? null;
  }

  private async buildAuthenticatedUser(
    id: string,
    email: string,
    displayName: string,
    status: string,
  ): Promise<AuthenticatedUser> {
    const roles = await this.users.rolesForUser(id);
    const permissions = new Set<Permission>();

    for (const role of roles) {
      let parsed: unknown;
      try {
        parsed = JSON.parse(role.permissions);
      } catch {
        parsed = [];
      }
      if (Array.isArray(parsed)) {
        for (const permission of parsed) {
          if (typeof permission === 'string') permissions.add(permission);
        }
      }
    }

    return {
      id,
      email,
      displayName,
      status,
      roles: roles.map((role) => role.slug as RoleSlug),
      permissions,
    };
  }
}

/**
 * The authorisation predicates used by the middleware.
 *
 * The decision itself lives in `services/permissions.ts`, which understands
 * both the resource-scoped vocabulary (`history:create`) and the Editorial Team
 * capability vocabulary (`content.create`). These re-exports keep every call
 * site pointed at one implementation.
 */
export function hasPermission(user: AuthenticatedUser | null, permission: Permission): boolean {
  return can(user, permission);
}

export function hasAnyPermission(user: AuthenticatedUser | null, permissions: Permission[]): boolean {
  return canAny(user, permissions);
}

export function hasRole(user: AuthenticatedUser | null, role: RoleSlug): boolean {
  return user?.roles.includes(role) ?? false;
}
