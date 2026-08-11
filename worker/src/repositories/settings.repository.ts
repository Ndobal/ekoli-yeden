import type { SiteSettingRecord } from '../types/models';
import { nowIso } from '../utils/id';

/**
 * Site settings.
 *
 * Everything an administrator can change without a deployment lives here:
 * site title, tagline, contact details, social links, feature switches. The
 * Flutter client reads only the rows flagged `is_public`.
 */
export class SettingsRepository {
  constructor(private readonly db: D1Database) {}

  async all(): Promise<SiteSettingRecord[]> {
    const result = await this.db
      .prepare('SELECT * FROM "site_settings" ORDER BY "group_name" ASC, "key" ASC')
      .all<SiteSettingRecord>();
    return result.results ?? [];
  }

  async publicSettings(): Promise<SiteSettingRecord[]> {
    const result = await this.db
      .prepare('SELECT * FROM "site_settings" WHERE "is_public" = 1 ORDER BY "group_name" ASC, "key" ASC')
      .all<SiteSettingRecord>();
    return result.results ?? [];
  }

  async get(key: string): Promise<SiteSettingRecord | null> {
    const row = await this.db
      .prepare('SELECT * FROM "site_settings" WHERE "key" = ? LIMIT 1')
      .bind(key)
      .first<SiteSettingRecord>();
    return row ?? null;
  }

  /**
   * Updates an existing setting. Settings are created by migrations so that the
   * set of keys stays under version control; an administrator changes values,
   * not the schema.
   */
  async setValue(key: string, value: string | null): Promise<number> {
    const result = await this.db
      .prepare('UPDATE "site_settings" SET "value" = ?, "updated_at" = ? WHERE "key" = ?')
      .bind(value, nowIso(), key)
      .run();
    return result.meta.changes ?? 0;
  }
}

/** Converts stored rows into the typed map the Flutter client consumes. */
export function settingsToMap(rows: SiteSettingRecord[]): Record<string, unknown> {
  const map: Record<string, unknown> = {};
  for (const row of rows) {
    map[row.key] = coerceSettingValue(row.value, row.value_type);
  }
  return map;
}

function coerceSettingValue(value: string | null, valueType: string): unknown {
  if (value === null) return null;
  switch (valueType) {
    case 'boolean':
      return value === 'true' || value === '1';
    case 'number': {
      const parsed = Number(value);
      return Number.isFinite(parsed) ? parsed : null;
    }
    case 'json':
      try {
        return JSON.parse(value);
      } catch {
        return null;
      }
    default:
      return value;
  }
}
