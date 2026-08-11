import { CONTENT_RESOURCES } from './content-registry';
import { CONTENT_STATUS } from '../types/models';
import { listRecords } from '../repositories/base.repository';

/**
 * Cross-archive search.
 *
 * Module 1 implements this as a fan-out of `LIKE` queries across every
 * registered content type, which is correct and cheap while the archive is
 * small. Because the registry already declares each resource's searchable
 * columns, swapping the implementation for D1 FTS5 in a later module is a
 * change to this file alone — no route, client or schema contract moves.
 */
export interface SearchHit {
  resource: string;
  label: string;
  id: string;
  slug: string | null;
  title: string;
  excerpt: string | null;
  updatedAt: string | null;
}

export interface SearchResults {
  query: string;
  total: number;
  groups: { resource: string; label: string; total: number; hits: SearchHit[] }[];
}

const PER_RESOURCE_LIMIT = 5;

export async function searchArchive(
  db: D1Database,
  term: string,
  options: { resources?: string[]; perResource?: number } = {},
): Promise<SearchResults> {
  const trimmed = term.trim();
  if (trimmed.length < 2) {
    return { query: trimmed, total: 0, groups: [] };
  }

  const limit = options.perResource ?? PER_RESOURCE_LIMIT;
  const wanted = options.resources?.length
    ? Object.values(CONTENT_RESOURCES).filter((r) => options.resources?.includes(r.key))
    : Object.values(CONTENT_RESOURCES);

  const searchable = wanted.filter((resource) => resource.searchable);

  const groups = await Promise.all(
    searchable.map(async (resource) => {
      const { items, total } = await listRecords<Record<string, unknown>>(db, resource.table, {
        // Search never reaches beyond published content: an unpublished draft
        // must not be discoverable by guessing at its words.
        status: CONTENT_STATUS.PUBLISHED,
        search: trimmed,
        searchColumns: resource.searchableColumns,
        sortColumn: resource.defaultSort,
        sortDirection: resource.defaultOrder,
        limit,
        offset: 0,
      });

      return {
        resource: resource.key,
        label: resource.label,
        total,
        hits: items.map((row) => toHit(resource.key, resource.label, row)),
      };
    }),
  );

  const populated = groups.filter((group) => group.total > 0);
  return {
    query: trimmed,
    total: populated.reduce((sum, group) => sum + group.total, 0),
    groups: populated,
  };
}

function toHit(resource: string, label: string, row: Record<string, unknown>): SearchHit {
  const title = firstString(row, ['title', 'name', 'word']) ?? '(untitled)';
  const excerpt = firstString(row, ['excerpt', 'summary', 'english_meaning', 'headline', 'description']);

  return {
    resource,
    label,
    id: String(row['id'] ?? ''),
    slug: typeof row['slug'] === 'string' ? row['slug'] : null,
    title,
    excerpt: excerpt ? truncate(excerpt, 200) : null,
    updatedAt: typeof row['updated_at'] === 'string' ? row['updated_at'] : null,
  };
}

function firstString(row: Record<string, unknown>, keys: string[]): string | null {
  for (const key of keys) {
    const value = row[key];
    if (typeof value === 'string' && value.trim() !== '') return value;
  }
  return null;
}

function truncate(value: string, max: number): string {
  return value.length <= max ? value : `${value.slice(0, max - 1).trimEnd()}…`;
}
