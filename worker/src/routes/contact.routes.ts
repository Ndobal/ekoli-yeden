import type { RouteDefinition } from '../types/api';
import { requirePermission } from '../middleware/auth';
import { rateLimit } from '../middleware/rate-limit';
import {
  contactMessageStatus,
  contactTopics,
  listContactMessages,
  submitContactMessage,
  updateContactMessage,
} from '../controllers/contact.controller';

/**
 * WRITING TO THE PRESERVATION TEAM.
 *
 * No `requireAuth` on the public routes, and that is the point. Somebody asking
 * what the archive holds about them, or asking for their photograph to be taken
 * down, must not have to create an account — a record of themselves — before
 * they can ask.
 *
 * The rate limit is generous rather than tight. A contact form that refuses a
 * second message from somebody trying to reach a person about a photograph of
 * their child has failed at the only job it has.
 */
export const contactRoutes: RouteDefinition[] = [
  {
    method: 'GET',
    path: '/api/contact/topics',
    handler: contactTopics,
    description: 'What the form offers, and what each topic means',
  },
  {
    method: 'POST',
    path: '/api/contact',
    handler: submitContactMessage,
    middleware: [rateLimit({ scope: 'contact', limit: 10, windowSeconds: 3600 })],
    description: 'Write to the Preservation Team. No account needed',
  },
  {
    method: 'GET',
    path: '/api/contact/:reference',
    handler: contactMessageStatus,
    description: 'What happened to a message, for whoever holds the reference',
  },

  // --- The inbox ------------------------------------------------------------
  {
    method: 'GET',
    path: '/api/admin/contact',
    handler: listContactMessages,
    middleware: [requirePermission('users:read')],
    description: 'Messages from the public, privacy and takedown requests first',
  },
  {
    method: 'POST',
    path: '/api/admin/contact/:id/status',
    handler: updateContactMessage,
    middleware: [requirePermission('users:read')],
    description: 'Pick one up, answer it, close it, or set it aside',
  },
];
