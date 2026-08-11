import type { RouteDefinition } from '../types/api';
import { CONTENT_RESOURCES, permissionFor } from '../services/content-registry';
import {
  adminChangeStatus,
  adminCreate,
  adminDelete,
  adminList,
  adminShow,
  adminUpdate,
} from '../controllers/content.controller';
import {
  assignRole,
  auditLogs,
  changeOwnPassword,
  createUser,
  dashboard,
  listRoles,
  listUsers,
  resetPassword,
  revokeRole,
  updateUser,
} from '../controllers/admin.controller';
import { adminSettings, updateSettings } from '../controllers/settings.controller';
import { deleteMedia, listMedia, updateMedia, upload } from '../controllers/media.controller';
import { listSubmissions, review, showSubmission } from '../controllers/submission.controller';
import { requireAuth, requirePermission, requireRole } from '../middleware/auth';
import { ROLES } from '../types/auth';

/**
 * Admin API.
 *
 * Every route in this file is behind an explicit permission check. The Flutter
 * admin screens also hide what a user may not do, but that is presentation —
 * the decision that matters is made here, on the server, on every request.
 */

/**
 * CRUD routes generated per content type.
 *
 * Reading uses `<resource>:read`, writing `<resource>:create` / `:update`,
 * removal `:delete`, and moving an entry through the editorial workflow
 * `<resource>:publish`. A Heritage Editor therefore gets full control of
 * history, leaders and people, and no access at all to the language dictionary.
 */
function generatedAdminRoutes(): RouteDefinition[] {
  const routes: RouteDefinition[] = [];

  for (const resource of Object.values(CONTENT_RESOURCES)) {
    const base = `/api/admin/${resource.key}`;

    routes.push(
      {
        method: 'GET',
        path: base,
        handler: adminList(resource),
        middleware: [requirePermission(permissionFor(resource.key, 'read'))],
        description: `List all ${resource.label.toLowerCase()} records in every status`,
      },
      {
        method: 'GET',
        path: `${base}/:identifier`,
        handler: adminShow(resource),
        middleware: [requirePermission(permissionFor(resource.key, 'read'))],
        description: `Read one ${resource.label.toLowerCase()} in any status`,
      },
      {
        method: 'POST',
        path: base,
        handler: adminCreate(resource),
        middleware: [requirePermission(permissionFor(resource.key, 'create'))],
        description: `Create a ${resource.label.toLowerCase()}`,
      },
      {
        method: 'PUT',
        path: `${base}/:id`,
        handler: adminUpdate(resource),
        middleware: [requirePermission(permissionFor(resource.key, 'update'))],
        description: `Update a ${resource.label.toLowerCase()}`,
      },
      {
        method: 'PATCH',
        path: `${base}/:id`,
        handler: adminUpdate(resource),
        middleware: [requirePermission(permissionFor(resource.key, 'update'))],
        description: `Partially update a ${resource.label.toLowerCase()}`,
      },
      {
        method: 'PATCH',
        path: `${base}/:id/status`,
        handler: adminChangeStatus(resource),
        // Only authentication is enforced here. The specific permission depends
        // on the target status — submit, review or publish — and is checked
        // inside the handler once the request body has been read.
        middleware: [requireAuth],
        description: `Move a ${resource.label.toLowerCase()} through the editorial workflow`,
      },
      {
        method: 'DELETE',
        path: `${base}/:id`,
        handler: adminDelete(resource),
        middleware: [requirePermission(permissionFor(resource.key, 'delete'))],
        description: `Delete a ${resource.label.toLowerCase()}`,
      },
    );
  }

  return routes;
}

export const adminRoutes: RouteDefinition[] = [
  // --- Dashboard -----------------------------------------------------------
  {
    method: 'GET',
    path: '/api/admin/dashboard',
    handler: dashboard,
    middleware: [requireAuth],
    description: 'Counts per content type and status, and the moderation queue',
  },

  // --- Settings ------------------------------------------------------------
  {
    method: 'GET',
    path: '/api/admin/settings',
    handler: adminSettings,
    middleware: [requireRole(ROLES.CONTENT_ADMINISTRATOR)],
    description: 'All site settings, grouped',
  },
  {
    method: 'PUT',
    path: '/api/admin/settings',
    handler: updateSettings,
    middleware: [requireRole(ROLES.CONTENT_ADMINISTRATOR)],
    description: 'Update site setting values',
  },

  // --- Media library -------------------------------------------------------
  {
    method: 'GET',
    path: '/api/admin/media',
    handler: listMedia,
    middleware: [requirePermission('media:read')],
    description: 'Browse the R2 media library',
  },
  {
    method: 'POST',
    path: '/api/admin/media',
    handler: upload,
    middleware: [requirePermission('media:create')],
    description: 'Upload a file to R2 and record it in D1',
  },
  {
    method: 'PATCH',
    path: '/api/admin/media/:id',
    handler: updateMedia,
    middleware: [requirePermission('media:update')],
    description: 'Catalogue a media item — title, credit, location, date taken',
  },
  {
    method: 'DELETE',
    path: '/api/admin/media/:id',
    handler: deleteMedia,
    middleware: [requirePermission('media:delete')],
    description: 'Delete a media item from R2 and D1',
  },

  // --- Moderation ----------------------------------------------------------
  {
    method: 'GET',
    path: '/api/admin/submissions',
    handler: listSubmissions,
    middleware: [requirePermission('submissions:read')],
    description: 'The community contribution queue',
  },
  {
    method: 'GET',
    path: '/api/admin/submissions/:id',
    handler: showSubmission,
    middleware: [requirePermission('submissions:read')],
    description: 'One contribution in full',
  },
  {
    method: 'PATCH',
    path: '/api/admin/submissions/:id/review',
    handler: review,
    middleware: [requirePermission('submissions:review')],
    description: 'Approve, reject or archive a contribution',
  },

  // --- Users and roles -----------------------------------------------------
  {
    method: 'GET',
    path: '/api/admin/roles',
    handler: listRoles,
    middleware: [requirePermission('users:read')],
    description: 'Platform roles and the Preservation Team structure',
  },
  {
    method: 'GET',
    path: '/api/admin/users',
    handler: listUsers,
    middleware: [requirePermission('users:read')],
    description: 'List platform users',
  },
  {
    method: 'POST',
    path: '/api/admin/users',
    handler: createUser,
    middleware: [requirePermission('users:create')],
    description: 'Create an account for a team member',
  },
  {
    method: 'PATCH',
    path: '/api/admin/users/:id',
    handler: updateUser,
    middleware: [requirePermission('users:update')],
    description: 'Update a user profile, status or Preservation Team position',
  },
  {
    method: 'POST',
    path: '/api/admin/users/:id/password',
    handler: resetPassword,
    middleware: [requirePermission('users:update')],
    description: 'Reset another user password and end their sessions',
  },
  {
    method: 'POST',
    path: '/api/admin/users/:id/roles',
    handler: assignRole,
    middleware: [requirePermission('users:assign_roles')],
    description: 'Grant a role to a user',
  },
  {
    method: 'DELETE',
    path: '/api/admin/users/:id/roles/:role',
    handler: revokeRole,
    middleware: [requirePermission('users:assign_roles')],
    description: 'Remove a role from a user',
  },

  // --- Own account ---------------------------------------------------------
  {
    method: 'POST',
    path: '/api/admin/account/password',
    handler: changeOwnPassword,
    middleware: [requireAuth],
    description: 'Change your own password',
  },

  // --- Audit ---------------------------------------------------------------
  {
    method: 'GET',
    path: '/api/admin/audit-logs',
    handler: auditLogs,
    middleware: [requirePermission('audit:read')],
    description: 'The audit trail',
  },

  ...generatedAdminRoutes(),
];
