import type { Env } from '../types/env';
import { AppError, RateLimitError } from '../utils/errors';
import { fail } from '../utils/responses';

/**
 * The last line of defence.
 *
 * Anything thrown anywhere in the Worker ends up here. Known `AppError`s carry
 * a message written for a community member to read; everything else becomes a
 * generic 500 and the detail goes to the log, never to the client.
 */
export function toErrorResponse(error: unknown, requestId: string, env: Env): Response {
  if (error instanceof AppError) {
    const headers: Record<string, string> = { 'cache-control': 'no-store' };
    if (error instanceof RateLimitError) {
      headers['retry-after'] = String(error.retryAfterSeconds);
    }

    if (!error.expose) {
      console.error(`[${requestId}] ${error.code}: ${error.message}`, error.cause ?? '');
      return fail(
        error.status,
        error.code,
        'The service is not correctly configured. Please contact the administrator.',
        requestId,
        undefined,
        headers,
      );
    }

    // 5xx is always worth a log line even when the message is safe to expose.
    if (error.status >= 500) {
      console.error(`[${requestId}] ${error.code}: ${error.message}`, error.cause ?? '');
    }

    return fail(error.status, error.code, error.message, requestId, error.details, headers);
  }

  console.error(`[${requestId}] Unhandled error`, error);

  // In development the message helps; in staging/production it never leaves the log.
  const message =
    env.ENVIRONMENT === 'development' && error instanceof Error
      ? error.message
      : 'Something went wrong while processing your request.';

  return fail(500, 'INTERNAL_ERROR', message, requestId, undefined, { 'cache-control': 'no-store' });
}
