import type { Handler, Middleware } from '../types/api';
import { RateLimitError } from '../utils/errors';

/**
 * A small in-isolate rate limiter.
 *
 * This protects the endpoints that would otherwise be attractive to abuse —
 * sign-in and public contribution — against casual scripted traffic from a
 * single address. It is intentionally simple and NOT a distributed limiter:
 * counters live in one Worker isolate and reset when that isolate recycles.
 *
 * Cloudflare's WAF and Rate Limiting rules do the real work at the edge; this
 * is defence in depth for the two endpoints that most deserve it. Module 2 can
 * promote it to a Durable Object if the community needs stricter guarantees.
 */
interface Bucket {
  count: number;
  resetAt: number;
}

const buckets = new Map<string, Bucket>();
const MAX_TRACKED_KEYS = 10_000;

function clientKey(request: Request, scope: string): string {
  const ip =
    request.headers.get('cf-connecting-ip') ??
    request.headers.get('x-forwarded-for')?.split(',')[0]?.trim() ??
    'unknown';
  return `${scope}:${ip}`;
}

export function rateLimit(options: { scope: string; limit: number; windowSeconds: number }): Middleware {
  return (next: Handler): Handler => {
    return async (context) => {
      const key = clientKey(context.request, options.scope);
      const now = Date.now();
      const existing = buckets.get(key);

      if (!existing || existing.resetAt <= now) {
        // Keep the map from growing without bound in a long-lived isolate.
        if (buckets.size > MAX_TRACKED_KEYS) buckets.clear();
        buckets.set(key, { count: 1, resetAt: now + options.windowSeconds * 1000 });
        return next(context);
      }

      if (existing.count >= options.limit) {
        throw new RateLimitError(Math.max(1, Math.ceil((existing.resetAt - now) / 1000)));
      }

      existing.count += 1;
      return next(context);
    };
  };
}
