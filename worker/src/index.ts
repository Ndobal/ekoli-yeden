import type { Env } from './types/env';
import { buildRouter } from './routes';
import { AuthService } from './services/auth.service';
import { handlePreflight, withCors } from './middleware/cors';
import { toErrorResponse } from './middleware/error-handler';
import { json } from './utils/responses';
import { newId } from './utils/id';

/**
 * EKOLI YEDEN DIGITAL HOME — API Worker
 * "Preserving Our Past. Celebrating Our Present. Building Our Future."
 *
 * This Worker is the whole backend. The Flutter Web client on Cloudflare Pages
 * talks only to this, and this is the only thing that holds a D1 binding, an R2
 * binding or a secret.
 *
 *   Flutter Web (Cloudflare Pages)
 *        ↓ HTTPS
 *   Cloudflare Worker  ← you are here
 *        ↓
 *   D1 (records) · R2 (files) · YouTube (videos)
 */

// The router is built once per isolate rather than per request: route tables
// are static, and rebuilding them on every request would waste CPU time on a
// site that is mostly serving reads.
const router = buildRouter();

export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    // A request id ties an error the visitor sees to the line in the log that
    // explains it, without exposing anything about the failure itself.
    const requestId = request.headers.get('x-request-id') ?? newId();

    const preflight = handlePreflight(request, env);
    if (preflight) return preflight;

    const url = new URL(request.url);

    try {
      // The API index is served at the root so that opening the Worker URL in a
      // browser explains what it is rather than returning a bare 404.
      if (url.pathname === '/' || url.pathname === '/api') {
        return withCors(apiIndex(env), request, env);
      }

      // Authentication runs once for every request. A missing or invalid token
      // simply yields an anonymous context — it is not an error, because most
      // of this archive is meant to be read by anyone.
      const user = await new AuthService(env)
        .resolveUser(request.headers.get('authorization'))
        .catch(() => null);

      const response = await router.handle({
        request,
        env,
        ctx,
        url,
        query: url.searchParams,
        requestId,
        user,
      });

      return withCors(withRequestId(response, requestId), request, env);
    } catch (error) {
      return withCors(withRequestId(toErrorResponse(error, requestId, env), requestId), request, env);
    }
  },
} satisfies ExportedHandler<Env>;

function withRequestId(response: Response, requestId: string): Response {
  const headers = new Headers(response.headers);
  headers.set('x-request-id', requestId);
  return new Response(response.body, {
    status: response.status,
    statusText: response.statusText,
    headers,
  });
}

/** A self-describing index, useful during development and for monitoring. */
function apiIndex(env: Env): Response {
  return json({
    service: env.SERVICE_NAME,
    tagline: 'Preserving Our Past. Celebrating Our Present. Building Our Future.',
    version: env.API_VERSION,
    environment: env.ENVIRONMENT,
    documentation: '/docs/architecture.md',
    endpoints: router.inventory(),
  });
}
