/**
 * Roles recognised by the platform.
 *
 * These names are mirrored by the `roles` table (see the D1 migrations) and by
 * `AppRoles` in the Flutter client. Authorisation is ALWAYS decided here on the
 * server; the client copy exists only to decide which buttons to draw.
 */
export const ROLES = {
  SUPER_ADMIN: 'super_admin',
  CONTENT_ADMINISTRATOR: 'content_administrator',
  HERITAGE_EDITOR: 'heritage_editor',
  LANGUAGE_EDITOR: 'language_editor',
  MEDIA_MANAGER: 'media_manager',
  LEBOKU_MANAGER: 'leboku_manager',
  MODERATOR: 'moderator',
  CONTRIBUTOR: 'contributor',
  PUBLIC_VISITOR: 'public_visitor',
} as const;

export type RoleSlug = (typeof ROLES)[keyof typeof ROLES];

/**
 * Permissions are `<resource>:<action>` strings. `*` is a wildcard reserved
 * for Super Admin. Content resources are listed in `content-registry.ts`.
 */
export type Permission = string;

export const PERMISSION_WILDCARD = '*';

/**
 * Ekoli-Yeden Preservation Team designations.
 *
 * A preservation team position describes what a volunteer *does* within the
 * organisation. It is stored alongside — not instead of — the platform role
 * that grants technical permissions, so that the volunteer structure can
 * evolve without rewriting the authorisation model.
 */
export const PRESERVATION_TEAM_POSITIONS = {
  COORDINATOR: 'coordinator',
  SECRETARY: 'secretary',
  HISTORY_AND_RESEARCH: 'history_and_research',
  LANGUAGE_PRESERVATION: 'language_preservation',
  MEDIA: 'media',
  TECHNOLOGY: 'technology',
  VERIFICATION: 'verification',
  COMMUNITY_OUTREACH: 'community_outreach',
  ARCHIVE: 'archive',
  VOLUNTEER: 'volunteer',
} as const;

export type PreservationTeamPosition =
  (typeof PRESERVATION_TEAM_POSITIONS)[keyof typeof PRESERVATION_TEAM_POSITIONS];

/** The caller, as resolved from a verified session token. */
export interface AuthenticatedUser {
  id: string;
  email: string;
  displayName: string;
  status: string;
  roles: RoleSlug[];
  permissions: Set<Permission>;
}

/** Claims carried inside a signed session token. */
export interface TokenClaims {
  /** Subject — the user id. */
  sub: string;
  email: string;
  /** Token kind, so a refresh token can never be used as an access token. */
  typ: 'access' | 'refresh';
  /** Issued-at / expiry, seconds since epoch. */
  iat: number;
  exp: number;
  /** Opaque session identifier, so a session can be revoked server-side. */
  sid: string;
}
