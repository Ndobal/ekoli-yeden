import { ConfigurationError } from './errors';

/**
 * Password hashing and token signing, built on WebCrypto only.
 *
 * No third-party crypto dependency is used: everything here is available in
 * the Workers runtime, which keeps the deploy bundle small and the trust
 * surface narrow.
 */

/**
 * PBKDF2 iteration count.
 *
 * 100,000 is the ceiling the Workers runtime enforces — asking for more throws
 * `NotSupportedError` at hashing time. OWASP currently suggests a higher figure
 * for PBKDF2-HMAC-SHA256, so this is the platform maximum rather than the
 * ideal, and it is worth revisiting if the runtime raises the cap or if
 * Argon2/scrypt becomes available here.
 *
 * Changing this number invalidates every existing password hash: the salt is
 * stored but the iteration count is not, so old hashes would no longer verify.
 * Any future change needs a migration that re-hashes on next successful login.
 */
const PBKDF2_ITERATIONS = 100_000;
const SALT_BYTES = 16;
const KEY_BITS = 256;

const encoder = new TextEncoder();

function toBase64Url(bytes: ArrayBuffer | Uint8Array): string {
  const view = bytes instanceof Uint8Array ? bytes : new Uint8Array(bytes);
  let binary = '';
  for (const byte of view) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function fromBase64Url(value: string): Uint8Array {
  const padded = value.replace(/-/g, '+').replace(/_/g, '/');
  const binary = atob(padded.padEnd(Math.ceil(padded.length / 4) * 4, '='));
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i += 1) bytes[i] = binary.charCodeAt(i);
  return bytes;
}

/** Constant-time comparison, so token checks do not leak by timing. */
export function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i += 1) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

export interface PasswordHash {
  hash: string;
  salt: string;
}

export async function hashPassword(password: string, existingSalt?: string): Promise<PasswordHash> {
  const salt = existingSalt ? fromBase64Url(existingSalt) : crypto.getRandomValues(new Uint8Array(SALT_BYTES));
  const keyMaterial = await crypto.subtle.importKey('raw', encoder.encode(password), 'PBKDF2', false, [
    'deriveBits',
  ]);
  const bits = await crypto.subtle.deriveBits(
    { name: 'PBKDF2', salt: salt as BufferSource, iterations: PBKDF2_ITERATIONS, hash: 'SHA-256' },
    keyMaterial,
    KEY_BITS,
  );
  return { hash: toBase64Url(bits), salt: toBase64Url(salt) };
}

export async function verifyPassword(password: string, hash: string, salt: string): Promise<boolean> {
  const candidate = await hashPassword(password, salt);
  return timingSafeEqual(candidate.hash, hash);
}

/** SHA-256 as base64url — used for refresh tokens, IP addresses and checksums. */
export async function sha256(value: string | ArrayBuffer): Promise<string> {
  const data = typeof value === 'string' ? encoder.encode(value) : value;
  const digest = await crypto.subtle.digest('SHA-256', data);
  return toBase64Url(digest);
}

/**
 * A visitor's IP address is personal data. The audit log stores only a salted
 * digest, which is enough to spot abuse but cannot be reversed to an address.
 */
export async function hashIp(ip: string | null, secret: string): Promise<string | null> {
  if (!ip) return null;
  return sha256(`${secret}:${ip}`);
}

export function randomToken(bytes = 32): string {
  return toBase64Url(crypto.getRandomValues(new Uint8Array(bytes)));
}

// --- Minimal HS256 JWT ------------------------------------------------------

async function hmacKey(secret: string): Promise<CryptoKey> {
  return crypto.subtle.importKey(
    'raw',
    encoder.encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign', 'verify'],
  );
}

export function requireSecret(secret: string | undefined, name: string): string {
  if (!secret || secret.length < 32) {
    throw new ConfigurationError(
      `${name} is missing or too short. Set it with \`wrangler secret put ${name}\` (or in .dev.vars for local development).`,
    );
  }
  return secret;
}

export async function signJwt(payload: Record<string, unknown>, secret: string): Promise<string> {
  const header = toBase64Url(encoder.encode(JSON.stringify({ alg: 'HS256', typ: 'JWT' })));
  const body = toBase64Url(encoder.encode(JSON.stringify(payload)));
  const signingInput = `${header}.${body}`;
  const signature = await crypto.subtle.sign('HMAC', await hmacKey(secret), encoder.encode(signingInput));
  return `${signingInput}.${toBase64Url(signature)}`;
}

/**
 * Verifies signature and expiry. Returns `null` on any failure — callers must
 * not be able to distinguish "bad signature" from "expired", which would help
 * an attacker probe the token format.
 */
export async function verifyJwt<T>(token: string, secret: string): Promise<T | null> {
  const parts = token.split('.');
  if (parts.length !== 3) return null;
  const [header, body, signature] = parts as [string, string, string];

  const valid = await crypto.subtle.verify(
    'HMAC',
    await hmacKey(secret),
    fromBase64Url(signature) as BufferSource,
    encoder.encode(`${header}.${body}`),
  );
  if (!valid) return null;

  try {
    const decoded = JSON.parse(new TextDecoder().decode(fromBase64Url(body))) as Record<string, unknown>;
    const exp = decoded['exp'];
    if (typeof exp !== 'number' || exp * 1000 <= Date.now()) return null;
    return decoded as T;
  } catch {
    return null;
  }
}
