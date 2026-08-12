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

  /** R2 — the published archive: images, audio, documents, heritage scans. */
  MEDIA: R2Bucket;

  /**
   * R2 — material contributed by the community, awaiting review.
   *
   * Deliberately a separate bucket rather than a folder in MEDIA. Unreviewed
   * material and the published archive have different audiences, different
   * retention and different risk: a bucket boundary means a mistake in the
   * media-serving path cannot expose something nobody has looked at yet, and
   * the community can apply its own lifecycle rules to submissions without
   * touching the archive.
   */
  SUBMISSIONS: R2Bucket;

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

  /** Public site origin, used to build password reset links. */
  SITE_URL?: string;

  // --- Secrets (set with `wrangler secret put`, never committed) -------
  /** HMAC key used to sign session tokens. Required in every environment. */
  JWT_SECRET?: string;
  /** Optional YouTube Data API key, used only for metadata enrichment. */
  YOUTUBE_API_KEY?: string;

  /**
   * Email delivery for password resets. Optional: without it the reset flow
   * still works, and a Super Admin passes the link on by hand.
   */
  RESEND_API_KEY?: string;
  RESET_EMAIL_FROM?: string;

  /** WhatsApp Cloud API, for communities who read WhatsApp before email. */
  WHATSAPP_TOKEN?: string;
  WHATSAPP_PHONE_NUMBER_ID?: string;
}

/** Environment names recognised by the platform. */
export type EnvironmentName = 'development' | 'staging' | 'production';

export function isProduction(env: Env): boolean {
  return env.ENVIRONMENT === 'production';
}
