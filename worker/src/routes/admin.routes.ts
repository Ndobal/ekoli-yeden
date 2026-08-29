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
  closeUserAccount,
} from '../controllers/admin.controller';
import { adminSettings, updateSettings } from '../controllers/settings.controller';
import { createResetLink, issueTemporaryPassword } from '../controllers/password-reset.controller';
import {
  listPersonSubmissions,
  promotePersonSubmission,
  reviewPersonSubmission,
} from '../controllers/person-submission.controller';
import {
  listNewsSubmissions,
  promoteNewsSubmission,
  reviewNewsSubmission,
} from '../controllers/news-submission.controller';
import {
  approveContribution,
  listContributions,
  rejectContribution,
  serveContributionFile,
} from '../controllers/contribution-upload.controller';
import { deleteMedia, listMedia, updateMedia, upload } from '../controllers/media.controller';
import {
  changeFestivalStatus,
  createFestival,
  ensureFestivalGallery,
  addFestivalYear,
  festivalGalleryIndex,
} from '../controllers/festival.controller';
import {
  addExistingMediaToGallery,
  listGalleryItems,
  removeGalleryItem,
  updateGalleryItem,
  uploadIntoGallery,
} from '../controllers/gallery.controller';
import { listSubmissions, review, showSubmission } from '../controllers/submission.controller';
import { ensureEventGallery } from '../controllers/event.controller';
import {
  adminCreateWord,
  adminSaveEntryParts,
  adminShowEntry,
  adminUpdateWord,
  dictionaryGaps,
} from '../controllers/language.controller';
import {
  listWordSubmissions,
  promoteWordSubmission,
  rejectWordSubmission,
} from '../controllers/word-submission.controller';
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

  // --- Festival galleries --------------------------------------------------
  // A photograph belongs to a year. These are the routes that make that true:
  // every festival owns one album, photographs go into it, and because a
  // festival album is an ordinary gallery the same pictures also appear in the
  // main Gallery section without being filed twice.
  {
    method: 'GET',
    path: '/api/admin/festival-galleries',
    handler: festivalGalleryIndex,
    middleware: [requirePermission('galleries:read')],
    description: 'Every festival with its photograph album and a count of what is in it',
  },
  {
    method: 'POST',
    path: '/api/admin/festivals/:id/gallery',
    handler: ensureFestivalGallery,
    middleware: [requirePermission('galleries:create')],
    description: "A festival's album, created if it does not exist yet",
  },
  // Adding a year to a festival: Leboku 2025, Leboku 2024. The album is an
  // ordinary gallery carrying `festival_id` and `year`, which is what puts it
  // in the festival's archive and the Gallery's album list at once.
  {
    method: 'POST',
    path: '/api/admin/festivals/:id/years',
    handler: addFestivalYear,
    middleware: [requirePermission('galleries:create')],
    description: 'Add a year to a festival',
  },
  // Registered ahead of the generated festival routes so that creating an
  // edition creates its album, and publishing one publishes its photographs.
  // Both wrap the generated handler rather than replacing it.
  {
    method: 'POST',
    path: '/api/admin/festivals',
    handler: createFestival,
    middleware: [requirePermission('festivals:create')],
    description: 'Create a festival edition, together with its photograph album',
  },
  {
    method: 'PATCH',
    path: '/api/admin/festivals/:id/status',
    handler: changeFestivalStatus,
    middleware: [requireAuth],
    description: 'Move a festival through the editorial workflow, taking its album with it',
  },
  {
    method: 'GET',
    path: '/api/admin/galleries/:id/items',
    handler: listGalleryItems,
    middleware: [requirePermission('galleries:read')],
    description: 'Every photograph in an album, in any status',
  },
  {
    method: 'POST',
    path: '/api/admin/galleries/:id/items',
    handler: uploadIntoGallery,
    middleware: [requirePermission('media:create')],
    description: 'Upload a photograph straight into an album',
  },
  {
    method: 'POST',
    path: '/api/admin/galleries/:id/items/existing',
    handler: addExistingMediaToGallery,
    middleware: [requirePermission('galleries:update')],
    description: 'File a photograph already in the media library into an album',
  },
  {
    method: 'PATCH',
    path: '/api/admin/gallery-items/:id',
    handler: updateGalleryItem,
    middleware: [requirePermission('galleries:update')],
    description: 'Label a photograph — who is in it, where, when, who took it',
  },
  {
    method: 'DELETE',
    path: '/api/admin/gallery-items/:id',
    handler: removeGalleryItem,
    middleware: [requirePermission('galleries:update')],
    description: 'Take a photograph out of an album. The file itself is kept',
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

  // --- The dictionary ------------------------------------------------------
  // Registered ahead of the generated language routes: `/api/admin/language/:id`
  // is the word row, and these are the parts of the entry that are not columns
  // on it — its senses, its variants and its example sentences.
  {
    method: 'GET',
    path: '/api/admin/language/gaps',
    handler: dictionaryGaps,
    middleware: [requirePermission('language:read')],
    description: 'Entries with no meaning, no recording or no example — the work still to do',
  },
  {
    method: 'GET',
    path: '/api/admin/language/:id/entry',
    handler: adminShowEntry,
    middleware: [requirePermission('language:read')],
    description: 'One dictionary entry in full, drafts included',
  },
  {
    method: 'PUT',
    path: '/api/admin/language/:id/entry',
    handler: adminSaveEntryParts,
    middleware: [requirePermission('language:update')],
    description: "Save an entry's senses, variants and example sentences",
  },
  // Ahead of the generated language routes, so that saving a headword rebuilds
  // the searchable form derived from it.
  {
    method: 'POST',
    path: '/api/admin/language',
    handler: adminCreateWord,
    middleware: [requirePermission('language:create')],
    description: 'Add a dictionary entry',
  },
  {
    method: 'PUT',
    path: '/api/admin/language/:id',
    handler: adminUpdateWord,
    middleware: [requirePermission('language:update')],
    description: 'Update a dictionary entry',
  },
  {
    method: 'PATCH',
    path: '/api/admin/language/:id',
    handler: adminUpdateWord,
    middleware: [requirePermission('language:update')],
    description: 'Partially update a dictionary entry',
  },
  {
    method: 'GET',
    path: '/api/admin/word-submissions',
    handler: listWordSubmissions,
    middleware: [requirePermission('language:read')],
    description: 'Dictionary entries proposed by the community, awaiting a language editor',
  },
  {
    method: 'POST',
    path: '/api/admin/word-submissions/:id/promote',
    handler: promoteWordSubmission,
    middleware: [requirePermission('language:create')],
    description: 'Turn a proposed entry into a draft dictionary entry, crediting the contributor',
  },
  {
    method: 'POST',
    path: '/api/admin/word-submissions/:id/reject',
    handler: rejectWordSubmission,
    middleware: [requirePermission('language:update')],
    description: 'Decline a proposed entry. It is kept, not deleted',
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
    description: 'Set another user password directly and end their sessions',
  },
  {
    method: 'POST',
    path: '/api/admin/users/:id/reset-link',
    handler: createResetLink,
    middleware: [requirePermission('users:update')],
    description:
      'Generate a password reset link for a user, sending it where possible and returning it so '
      + 'an administrator can pass it on',
  },
  {
    method: 'POST',
    path: '/api/admin/users/:id/temporary-password',
    handler: issueTemporaryPassword,
    middleware: [requirePermission('users:update')],
    description:
      'Set a temporary password that must be replaced at next sign-in — for somebody who cannot '
      + 'open a reset link',
  },
  {
    method: 'POST',
    path: '/api/admin/users/:id/close',
    handler: closeUserAccount,
    middleware: [requirePermission('users:manage')],
    description: 'Close an account: no sign-in, no sessions, out of the directory',
  },

  {
    method: 'POST',
    path: '/api/admin/events/:id/gallery',
    handler: ensureEventGallery,
    middleware: [requirePermission('events:update')],
    description: "Give an event its own album, so its photographs are filed under the occasion",
  },

  // --- News sent in by the community ----------------------------------------
  {
    method: 'GET',
    path: '/api/admin/news-submissions',
    handler: listNewsSubmissions,
    middleware: [requirePermission('news:update')],
    description: 'News sent in by members, awaiting an administrator',
  },
  {
    method: 'POST',
    path: '/api/admin/news-submissions/:id/promote',
    handler: promoteNewsSubmission,
    middleware: [requirePermission('news:publish')],
    description: 'Publish submitted news, optionally rewriting it first',
  },
  {
    method: 'POST',
    path: '/api/admin/news-submissions/:id/review',
    handler: reviewNewsSubmission,
    middleware: [requirePermission('news:update')],
    description: 'Ask for more, or decline submitted news',
  },

  // --- Profiles submitted for the People section ----------------------------
  {
    method: 'GET',
    path: '/api/admin/person-submissions',
    handler: listPersonSubmissions,
    middleware: [requirePermission('people:update')],
    description: 'Profiles of people sent in by the community, awaiting review',
  },
  {
    method: 'POST',
    path: '/api/admin/person-submissions/:id/promote',
    handler: promotePersonSubmission,
    middleware: [requirePermission('people:update')],
    description: 'Publish a submitted profile. Refuses where consent is unsettled',
  },
  {
    method: 'POST',
    path: '/api/admin/person-submissions/:id/review',
    handler: reviewPersonSubmission,
    middleware: [requirePermission('people:update')],
    description: 'Ask for more, reject, or mark a submitted profile a duplicate',
  },

  // --- Contributed files awaiting review -----------------------------------
  {
    method: 'GET',
    path: '/api/admin/contributions',
    handler: listContributions,
    middleware: [requirePermission('submissions:read')],
    description: 'Files uploaded by the community, awaiting review',
  },
  {
    method: 'GET',
    path: '/api/admin/contributions/:id/file',
    handler: serveContributionFile,
    middleware: [requirePermission('submissions:read')],
    description: 'Stream a contributed file for review — never public',
  },
  {
    method: 'POST',
    path: '/api/admin/contributions/:id/approve',
    handler: approveContribution,
    middleware: [requirePermission('submissions:review')],
    description: 'Approve a contributed file and copy it into the archive',
  },
  {
    method: 'POST',
    path: '/api/admin/contributions/:id/reject',
    handler: rejectContribution,
    middleware: [requirePermission('submissions:review')],
    description: 'Reject a contributed file. The file is retained, not deleted',
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
