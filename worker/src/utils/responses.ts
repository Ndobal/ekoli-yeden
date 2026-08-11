import type { ApiFailure, ApiSuccess, Paginated } from '../types/api';

const JSON_HEADERS: Record<string, string> = {
  'content-type': 'application/json; charset=utf-8',
  // The archive is served to browsers; keep the obvious hardening headers on
  // every response, including errors.
  'x-content-type-options': 'nosniff',
  'referrer-policy': 'strict-origin-when-cross-origin',
};

export function json<T>(
  data: T,
  init: { status?: number; headers?: Record<string, string>; meta?: Record<string, unknown> } = {},
): Response {
  const body: ApiSuccess<T> = { success: true, data };
  if (init.meta) body.meta = init.meta;
  return new Response(JSON.stringify(body), {
    status: init.status ?? 200,
    headers: { ...JSON_HEADERS, ...init.headers },
  });
}

/**
 * `GET /api/health` returns a flat, non-enveloped body on purpose: it is the
 * contract used by uptime checks and by the Flutter client's connectivity probe.
 */
export function raw(body: unknown, init: { status?: number; headers?: Record<string, string> } = {}): Response {
  return new Response(JSON.stringify(body), {
    status: init.status ?? 200,
    headers: { ...JSON_HEADERS, ...init.headers },
  });
}

export function fail(
  status: number,
  code: string,
  message: string,
  requestId: string,
  details?: Record<string, string[]>,
  headers: Record<string, string> = {},
): Response {
  const body: ApiFailure = { success: false, error: { code, message }, requestId };
  if (details) body.error.details = details;
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...JSON_HEADERS, ...headers },
  });
}

export function paginated<T>(
  items: T[],
  page: number,
  perPage: number,
  total: number,
  headers: Record<string, string> = {},
): Response {
  const payload: Paginated<T> = {
    items,
    page,
    perPage,
    total,
    totalPages: perPage > 0 ? Math.ceil(total / perPage) : 0,
  };
  return json(payload, { headers });
}

export function noContent(headers: Record<string, string> = {}): Response {
  return new Response(null, { status: 204, headers: { ...JSON_HEADERS, ...headers } });
}

/**
 * Cache hint for public, published content. Admin and authenticated responses
 * must stay uncached — see `middleware/auth.ts`.
 */
export function publicCacheHeaders(seconds = 300): Record<string, string> {
  return { 'cache-control': `public, max-age=60, s-maxage=${seconds}` };
}

export const NO_STORE_HEADERS: Record<string, string> = { 'cache-control': 'no-store' };
