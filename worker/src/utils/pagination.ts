export interface PageRequest {
  page: number;
  perPage: number;
  offset: number;
}

const DEFAULT_PER_PAGE = 20;
const MAX_PER_PAGE = 100;

/**
 * Reads `?page=` and `?perPage=`.
 *
 * `perPage` is capped so that a single request can never ask D1 to return the
 * whole archive.
 */
export function parsePagination(query: URLSearchParams): PageRequest {
  const rawPage = Number(query.get('page') ?? '1');
  const rawPerPage = Number(query.get('perPage') ?? String(DEFAULT_PER_PAGE));

  const page = Number.isFinite(rawPage) && rawPage >= 1 ? Math.floor(rawPage) : 1;
  const perPage =
    Number.isFinite(rawPerPage) && rawPerPage >= 1
      ? Math.min(Math.floor(rawPerPage), MAX_PER_PAGE)
      : DEFAULT_PER_PAGE;

  return { page, perPage, offset: (page - 1) * perPage };
}

/**
 * Validates a sort request against an allow-list.
 *
 * The column name is interpolated into SQL, so it must never come straight
 * from the query string.
 */
export function parseSort(
  query: URLSearchParams,
  allowedColumns: readonly string[],
  fallback: string,
): { column: string; direction: 'ASC' | 'DESC' } {
  const requested = query.get('sort');
  const column = requested && allowedColumns.includes(requested) ? requested : fallback;
  const direction = (query.get('order') ?? 'desc').toLowerCase() === 'asc' ? 'ASC' : 'DESC';
  return { column, direction };
}
