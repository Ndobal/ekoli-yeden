import type { Env } from './env';
import type { AuthenticatedUser } from './auth';

/** Uniform success envelope returned by every endpoint. */
export interface ApiSuccess<T> {
  success: true;
  data: T;
  meta?: Record<string, unknown>;
}

/** Uniform failure envelope. `message` is always safe to show to a visitor. */
export interface ApiFailure {
  success: false;
  error: {
    code: string;
    message: string;
    /** Field-level validation detail, when applicable. */
    details?: Record<string, string[]>;
  };
  requestId: string;
}

export type ApiResponse<T> = ApiSuccess<T> | ApiFailure;

/** Standard page envelope for list endpoints. */
export interface Paginated<T> {
  items: T[];
  page: number;
  perPage: number;
  total: number;
  totalPages: number;
}

/**
 * Everything a handler needs for one request.
 *
 * `user` is populated by the authentication middleware and is `null` for
 * anonymous (public visitor) traffic.
 */
export interface RequestContext {
  request: Request;
  env: Env;
  ctx: ExecutionContext;
  url: URL;
  /** Path parameters captured by the router, e.g. `/:slug`. */
  params: Record<string, string>;
  query: URLSearchParams;
  requestId: string;
  user: AuthenticatedUser | null;
}

export type Handler = (context: RequestContext) => Promise<Response> | Response;

/** A middleware wraps a handler and may short-circuit it. */
export type Middleware = (next: Handler) => Handler;

export type HttpMethod = 'GET' | 'POST' | 'PUT' | 'PATCH' | 'DELETE' | 'OPTIONS' | 'HEAD';

export interface RouteDefinition {
  method: HttpMethod;
  /** Pattern with `:name` segments, e.g. `/api/leboku/:year`. */
  path: string;
  handler: Handler;
  /** Middleware applied outermost-first. */
  middleware?: Middleware[];
  /** Human description, surfaced by `GET /api`. */
  description?: string;
}
