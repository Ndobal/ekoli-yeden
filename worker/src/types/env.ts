/**
 * Bindings and configuration available to the Worker at runtime.
 *
 * Anything declared here comes from wrangler.jsonc (`vars`, `d1_databases`,
 * `r2_buckets`) or from Cloudflare secrets. Secrets are never sent to the
 * Flutter client and never appear in an API response.
 */
export interface Env {
  /** D1 — all structured data for the archive. */
  DB: D1Database;

  /** R2 — images, audio, documents, avatars, heritage scans, Leboku files. */
  MEDIA: R2Bucket;

  // --- Plain configuration (safe, non-secret) --------------------------
  ENVIRONMENT: string;
  API_VERSION: string;
  SERVICE_NAME: string;
  /** Comma-separated list of origins permitted by CORS. */
  ALLOWED_ORIGINS: string;
  /** Base URL prefix used to build public URLs for R2 objects. */
  PUBLIC_MEDIA_BASE_URL: string;
  MAX_UPLOAD_BYTES: string;
  ACCESS_TOKEN_TTL_SECONDS: string;
  REFRESH_TOKEN_TTL_SECONDS: string;

  // --- Secrets (set with `wrangler secret put`, never committed) -------
  /** HMAC key used to sign session tokens. Required in every environment. */
  JWT_SECRET?: string;
  /** Optional YouTube Data API key, used only for metadata enrichment. */
  YOUTUBE_API_KEY?: string;
}

/** Environment names recognised by the platform. */
export type EnvironmentName = 'development' | 'staging' | 'production';

export function isProduction(env: Env): boolean {
  return env.ENVIRONMENT === 'production';
}
