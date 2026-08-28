import type { RouteDefinition } from '../types/api';
import { requireAuth } from '../middleware/auth';
import { rateLimit } from '../middleware/rate-limit';
import {
  decideContactRequest,
  listContactRequests,
  listConversations,
  markConversationRead,
  openConversation,
  requestContact,
  revokeContactGrant,
  searchPeople,
  sendMessage,
  showConversation,
  unreadCount,
  updateConversation,
} from '../controllers/messaging.controller';

/**
 * MESSAGES.
 *
 * ORDERING MATTERS. `/api/messages/:id` would happily match
 * `/api/messages/people`, `/api/messages/unread` and
 * `/api/messages/contact-requests`, so every static segment is registered
 * ahead of it.
 *
 * Everything requires a session. Reading the archive is open to anybody;
 * writing to a named person is not, and neither is finding out who is
 * findable.
 */
export const messagingRoutes: RouteDefinition[] = [
  // --- Static segments, first ----------------------------------------------
  {
    method: 'GET',
    path: '/api/messages/unread',
    handler: unreadCount,
    middleware: [requireAuth],
    description: 'How many messages are waiting, for the badge',
  },
  {
    method: 'GET',
    path: '/api/messages/people',
    handler: searchPeople,
    middleware: [requireAuth],
    description: 'Members you could write to, by name. Carries no contact details',
  },
  {
    method: 'POST',
    path: '/api/messages/conversations',
    handler: openConversation,
    middleware: [
      requireAuth,
      rateLimit({ scope: 'conversation-open', limit: 60, windowSeconds: 3600 }),
    ],
    description: 'Open the conversation with somebody, or find the existing one',
  },

  // --- Asking for somebody's details ---------------------------------------
  {
    method: 'GET',
    path: '/api/messages/contact-requests',
    handler: listContactRequests,
    middleware: [requireAuth],
    description: 'Requests waiting on me, the ones I have made, and who holds my details',
  },
  {
    method: 'POST',
    path: '/api/messages/contact-requests',
    handler: requestContact,
    middleware: [
      requireAuth,
      // Tight. Asking for somebody's phone number is not something anybody
      // needs to do thirty times in an hour, and an unlimited version of this
      // is a way to pester people.
      rateLimit({ scope: 'contact-request', limit: 10, windowSeconds: 3600 }),
    ],
    description: 'Ask to see somebody’s phone number or email. They decide',
  },
  {
    method: 'POST',
    path: '/api/messages/contact-requests/:id/decide',
    handler: decideContactRequest,
    middleware: [requireAuth],
    description: 'Answer a request for your details — yes, or no',
  },
  {
    method: 'DELETE',
    path: '/api/messages/contact-grants/:viewerId',
    handler: revokeContactGrant,
    middleware: [requireAuth],
    description: 'Take your details back from somebody you shared them with',
  },

  // --- One conversation ----------------------------------------------------
  {
    method: 'POST',
    path: '/api/messages/:id/read',
    handler: markConversationRead,
    middleware: [requireAuth],
    description: 'Mark a conversation read',
  },
  {
    method: 'GET',
    path: '/api/messages/:id',
    handler: showConversation,
    middleware: [requireAuth],
    description: 'One conversation and its messages',
  },
  {
    method: 'POST',
    path: '/api/messages/:id',
    handler: sendMessage,
    middleware: [
      requireAuth,
      rateLimit({ scope: 'message-send', limit: 300, windowSeconds: 3600 }),
    ],
    description: 'Send a message',
  },
  {
    method: 'PATCH',
    path: '/api/messages/:id',
    handler: updateConversation,
    middleware: [requireAuth],
    description: 'Archive, mute or block — on your own side only',
  },

  // --- The list ------------------------------------------------------------
  {
    method: 'GET',
    path: '/api/messages',
    handler: listConversations,
    middleware: [requireAuth],
    description: 'My conversations, newest activity first',
  },
];
