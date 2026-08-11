import { ValidationError, BadRequestError } from './errors';
import { ALL_CONTENT_STATUSES, type ContentStatus } from '../types/models';

/**
 * A small, dependency-free validator.
 *
 * Every write endpoint validates on the server. The Flutter client also
 * validates, but only to give the contributor fast feedback — the client's
 * checks are never trusted.
 */
export class Validator {
  private readonly errors: Record<string, string[]> = {};
  private readonly source: Record<string, unknown>;
  private readonly output: Record<string, unknown> = {};

  constructor(source: Record<string, unknown>) {
    this.source = source;
  }

  private add(field: string, message: string): void {
    (this.errors[field] ??= []).push(message);
  }

  private rawString(field: string): string | undefined {
    const value = this.source[field];
    if (value === undefined || value === null) return undefined;
    if (typeof value !== 'string') {
      this.add(field, 'Must be text.');
      return undefined;
    }
    return value.trim();
  }

  string(
    field: string,
    opts: { required?: boolean; min?: number; max?: number; pattern?: RegExp; label?: string } = {},
  ): this {
    const label = opts.label ?? field;
    const value = this.rawString(field);
    if (value === undefined || value === '') {
      if (opts.required) this.add(field, `${label} is required.`);
      else if (value === '') this.output[field] = null;
      return this;
    }
    if (opts.min !== undefined && value.length < opts.min) {
      this.add(field, `${label} must be at least ${opts.min} characters.`);
      return this;
    }
    const max = opts.max ?? 10_000;
    if (value.length > max) {
      this.add(field, `${label} must be at most ${max} characters.`);
      return this;
    }
    if (opts.pattern && !opts.pattern.test(value)) {
      this.add(field, `${label} is not in the expected format.`);
      return this;
    }
    this.output[field] = value;
    return this;
  }

  email(field: string, opts: { required?: boolean } = {}): this {
    const value = this.rawString(field);
    if (!value) {
      if (opts.required) this.add(field, 'An email address is required.');
      return this;
    }
    // Deliberately permissive: rejecting unusual but valid addresses would shut
    // community members out of the archive.
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(value) || value.length > 254) {
      this.add(field, 'Enter a valid email address.');
      return this;
    }
    this.output[field] = value.toLowerCase();
    return this;
  }

  integer(
    field: string,
    opts: { required?: boolean; min?: number; max?: number; label?: string } = {},
  ): this {
    const label = opts.label ?? field;
    const value = this.source[field];
    if (value === undefined || value === null || value === '') {
      if (opts.required) this.add(field, `${label} is required.`);
      return this;
    }
    const parsed = typeof value === 'number' ? value : Number(value);
    if (!Number.isFinite(parsed) || !Number.isInteger(parsed)) {
      this.add(field, `${label} must be a whole number.`);
      return this;
    }
    if (opts.min !== undefined && parsed < opts.min) {
      this.add(field, `${label} must be ${opts.min} or greater.`);
      return this;
    }
    if (opts.max !== undefined && parsed > opts.max) {
      this.add(field, `${label} must be ${opts.max} or less.`);
      return this;
    }
    this.output[field] = parsed;
    return this;
  }

  boolean(field: string, opts: { required?: boolean } = {}): this {
    const value = this.source[field];
    if (value === undefined || value === null) {
      if (opts.required) this.add(field, 'This field is required.');
      return this;
    }
    if (typeof value === 'boolean') {
      this.output[field] = value ? 1 : 0;
      return this;
    }
    if (value === 'true' || value === 1 || value === '1') {
      this.output[field] = 1;
      return this;
    }
    if (value === 'false' || value === 0 || value === '0') {
      this.output[field] = 0;
      return this;
    }
    this.add(field, 'Must be true or false.');
    return this;
  }

  /** ISO date (`YYYY-MM-DD`) or full ISO-8601 timestamp. */
  date(field: string, opts: { required?: boolean; label?: string } = {}): this {
    const label = opts.label ?? field;
    const value = this.rawString(field);
    if (!value) {
      if (opts.required) this.add(field, `${label} is required.`);
      return this;
    }
    if (Number.isNaN(Date.parse(value))) {
      this.add(field, `${label} must be a valid date.`);
      return this;
    }
    this.output[field] = value;
    return this;
  }

  oneOf(field: string, allowed: readonly string[], opts: { required?: boolean } = {}): this {
    const value = this.rawString(field);
    if (!value) {
      if (opts.required) this.add(field, 'This field is required.');
      return this;
    }
    if (!allowed.includes(value)) {
      this.add(field, `Must be one of: ${allowed.join(', ')}.`);
      return this;
    }
    this.output[field] = value;
    return this;
  }

  status(field = 'status', opts: { required?: boolean } = {}): this {
    return this.oneOf(field, ALL_CONTENT_STATUSES, opts);
  }

  /** An array of strings, stored in D1 as a JSON string. */
  stringArray(field: string, opts: { required?: boolean; maxItems?: number } = {}): this {
    const value = this.source[field];
    if (value === undefined || value === null) {
      if (opts.required) this.add(field, 'This field is required.');
      return this;
    }
    if (!Array.isArray(value) || value.some((item) => typeof item !== 'string')) {
      this.add(field, 'Must be a list of text values.');
      return this;
    }
    if (opts.maxItems !== undefined && value.length > opts.maxItems) {
      this.add(field, `At most ${opts.maxItems} items are allowed.`);
      return this;
    }
    this.output[field] = JSON.stringify(value);
    return this;
  }

  /** Free-form JSON (programme, sponsors), stored as a JSON string. */
  jsonValue(field: string, opts: { required?: boolean; maxBytes?: number } = {}): this {
    const value = this.source[field];
    if (value === undefined || value === null) {
      if (opts.required) this.add(field, 'This field is required.');
      return this;
    }
    let encoded: string;
    try {
      encoded = JSON.stringify(value);
    } catch {
      this.add(field, 'Must be valid structured data.');
      return this;
    }
    const maxBytes = opts.maxBytes ?? 200_000;
    if (encoded.length > maxBytes) {
      this.add(field, 'The structured data is too large.');
      return this;
    }
    this.output[field] = encoded;
    return this;
  }

  /**
   * A YouTube video id. Accepts a bare id or any of the common URL forms so
   * that a Media Team volunteer can paste whatever their browser shows.
   */
  youtubeVideoId(field: string, opts: { required?: boolean } = {}): this {
    const value = this.rawString(field);
    if (!value) {
      if (opts.required) this.add(field, 'A YouTube video is required.');
      return this;
    }
    const id = extractYouTubeId(value);
    if (!id) {
      this.add(field, 'Enter a valid YouTube video link or id.');
      return this;
    }
    this.output[field] = id;
    return this;
  }

  url(field: string, opts: { required?: boolean } = {}): this {
    const value = this.rawString(field);
    if (!value) {
      if (opts.required) this.add(field, 'A link is required.');
      return this;
    }
    let parsed: URL;
    try {
      parsed = new URL(value);
    } catch {
      this.add(field, 'Enter a valid link.');
      return this;
    }
    if (parsed.protocol !== 'https:' && parsed.protocol !== 'http:') {
      this.add(field, 'Links must start with http:// or https://.');
      return this;
    }
    this.output[field] = parsed.toString();
    return this;
  }

  /** Throws if anything failed; otherwise returns only the validated fields. */
  validated(): Record<string, unknown> {
    if (Object.keys(this.errors).length > 0) throw new ValidationError(this.errors);
    return this.output;
  }
}

const YOUTUBE_ID = /^[A-Za-z0-9_-]{11}$/;

/** Pulls an 11-character video id out of a bare id or a YouTube URL. */
export function extractYouTubeId(input: string): string | null {
  const trimmed = input.trim();
  if (YOUTUBE_ID.test(trimmed)) return trimmed;

  let url: URL;
  try {
    url = new URL(trimmed);
  } catch {
    return null;
  }

  const host = url.hostname.replace(/^www\./, '');
  if (host === 'youtu.be') {
    const candidate = url.pathname.slice(1);
    return YOUTUBE_ID.test(candidate) ? candidate : null;
  }
  if (host === 'youtube.com' || host === 'm.youtube.com' || host === 'youtube-nocookie.com') {
    const fromQuery = url.searchParams.get('v');
    if (fromQuery && YOUTUBE_ID.test(fromQuery)) return fromQuery;
    // /embed/<id>, /shorts/<id>, /live/<id>, /v/<id>
    const segments = url.pathname.split('/').filter(Boolean);
    const last = segments[segments.length - 1];
    if (last && YOUTUBE_ID.test(last)) return last;
  }
  return null;
}

/** Reads and size-guards a JSON request body. */
export async function readJsonBody(request: Request, maxBytes = 512_000): Promise<Record<string, unknown>> {
  const contentType = request.headers.get('content-type') ?? '';
  if (!contentType.includes('application/json')) {
    throw new BadRequestError('Expected a JSON request body.');
  }
  const declared = Number(request.headers.get('content-length') ?? '0');
  if (Number.isFinite(declared) && declared > maxBytes) {
    throw new BadRequestError('The request body is too large.');
  }
  const text = await request.text();
  if (text.length > maxBytes) throw new BadRequestError('The request body is too large.');
  if (text.trim() === '') return {};
  try {
    const parsed: unknown = JSON.parse(text);
    if (parsed === null || typeof parsed !== 'object' || Array.isArray(parsed)) {
      throw new BadRequestError('Expected a JSON object.');
    }
    return parsed as Record<string, unknown>;
  } catch (error) {
    if (error instanceof BadRequestError) throw error;
    throw new BadRequestError('The request body is not valid JSON.');
  }
}

/** Parses a `?status=` filter, restricted to statuses the caller may see. */
export function parseStatusFilter(value: string | null, allowed: ContentStatus[]): ContentStatus | null {
  if (!value) return null;
  const match = allowed.find((status) => status === value);
  return match ?? null;
}
