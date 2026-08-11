import type { RequestContext } from '../types/api';
import { NO_STORE_HEADERS, json, raw } from '../utils/responses';

/**
 * `GET /api/health`
 *
 * The response shape here is a fixed contract — uptime monitors, the Cloudflare
 * Pages build check and the Flutter client's connectivity probe all read it —
 * so it deliberately does not use the standard success envelope.
 */
export async function health(context: RequestContext): Promise<Response> {
  return raw(
    {
      success: true,
      service: context.env.SERVICE_NAME,
      status: 'healthy',
    },
    { headers: NO_STORE_HEADERS },
  );
}

/**
 * `GET /api/health/ready`
 *
 * A deeper check that actually touches D1 and R2. Used after a deployment and
 * after running migrations; not suitable as a high-frequency uptime probe
 * because it costs a database read.
 */
export async function readiness(context: RequestContext): Promise<Response> {
  const checks: Record<string, { ok: boolean; detail: string }> = {};

  try {
    const row = await context.env.DB.prepare('SELECT COUNT(*) AS total FROM "roles"').first<{ total: number }>();
    checks['d1'] = { ok: true, detail: `connected, ${Number(row?.total ?? 0)} roles defined` };
  } catch (error) {
    // The reason is logged, not returned: it can name tables and bindings.
    console.error(`[${context.requestId}] D1 readiness check failed`, error);
    checks['d1'] = { ok: false, detail: 'unavailable or migrations not applied' };
  }

  try {
    await context.env.MEDIA.head('__readiness_probe__');
    checks['r2'] = { ok: true, detail: 'bucket reachable' };
  } catch (error) {
    console.error(`[${context.requestId}] R2 readiness check failed`, error);
    checks['r2'] = { ok: false, detail: 'unavailable' };
  }

  checks['jwt_secret'] = {
    ok: Boolean(context.env.JWT_SECRET && context.env.JWT_SECRET.length >= 32),
    detail: context.env.JWT_SECRET ? 'configured' : 'not set — authentication is disabled',
  };

  const allOk = Object.values(checks).every((check) => check.ok);

  return json(
    {
      service: context.env.SERVICE_NAME,
      version: context.env.API_VERSION,
      environment: context.env.ENVIRONMENT,
      ready: allOk,
      checks,
    },
    { status: allOk ? 200 : 503, headers: NO_STORE_HEADERS },
  );
}
