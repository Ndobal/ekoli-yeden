import type { Env } from '../types/env';

/**
 * CORS.
 *
 * The origin allow-list comes from `ALLOWED_ORIGINS` in wrangler.jsonc, one
 * value per environment. There is no `*` fallback: the API carries credentials
 * and admin operations, so an unknown origin receives no CORS headers and the
 * browser blocks the response.
 *
 * ---------------------------------------------------------------------------
 * WHY THIS IS THE MOST DANGEROUS FILE IN THE WORKER TO GET SLIGHTLY WRONG
 * ---------------------------------------------------------------------------
 *
 * A browser does not tell a page WHY a cross-origin request failed. A rejected
 * origin and an unplugged network cable are the same event to JavaScript, so
 * the archive told people "we could not reach the archive. Please check your
 * internet connection" while the connection was perfectly fine and the server
 * was answering every request correctly.
 *
 * That is exactly what happened: the allow-list held one exact string, and
 * every Cloudflare Pages preview deployment gets its own hostname
 * (`https://32ade2f8.ekoli.pages.dev`). Anybody following one of those links —
 * and every deploy prints one — could read the site, because reading is
 * same-origin static hosting, and could not register, sign in, or do anything
 * at all that touched the API.
 *
 * So exact strings are still the rule, and a single deliberate pattern is
 * allowed alongside them: an entry beginning `*.` matches that host's
 * subdomains. It is opt-in per environment, it never matches the apex on its
 * own, and it is not a wildcard for the whole internet.
 */
export function allowedOrigins(env: Env): string[] {
  return env.ALLOWED_ORIGINS.split(',')
    .map((origin) => origin.trim())
    .filter((origin) => origin.length > 0);
}

/**
 * Whether one allow-list entry admits this origin.
 *
 * `https://*.ekoli.pages.dev` admits `https://abc123.ekoli.pages.dev` and
 * `https://ekoli.pages.dev` is a separate entry — a pattern deliberately does
 * not admit its own apex, so removing the apex from the list actually removes
 * it.
 *
 * The scheme is compared too. `http://evil.ekoli.pages.dev` is not admitted by
 * an `https://` pattern, and the dot before the host is required so that
 * `https://*.ekoli.pages.dev` cannot be satisfied by `https://notekoli.pages.dev`.
 */
function admits(entry: string, origin: string): boolean {
  if (entry === origin) return true;

  const marker = '://*.';
  const at = entry.indexOf(marker);
  if (at < 0) return false;

  const scheme = entry.slice(0, at + 3);
  const host = entry.slice(at + marker.length);
  if (host.length === 0) return false;

  return origin.startsWith(scheme) && origin.endsWith(`.${host}`);
}

export function resolveOrigin(request: Request, env: Env): string | null {
  const origin = request.headers.get('origin');
  if (!origin) return null;

  // The origin is echoed back only after matching. Never reflected blindly:
  // the API carries credentials, and reflecting an arbitrary origin with
  // `allow-credentials` hands every site on the internet a signed-in session.
  return allowedOrigins(env).some((entry) => admits(entry, origin)) ? origin : null;
}

export function corsHeaders(request: Request, env: Env): Record<string, string> {
  const origin = resolveOrigin(request, env);
  if (!origin) return {};
  return {
    'access-control-allow-origin': origin,
    'access-control-allow-credentials': 'true',
    // Caches must not serve one origin's response to another.
    vary: 'Origin',
  };
}

/** Answers the browser's preflight without ever reaching a route handler. */
export function handlePreflight(request: Request, env: Env): Response | null {
  if (request.method !== 'OPTIONS') return null;
  if (!request.headers.get('access-control-request-method')) return null;

  const origin = resolveOrigin(request, env);
  if (!origin) {
    // A body, rather than a bare 403. JavaScript cannot read it — that is the
    // whole nature of a CORS rejection — but a person looking at the Network
    // tab, or anybody running curl to find out why registration is failing,
    // gets told what is actually wrong instead of guessing.
    return new Response(
      JSON.stringify({
        success: false,
        error: {
          code: 'ORIGIN_NOT_ALLOWED',
          message:
            `The origin ${request.headers.get('origin') ?? 'unknown'} is not on this API's `
            + 'allow-list, so the browser will block the response. Add it to ALLOWED_ORIGINS.',
        },
      }),
      { status: 403, headers: { 'content-type': 'application/json; charset=utf-8' } },
    );
  }

  return new Response(null, {
    status: 204,
    headers: {
      'access-control-allow-origin': origin,
      'access-control-allow-credentials': 'true',
      'access-control-allow-methods': 'GET, POST, PUT, PATCH, DELETE, OPTIONS',
      'access-control-allow-headers': 'Content-Type, Authorization, X-Request-Id',
      'access-control-max-age': '86400',
      vary: 'Origin',
    },
  });
}

/** Copies CORS headers onto a response produced by a handler. */
export function withCors(response: Response, request: Request, env: Env): Response {
  const headers = corsHeaders(request, env);
  if (Object.keys(headers).length === 0) return response;

  const merged = new Headers(response.headers);
  for (const [key, value] of Object.entries(headers)) merged.set(key, value);
  return new Response(response.body, {
    status: response.status,
    statusText: response.statusText,
    headers: merged,
  });
}
