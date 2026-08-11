import { nowIso } from '../utils/id';

/**
 * Shared D1 access helpers.
 *
 * Every value that reaches SQL goes through a bound parameter. The only
 * identifiers ever interpolated into a statement are table and column names,
 * and those come exclusively from the content registry — never from a request.
 */
export interface ListOptions {
  status?: string | string[] | null;
  search?: string | null;
  searchColumns?: string[];
  filters?: Record<string, string | number | null>;
  sortColumn: string;
  sortDirection: 'ASC' | 'DESC';
  limit: number;
  offset: number;
  columns?: string[] | null;
}

export interface ListResult<T> {
  items: T[];
  total: number;
}

/** Guards an identifier that is about to be interpolated into SQL. */
export function assertSafeIdentifier(identifier: string): string {
  if (!/^[a-z_][a-z0-9_]*$/i.test(identifier)) {
    throw new Error(`Unsafe SQL identifier: ${identifier}`);
  }
  return identifier;
}

function quote(identifier: string): string {
  return `"${assertSafeIdentifier(identifier)}"`;
}

interface WhereClause {
  sql: string;
  bindings: unknown[];
}

function buildWhere(options: ListOptions): WhereClause {
  const conditions: string[] = [];
  const bindings: unknown[] = [];

  if (options.status) {
    const statuses = Array.isArray(options.status) ? options.status : [options.status];
    if (statuses.length > 0) {
      conditions.push(`"status" IN (${statuses.map(() => '?').join(', ')})`);
      bindings.push(...statuses);
    }
  }

  for (const [column, value] of Object.entries(options.filters ?? {})) {
    if (value === undefined) continue;
    if (value === null) {
      conditions.push(`${quote(column)} IS NULL`);
    } else {
      conditions.push(`${quote(column)} = ?`);
      bindings.push(value);
    }
  }

  const term = options.search?.trim();
  if (term && options.searchColumns && options.searchColumns.length > 0) {
    // `LIKE` with escaped wildcards: a visitor typing `%` searches for a
    // literal percent sign rather than matching the entire archive.
    const pattern = `%${term.replace(/[\\%_]/g, (char) => `\\${char}`)}%`;
    const parts = options.searchColumns.map((column) => `${quote(column)} LIKE ? ESCAPE '\\'`);
    conditions.push(`(${parts.join(' OR ')})`);
    for (let i = 0; i < parts.length; i += 1) bindings.push(pattern);
  }

  return {
    sql: conditions.length > 0 ? ` WHERE ${conditions.join(' AND ')}` : '',
    bindings,
  };
}

function selectList(columns: string[] | null | undefined): string {
  if (!columns || columns.length === 0) return '*';
  return columns.map(quote).join(', ');
}

export async function listRecords<T>(
  db: D1Database,
  table: string,
  options: ListOptions,
): Promise<ListResult<T>> {
  const safeTable = quote(table);
  const where = buildWhere(options);
  const orderBy = `${quote(options.sortColumn)} ${options.sortDirection === 'ASC' ? 'ASC' : 'DESC'}`;

  const countStatement = db
    .prepare(`SELECT COUNT(*) AS total FROM ${safeTable}${where.sql}`)
    .bind(...where.bindings);

  const rowsStatement = db
    .prepare(
      `SELECT ${selectList(options.columns)} FROM ${safeTable}${where.sql} ` +
        `ORDER BY ${orderBy}, "id" ASC LIMIT ? OFFSET ?`,
    )
    .bind(...where.bindings, options.limit, options.offset);

  // One round trip for both the page and its total, so a list view never costs
  // two sequential D1 calls.
  const [countResult, rowsResult] = await db.batch<Record<string, unknown>>([
    countStatement,
    rowsStatement,
  ]);

  const total = Number((countResult?.results?.[0]?.['total'] as number | undefined) ?? 0);
  return { items: (rowsResult?.results ?? []) as T[], total };
}

export async function findRecordBy<T>(
  db: D1Database,
  table: string,
  column: string,
  value: string | number,
  options: { status?: string | string[] | null; columns?: string[] | null } = {},
): Promise<T | null> {
  const conditions = [`${quote(column)} = ?`];
  const bindings: unknown[] = [value];

  if (options.status) {
    const statuses = Array.isArray(options.status) ? options.status : [options.status];
    conditions.push(`"status" IN (${statuses.map(() => '?').join(', ')})`);
    bindings.push(...statuses);
  }

  const row = await db
    .prepare(
      `SELECT ${selectList(options.columns)} FROM ${quote(table)} WHERE ${conditions.join(' AND ')} LIMIT 1`,
    )
    .bind(...bindings)
    .first<T>();

  return row ?? null;
}

export async function insertRecord(
  db: D1Database,
  table: string,
  values: Record<string, unknown>,
): Promise<void> {
  const columns = Object.keys(values);
  if (columns.length === 0) throw new Error('insertRecord called with no columns');

  await db
    .prepare(
      `INSERT INTO ${quote(table)} (${columns.map(quote).join(', ')}) ` +
        `VALUES (${columns.map(() => '?').join(', ')})`,
    )
    .bind(...columns.map((column) => values[column] ?? null))
    .run();
}

/** Returns the number of rows changed, so callers can detect a missing id. */
export async function updateRecord(
  db: D1Database,
  table: string,
  id: string,
  values: Record<string, unknown>,
): Promise<number> {
  const payload: Record<string, unknown> = { ...values, updated_at: nowIso() };
  const columns = Object.keys(payload);

  const result = await db
    .prepare(`UPDATE ${quote(table)} SET ${columns.map((c) => `${quote(c)} = ?`).join(', ')} WHERE "id" = ?`)
    .bind(...columns.map((column) => payload[column] ?? null), id)
    .run();

  return result.meta.changes ?? 0;
}

export async function deleteRecord(db: D1Database, table: string, id: string): Promise<number> {
  const result = await db.prepare(`DELETE FROM ${quote(table)} WHERE "id" = ?`).bind(id).run();
  return result.meta.changes ?? 0;
}

/** Counts rows grouped by status — the numbers shown on the admin dashboard. */
export async function countByStatus(
  db: D1Database,
  table: string,
): Promise<Record<string, number>> {
  const result = await db
    .prepare(`SELECT "status", COUNT(*) AS total FROM ${quote(table)} GROUP BY "status"`)
    .all<{ status: string; total: number }>();

  const counts: Record<string, number> = {};
  for (const row of result.results ?? []) counts[row.status] = Number(row.total);
  return counts;
}
