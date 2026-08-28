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
   * OPTIONAL, and unbound today. The intent is a separate bucket: unreviewed
   * material and the published archive have different audiences, different
   * retention and different risk, and a bucket boundary is the strongest way
   * to say so. But a binding to a bucket that does not exist fails the whole
   * deploy, which took the contribution form offline entirely — a worse
   * outcome than sharing a bucket.
   *
   * So when this is unbound, contributions land in MEDIA instead. What keeps
   * them private is not the bucket, it is `MediaService.serve`: it resolves a
   * storage key through the `media_assets` table and 404s when there is no
   * row. A contributed file has no such row until it is approved, so it is
   * unreachable at `/api/media/file/*` no matter who guesses the key.
   *
   * To restore the separation: create the bucket, add the binding back to
   * wrangler.jsonc, redeploy. Nothing else changes — keys are identical
   * either way, and existing records keep resolving.
   */
  SUBMISSIONS?: R2Bucket;

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
