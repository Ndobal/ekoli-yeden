import type { RouteDefinition } from '../types/api';
import { requireAuth } from '../middleware/auth';
import { rateLimit } from '../middleware/rate-limit';
import {
  createTopic,
  editPost,
  follow,
  listReports,
  listSpaces,
  moderate,
  moderationLog,
  react,
  reply,
  report,
  sanction,
  settleReport,
  showSpace,
  showTopic,
} from '../controllers/forum.controller';

/**
 * THE YAKOLI FORUMS (Module 5)
 *
 * ORDERING MATTERS MORE HERE THAN ALMOST ANYWHERE ELSE IN THIS ROUTER.
 *
 * `/api/forums/:space` would happily match `/api/forums/admin`, `/api/forums/
 * topics` and `/api/forums/post` — so every static segment is registered ahead
 * of it. A moderation endpoint shadowed by a space whose slug happened to be
 * "admin" would be a genuinely dangerous accident.
 *
 * READING IS NOT UNIFORMLY OPEN. `requireAuth` is absent from the read routes
 * because the general space is public and a visitor should be able to read it —
 * but `ForumService.access` still decides, per space, and answers "not found"
 * for a members-only space rather than "forbidden", so its contents are not
 * probeable by an anonymous caller.
 */
export const forumRoutes: RouteDefinition[] = [
  // --- Moderation: static, and first ---------------------------------------
  {
    method: 'GET',
    path: '/api/forums/admin/reports',
    handler: listReports,
    middleware: [requireAuth],
    description: 'Reported posts and topics, child-safety first',
  },
  {
    method: 'POST',
    path: '/api/forums/admin/reports/:id/settle',
    handler: settleReport,
    middleware: [requireAuth],
    description: 'Action or dismiss a report',
  },
  {
    method: 'POST',
    path: '/api/forums/admin/moderate',
    handler: moderate,
    middleware: [requireAuth],
    description: 'Hide, remove, restore, lock or pin. Every action is recorded permanently',
  },
  {
    method: 'POST',
    path: '/api/forums/admin/sanctions',
    handler: sanction,
    middleware: [requireAuth],
    description: 'Warn, suspend or ban a member from the forums',
  },
  {
    method: 'GET',
    path: '/api/forums/admin/actions',
    handler: moderationLog,
    middleware: [requireAuth],
    description: 'The moderation log — append-only, and readable by every moderator',
  },

  // --- Acting on one thing, by id ------------------------------------------
  {
    method: 'PATCH',
    path: '/api/forums/posts/:id',
    handler: editPost,
    middleware: [requireAuth],
    description: 'Edit your own reply. The edit is stamped rather than silent',
  },
  {
    method: 'POST',
    path: '/api/forums/topics/:id/follow',
    handler: follow,
    middleware: [requireAuth],
    description: 'Be told when somebody replies to this conversation',
  },

  // `:targetType` is constrained to topic|post inside the handler.
  {
    method: 'POST',
    path: '/api/forums/:targetType/:id/react',
    handler: react,
    middleware: [
      requireAuth,
      rateLimit({ scope: 'forum-react', limit: 200, windowSeconds: 3600 }),
    ],
    description: 'Add or remove a reaction. Counts are shown and order nothing',
  },
  {
    method: 'POST',
    path: '/api/forums/:targetType/:id/report',
    handler: report,
    middleware: [
      requireAuth,
      // Generous on purpose. Somebody being harassed should never meet a rate
      // limit while trying to report it.
      rateLimit({ scope: 'forum-report', limit: 60, windowSeconds: 3600 }),
    ],
    description: 'Report a topic or reply. Child-safety reports hide it immediately',
  },

  // --- Spaces --------------------------------------------------------------
  {
    method: 'GET',
    path: '/api/forums',
    handler: listSpaces,
    description: 'The three spaces, and whether you may enter each',
  },
  {
    method: 'POST',
    path: '/api/forums/:space/topics',
    handler: createTopic,
    middleware: [
      requireAuth,
      rateLimit({ scope: 'forum-topic', limit: 20, windowSeconds: 3600 }),
    ],
    description: 'Start a conversation',
  },
  {
    method: 'POST',
    path: '/api/forums/:space/topics/:topic/replies',
    handler: reply,
    middleware: [
      requireAuth,
      rateLimit({ scope: 'forum-reply', limit: 100, windowSeconds: 3600 }),
    ],
    description: 'Reply to a conversation',
  },
  {
    method: 'GET',
    path: '/api/forums/:space/topics/:topic',
    handler: showTopic,
    description: 'One conversation with its replies',
  },
  {
    method: 'GET',
    path: '/api/forums/:space',
    handler: showSpace,
    description: 'One space with its categories and conversations',
  },
];
