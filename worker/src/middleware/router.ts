import type {
  Handler,
  HttpMethod,
  Middleware,
  RequestContext,
  RouteDefinition,
} from '../types/api';
import { NotFoundError } from '../utils/errors';

/**
 * A dependency-free router.
 *
 * Patterns support `:name` segments (`/api/leboku/:year`) and a single
 * trailing `*` wildcard (`/api/media/file/*`), which is what the R2 media
 * route needs because object keys contain slashes.
 */
interface CompiledRoute {
  method: HttpMethod;
  segments: string[];
  handler: Handler;
  description: string | undefined;
}

export class Router {
  private readonly routes: CompiledRoute[] = [];

  register(definition: RouteDefinition): this {
    const handler = applyMiddleware(definition.handler, definition.middleware ?? []);
    this.routes.push({
      method: definition.method,
      segments: splitPath(definition.path),
      handler,
      description: definition.description,
    });
    return this;
  }

  registerAll(definitions: RouteDefinition[]): this {
    for (const definition of definitions) this.register(definition);
    return this;
  }

  /** Resolves and runs a request, throwing `NotFoundError` when nothing matches. */
  async handle(context: Omit<RequestContext, 'params'>): Promise<Response> {
    const pathSegments = splitPath(context.url.pathname);
    let methodMismatch = false;

    for (const route of this.routes) {
      const params = matchSegments(route.segments, pathSegments);
      if (params === null) continue;
      if (route.method !== context.request.method) {
        methodMismatch = true;
        continue;
      }
      return route.handler({ ...context, params });
    }

    if (methodMismatch) {
      throw new NotFoundError('That method is not supported for this endpoint.');
    }
    throw new NotFoundError('That endpoint does not exist.');
  }

  /** Route inventory, published by `GET /api` for developers and monitoring. */
  inventory(): { method: string; path: string; description: string | null }[] {
    return this.routes.map((route) => ({
      method: route.method,
      path: `/${route.segments.join('/')}`,
      description: route.description ?? null,
    }));
  }
}

function splitPath(path: string): string[] {
  return path.split('/').filter((segment) => segment.length > 0);
}

/**
 * Returns captured params, or `null` when the pattern does not match.
 * An empty object is a successful match with no params, which is why the
 * failure signal is `null` rather than a falsy object.
 */
function matchSegments(pattern: string[], actual: string[]): Record<string, string> | null {
  const params: Record<string, string> = {};

  for (let i = 0; i < pattern.length; i += 1) {
    const expected = pattern[i] as string;

    if (expected === '*') {
      // Trailing wildcard swallows the rest of the path, slashes included.
      params['wildcard'] = actual.slice(i).map(decodeSegment).join('/');
      return params;
    }

    const segment = actual[i];
    if (segment === undefined) return null;

    if (expected.startsWith(':')) {
      params[expected.slice(1)] = decodeSegment(segment);
      continue;
    }
    if (expected !== segment) return null;
  }

  return actual.length === pattern.length ? params : null;
}

function decodeSegment(segment: string): string {
  try {
    return decodeURIComponent(segment);
  } catch {
    return segment;
  }
}

/** Wraps a handler so that middleware listed first runs outermost. */
export function applyMiddleware(handler: Handler, middleware: Middleware[]): Handler {
  return middleware.reduceRight<Handler>((next, wrap) => wrap(next), handler);
}
