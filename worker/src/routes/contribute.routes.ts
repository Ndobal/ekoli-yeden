import type { RouteDefinition } from '../types/api';
import { checkStatus, contributionTypes, submit } from '../controllers/submission.controller';
import { contributeUpload } from '../controllers/media.controller';
import { rateLimit } from '../middleware/rate-limit';

/**
 * CONTRIBUTE TO EKOLI YEDEN
 *
 * Open to anyone — an elder's grandchild with a photograph on their phone does
 * not need an account. Everything lands in `pending_review`.
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
    middleware: [rateLimit({ scope: 'contribute', limit: 10, windowSeconds: 3600 })],
    description: 'Submit material to the archive for review',
  },
  {
    method: 'POST',
    path: '/api/contribute/media',
    handler: contributeUpload,
    middleware: [rateLimit({ scope: 'contribute-media', limit: 20, windowSeconds: 3600 })],
    description: 'Attach a photograph, document or recording to a contribution',
  },
  {
    method: 'GET',
    path: '/api/contribute/status/:reference',
    handler: checkStatus,
    middleware: [rateLimit({ scope: 'contribute-status', limit: 60, windowSeconds: 3600 })],
    description: 'Check the progress of a contribution using its reference code',
  },
];
