import type { RouteDefinition } from '../types/api';
import { checkStatus, contributionTypes, submit } from '../controllers/submission.controller';
import { contributeUpload } from '../controllers/media.controller';
import {
  uploadConfig,
  uploadContribution,
} from '../controllers/contribution-upload.controller';
import {
  submitWord,
  wordFormOptions,
  wordSubmissionStatus,
} from '../controllers/word-submission.controller';
import { rateLimit } from '../middleware/rate-limit';
import { requireMembership } from '../middleware/auth';
import {
  personFormOptions,
  personSubmissionStatus,
  submitPerson,
} from '../controllers/person-submission.controller';
import {
  newsFormOptions,
  newsSubmissionStatus,
  submitNews,
} from '../controllers/news-submission.controller';

/**
 * CONTRIBUTE TO EKOLI YEDEN
 *
 * Contributing requires an Okoli membership. Reading does not, and never will —
 * every page of the archive stays open to anybody.
 *
 * The reasoning is at `requireMembership` in `middleware/auth.ts`, and it comes
 * down to this: a photograph is worth what is known about it, and an anonymous
 * upload leaves nobody to ask. Everything still lands in `pending_review`.
 *
 * The GET routes stay open. Somebody deciding whether to join should be able to
 * see what contributing involves before they do.
 */
export const contributeRoutes: RouteDefinition[] = [
  {
    method: 'GET',
    path: '/api/contribute/types',
    handler: contributionTypes,
    description: 'What may be contributed, and what happens next',
  },
  {
    method: 'POST',
    path: '/api/contribute',
    handler: submit,
    middleware: [
      requireMembership,
      rateLimit({ scope: 'contribute', limit: 10, windowSeconds: 3600 }),
    ],
    description: 'Submit material to the archive for review',
  },
  {
    method: 'POST',
    path: '/api/contribute/media',
    handler: contributeUpload,
    middleware: [
      requireMembership,
      rateLimit({ scope: 'contribute-media', limit: 20, windowSeconds: 3600 }),
    ],
    description: 'Attach a photograph, document or recording to a contribution',
  },

  // --- File uploads into the dedicated submissions bucket ------------------
  // Kept apart from the published archive until somebody has reviewed it.
  {
    method: 'GET',
    path: '/api/contribute/upload-config',
    handler: uploadConfig,
    description: 'What may be uploaded, the size limits, and the usage permissions offered',
  },
  {
    method: 'POST',
    path: '/api/contribute/upload',
    handler: uploadContribution,
    middleware: [
      requireMembership,
      rateLimit({ scope: 'contribute-upload', limit: 30, windowSeconds: 3600 }),
    ],
    description: 'Upload a file for the Preservation Team to review',
  },
  // --- Contributing a word to the dictionary --------------------------------
  // A route of its own because a word is not a photograph: what arrives here is
  // a whole proposed entry — variants, parts of speech, meanings, sentences —
  // and it would not survive being squeezed into "title" and "description".
  //
  // --- Sending in news ------------------------------------------------------
  // Anybody may WRITE news; only an administrator may PUBLISH it. Those are
  // different permissions, and keeping them apart is what makes News the
  // community's official channel rather than a noticeboard.
  {
    method: 'GET',
    path: '/api/contribute/news/form',
    handler: newsFormOptions,
    description: 'The categories the news form offers',
  },
  {
    method: 'POST',
    path: '/api/contribute/news',
    handler: submitNews,
    middleware: [
      requireMembership,
      rateLimit({ scope: 'contribute-news', limit: 20, windowSeconds: 3600 }),
    ],
    description: 'Send news in for an administrator to consider publishing',
  },
  {
    method: 'GET',
    path: '/api/contribute/news/:reference',
    handler: newsSubmissionStatus,
    description: 'What happened to news you sent in',
  },

  // --- Contributing a person ------------------------------------------------
  // A structured profile rather than a description box, for the same reason
  // words get their own form: when the destination is structured, an
  // unstructured contribution is taken apart by whoever reviews it — badly,
  // and from memory.
  //
  // Registered before `/api/contribute/status/:reference` so `person` is never
  // read as a reference code.
  {
    method: 'GET',
    path: '/api/contribute/person/form',
    handler: personFormOptions,
    description: 'The categories and consent bases the profile builder offers',
  },
  {
    method: 'POST',
    path: '/api/contribute/person',
    handler: submitPerson,
    middleware: [
      requireMembership,
      rateLimit({ scope: 'contribute-person', limit: 20, windowSeconds: 3600 }),
    ],
    description: 'Send a profile of somebody from Ekoli-Yeden for review',
  },
  {
    method: 'GET',
    path: '/api/contribute/person/:reference',
    handler: personSubmissionStatus,
    description: 'What happened to a profile you sent in',
  },

  // Registered before `/api/contribute/status/:reference` so that `word` is
  // never read as a reference code.
  {
    method: 'GET',
    path: '/api/contribute/word/form',
    handler: wordFormOptions,
    description: 'The parts of speech, categories and variant kinds the word form offers',
  },
  {
    method: 'POST',
    path: '/api/contribute/word',
    handler: submitWord,
    middleware: [
      requireMembership,
      rateLimit({ scope: 'contribute-word', limit: 30, windowSeconds: 3600 }),
    ],
    description: 'Propose a dictionary entry — the word, its meanings and a sentence using it',
  },
  {
    method: 'GET',
    path: '/api/contribute/word/:reference',
    handler: wordSubmissionStatus,
    middleware: [rateLimit({ scope: 'contribute-status', limit: 60, windowSeconds: 3600 })],
    description: 'Check the progress of a proposed dictionary entry',
  },

  {
    method: 'GET',
    path: '/api/contribute/status/:reference',
    handler: checkStatus,
    middleware: [rateLimit({ scope: 'contribute-status', limit: 60, windowSeconds: 3600 })],
    description: 'Check the progress of a contribution using its reference code',
  },
];
