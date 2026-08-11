import type { Env } from '../types/env';

/**
 * CORS.
 *
 * The origin allow-list comes from `ALLOWED_ORIGINS` in wrangler.jsonc, one
 * value per environment. There is no `*` fallback: the API carries credentials
 * and admin operations, so an unknown origin simply receives no CORS headers
 * and the browser blocks the response.
 */
export function allowedOrigins(env: Env): string[] {
  return env.ALLOWED_ORIGINS.split(',')
    .map((origin) => origin.trim())
    .filter((origin) => origin.length > 0);
}

export function resolveOrigin(request: Request, env: Env): string | null {
  const origin = request.headers.get('origin');
  if (!origin) return null;
  return allowedOrigins(env).includes(origin) ? origin : null;
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
  if (!origin) return new Response(null, { status: 403 });

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
