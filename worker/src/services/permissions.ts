import { PERMISSION_WILDCARD, type AuthenticatedUser, type Permission } from '../types/auth';
import { CONTENT_KEYS } from './content-registry';

/**
 * ZERO TRUST — THE AUTHORISATION DECISION
 *
 * Never trust. Always verify.
 *
 * Every protected request is decided here, on the server, from the roles the
 * database says the caller holds. The Flutter client mirrors the permission
 * list only to decide which buttons to draw; it can lie about anything and the
 * answer produced by this file does not change.
 *
 * Two vocabularies are in use, deliberately:
 *
 *   Resource-scoped  `history:create`, `videos:publish`
 *     Fine-grained. A Heritage Editor gets history, leaders and people, and no
 *     access at all to the language dictionary.
 *
 *   Capability       `content.create`, `content.publish`
 *     Broad. An Editorial Team Writer can draft any content type; a Publisher
 *     can publish any content type.
 *
 * `implies` below is the bridge: a capability satisfies the matching
 * resource-scoped permission across every content resource. That lets the
 * community grant an editor broad authority or narrow authority without two
 * separate permission systems, and it is why `content.publish` can be withheld
 * from an editor who is allowed to write but not to publish.
 *
 * Everything not granted is denied. There is no fall-through.
 */

/** Capabilities that satisfy `<any content resource>:<action>`. */
const CAPABILITY_FOR_ACTION: Record<string, string[]> = {
  read: ['content.read', 'content.manage'],
  create: ['content.create', 'content.manage'],
  update: ['content.edit', 'content.manage'],
  delete: ['content.delete', 'content.manage'],
  publish: ['content.publish', 'content.manage'],
  review: ['content.review', 'content.manage'],
  submit: ['content.submit', 'content.manage'],
};

/**
 * Capabilities that stand in for a non-content permission.
 *
 * Note what is absent: nothing here grants `users.*`, `roles.*`,
 * `permissions.*`, `security.*`, `system.*` or `audit.view`. Those are reachable
 * only by holding them explicitly, or by the Super Admin wildcard — which is
 * how the Editorial Team is kept out of administration by construction rather
 * than by a check somebody might forget to write.
 */
const CAPABILITY_ALIASES: Record<string, string[]> = {
  'media:read': ['media.manage', 'media.metadata.edit'],
  'media:update': ['media.manage', 'media.metadata.edit'],
  'media:create': ['media.manage'],
  'media:delete': ['media.manage'],
  'submissions:read': ['submissions.manage', 'content.review'],
  'submissions:review': ['submissions.manage', 'content.review'],
  'sources:read': ['sources.manage', 'sources.read', 'content.manage'],
  'sources:create': ['sources.manage'],
  'sources:update': ['sources.manage'],
  'sources:delete': ['sources.manage'],
  'strings:read': ['pages.edit', 'homepage.edit', 'navigation.edit', 'content.edit', 'content.manage'],
  'strings:update': ['pages.edit', 'homepage.edit', 'content.edit', 'content.manage'],
  'strings:publish': ['content.publish', 'content.manage'],
  'navigation:update': ['navigation.edit', 'content.manage'],
  'hero:update': ['homepage.edit', 'content.manage'],
  'hero:publish': ['content.publish', 'content.manage'],
  'seo:update': ['seo.edit', 'content.edit', 'content.manage'],
  'versions:read': ['content.read', 'content.edit', 'content.manage'],
  'versions:restore': ['content.manage', 'content.edit'],
  'contributors:manage': ['content.manage', 'submissions.manage'],
  'audit:read': ['audit.view'],
  'users:read': ['users.manage'],
  'users:create': ['users.manage'],
  'users:update': ['users.manage'],
  'users:assign_roles': ['roles.manage', 'users.manage'],
  'settings:read': ['settings.manage'],
  'settings:update': ['settings.manage'],
};

/**
 * Every permission that satisfies the requested one.
 *
 * Exported so the API can explain a denial and so the tests — and a reviewer —
 * can see exactly what a given permission accepts.
 */
export function acceptedPermissionsFor(permission: Permission): string[] {
  const accepted = new Set<string>([PERMISSION_WILDCARD, permission]);

  for (const alias of CAPABILITY_ALIASES[permission] ?? []) accepted.add(alias);

  // `<resource>:<action>` also accepts the matching content capability — but
  // ONLY when the resource really is a content type.
  //
  // Without this guard, `content.read` would satisfy `users:read` and
  // `audit:read` purely because they share the word "read", handing every
  // Editorial Team member the user list and the audit trail. The permission
  // vocabulary is not a namespace to pattern-match across; the bridge exists
  // for content resources and nowhere else.
  const separator = permission.indexOf(':');
  if (separator > 0) {
    const resource = permission.slice(0, separator);
    if (CONTENT_KEYS.includes(resource)) {
      const action = permission.slice(separator + 1);
      for (const capability of CAPABILITY_FOR_ACTION[action] ?? []) accepted.add(capability);
    }
  }

  return [...accepted];
}

/** The single authorisation predicate. Deny by default. */
export function can(user: AuthenticatedUser | null, permission: Permission): boolean {
  if (!user) return false;
  if (user.status !== 'active') return false;

  for (const accepted of acceptedPermissionsFor(permission)) {
    if (user.permissions.has(accepted)) return true;
  }
  return false;
}

export function canAny(user: AuthenticatedUser | null, permissions: Permission[]): boolean {
  return permissions.some((permission) => can(user, permission));
}

export function canAll(user: AuthenticatedUser | null, permissions: Permission[]): boolean {
  return permissions.every((permission) => can(user, permission));
}

/**
 * Permissions the Editorial Team may never hold, however its roles are
 * configured. Checked when roles are assigned, so a misconfiguration cannot
 * quietly hand an editor administrative authority.
 */
export const ADMINISTRATIVE_ONLY_PERMISSIONS: string[] = [
  PERMISSION_WILDCARD,
  'system.manage',
  'users.manage',
  'roles.manage',
  'permissions.manage',
  'security.manage',
  'settings.manage',
  'audit.view',
  'content.delete',
];

/** True when a permission belongs to the administrative surface. */
export function isAdministrativePermission(permission: string): boolean {
  return ADMINISTRATIVE_ONLY_PERMISSIONS.includes(permission);
}

/**
 * The workflow transitions each permission allows.
 *
 * Publishing is separated from editing on purpose: an Editorial Team member is
 * not automatically allowed to make their own work live. Approving and
 * publishing are likewise distinct, so the community can require a second pair
 * of eyes on anything that reaches the public archive.
 */
export const STATUS_TRANSITION_PERMISSION: Record<string, string> = {
  draft: 'update',
  pending_review: 'submit',
  approved: 'review',
  rejected: 'review',
  published: 'publish',
  archived: 'publish',
};

/** The permission needed to move a resource into a given status. */
export function permissionForStatus(resourceKey: string, status: string): string {
  const action = STATUS_TRANSITION_PERMISSION[status] ?? 'publish';
  return `${resourceKey}:${action}`;
}
