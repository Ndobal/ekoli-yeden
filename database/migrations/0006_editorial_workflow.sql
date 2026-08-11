-- ---------------------------------------------------------------------------
-- EKOLI YEDEN DIGITAL HOME — Migration 0006
-- The editorial workflow: attribution, sources, versions and contributors.
--
-- Module 1 gave every content table a `status` column. This migration gives the
-- workflow the people and the paper trail that make it meaningful:
--
--   who wrote it, who edited it, who reviewed it, who published it,
--   what it said before, where the claim came from,
--   and which community member supplied the material.
--
-- That last point is the one that matters most for an archive. An article can
-- be rewritten many times; the person who walked to the Preservation Team with
-- a photograph from 1974 must still be credited afterwards. Contributor
-- attribution therefore lives in its own table, keyed to the record, and is
-- never touched by an edit to the article body.
-- ---------------------------------------------------------------------------

-- --------------------------------------------------------------------------
-- Editorial columns on every content table.
--
-- `published_at_workflow` is deliberately distinct from the `published_at`
-- that already exists on `news`: one is the editorial act of publishing, the
-- other is the date the news item itself states. Collapsing them would let an
-- editor's click silently rewrite a stated publication date.
-- --------------------------------------------------------------------------

-- pages
ALTER TABLE pages ADD COLUMN author_id TEXT REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE pages ADD COLUMN editor_id TEXT REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE pages ADD COLUMN reviewer_id TEXT REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE pages ADD COLUMN published_by TEXT REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE pages ADD COLUMN submitted_at TEXT;
ALTER TABLE pages ADD COLUMN published_at_workflow TEXT;
ALTER TABLE pages ADD COLUMN review_notes TEXT;

-- history_entries
ALTER TABLE history_entries ADD COLUMN author_id TEXT REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE history_entries ADD COLUMN editor_id TEXT REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE history_entries ADD COLUMN reviewer_id TEXT REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE history_entries ADD COLUMN published_by TEXT REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE history_entries ADD COLUMN submitted_at TEXT;
ALTER TABLE history_entries ADD COLUMN published_at_workflow TEXT;
ALTER TABLE history_entries ADD COLUMN review_notes TEXT;
-- Marks material drawn from secondary web sources and not yet checked by the
-- Preservation Team. Rendered on the page as "Initial Research Edition".
ALTER TABLE history_entries ADD COLUMN research_edition INTEGER NOT NULL DEFAULT 0
  CHECK (research_edition IN (0, 1));

-- leaders
ALTER TABLE leaders ADD COLUMN author_id TEXT REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE leaders ADD COLUMN editor_id TEXT REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE leaders ADD COLUMN reviewer_id TEXT REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE leaders ADD COLUMN published_by TEXT REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE leaders ADD COLUMN submitted_at TEXT;
ALTER TABLE leaders ADD COLUMN published_at_workflow TEXT;
ALTER TABLE leaders ADD COLUMN review_notes TEXT;

-- people
ALTER TABLE people ADD COLUMN author_id TEXT REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE people ADD COLUMN editor_id TEXT REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE people ADD COLUMN reviewer_id TEXT REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE people ADD COLUMN published_by TEXT REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE people ADD COLUMN submitted_at TEXT;
ALTER TABLE people ADD COLUMN published_at_workflow TEXT;
ALTER TABLE people ADD COLUMN review_notes TEXT;

-- news
ALTER TABLE news ADD COLUMN author_id TEXT REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE news ADD COLUMN editor_id TEXT REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE news ADD COLUMN reviewer_id TEXT REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE news ADD COLUMN published_by TEXT REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE news ADD COLUMN submitted_at TEXT;
ALTER TABLE news ADD COLUMN published_at_workflow TEXT;
ALTER TABLE news ADD COLUMN review_notes TEXT;

-- events
ALTER TABLE events ADD COLUMN author_id TEXT REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE events ADD COLUMN editor_id TEXT REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE events ADD COLUMN reviewer_id TEXT REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE events ADD COLUMN published_by TEXT REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE events ADD COLUMN submitted_at TEXT;
ALTER TABLE events ADD COLUMN published_at_workflow TEXT;
ALTER TABLE events ADD COLUMN review_notes TEXT;

-- festivals
ALTER TABLE festivals ADD COLUMN author_id TEXT REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE festivals ADD COLUMN editor_id TEXT REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE festivals ADD COLUMN reviewer_id TEXT REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE festivals ADD COLUMN published_by TEXT REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE festivals ADD COLUMN submitted_at TEXT;
ALTER TABLE festivals ADD COLUMN published_at_workflow TEXT;
ALTER TABLE festivals ADD COLUMN review_notes TEXT;

-- language_categories
ALTER TABLE language_categories ADD COLUMN author_id TEXT REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE language_categories ADD COLUMN editor_id TEXT REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE language_categories ADD COLUMN reviewer_id TEXT REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE language_categories ADD COLUMN published_by TEXT REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE language_categories ADD COLUMN submitted_at TEXT;
ALTER TABLE language_categories ADD COLUMN published_at_workflow TEXT;
ALTER TABLE language_categories ADD COLUMN review_notes TEXT;

-- language_words
ALTER TABLE language_words ADD COLUMN author_id TEXT REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE language_words ADD COLUMN editor_id TEXT REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE language_words ADD COLUMN reviewer_id TEXT REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE language_words ADD COLUMN published_by TEXT REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE language_words ADD COLUMN submitted_at TEXT;
ALTER TABLE language_words ADD COLUMN published_at_workflow TEXT;
ALTER TABLE language_words ADD COLUMN review_notes TEXT;

-- galleries
ALTER TABLE galleries ADD COLUMN author_id TEXT REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE galleries ADD COLUMN editor_id TEXT REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE galleries ADD COLUMN reviewer_id TEXT REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE galleries ADD COLUMN published_by TEXT REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE galleries ADD COLUMN submitted_at TEXT;
ALTER TABLE galleries ADD COLUMN published_at_workflow TEXT;
ALTER TABLE galleries ADD COLUMN review_notes TEXT;

-- videos
ALTER TABLE videos ADD COLUMN author_id TEXT REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE videos ADD COLUMN editor_id TEXT REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE videos ADD COLUMN reviewer_id TEXT REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE videos ADD COLUMN published_by TEXT REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE videos ADD COLUMN submitted_at TEXT;
ALTER TABLE videos ADD COLUMN published_at_workflow TEXT;
ALTER TABLE videos ADD COLUMN review_notes TEXT;

-- businesses
ALTER TABLE businesses ADD COLUMN author_id TEXT REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE businesses ADD COLUMN editor_id TEXT REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE businesses ADD COLUMN reviewer_id TEXT REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE businesses ADD COLUMN published_by TEXT REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE businesses ADD COLUMN submitted_at TEXT;
ALTER TABLE businesses ADD COLUMN published_at_workflow TEXT;
ALTER TABLE businesses ADD COLUMN review_notes TEXT;

-- organizations
ALTER TABLE organizations ADD COLUMN author_id TEXT REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE organizations ADD COLUMN editor_id TEXT REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE organizations ADD COLUMN reviewer_id TEXT REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE organizations ADD COLUMN published_by TEXT REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE organizations ADD COLUMN submitted_at TEXT;
ALTER TABLE organizations ADD COLUMN published_at_workflow TEXT;
ALTER TABLE organizations ADD COLUMN review_notes TEXT;

-- community_projects
ALTER TABLE community_projects ADD COLUMN author_id TEXT REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE community_projects ADD COLUMN editor_id TEXT REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE community_projects ADD COLUMN reviewer_id TEXT REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE community_projects ADD COLUMN published_by TEXT REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE community_projects ADD COLUMN submitted_at TEXT;
ALTER TABLE community_projects ADD COLUMN published_at_workflow TEXT;
ALTER TABLE community_projects ADD COLUMN review_notes TEXT;

-- --------------------------------------------------------------------------
-- content_items
--
-- The generic article store. Culture articles live here, and any future
-- content type that is "a titled article with a body" can too, without needing
-- its own table. `content_type` is the discriminator.
-- --------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS content_items (
  id                     TEXT PRIMARY KEY,
  content_type           TEXT NOT NULL,
  slug                   TEXT NOT NULL,
  title                  TEXT NOT NULL,
  subtitle               TEXT,
  excerpt                TEXT,
  body                   TEXT,
  category               TEXT,
  cover_media_id         TEXT REFERENCES media_assets (id) ON DELETE SET NULL,
  seo_title              TEXT,
  seo_description        TEXT,
  seo_image_media_id     TEXT REFERENCES media_assets (id) ON DELETE SET NULL,
  sort_order             INTEGER NOT NULL DEFAULT 0,
  verification_status    TEXT NOT NULL DEFAULT 'unverified'
                           CHECK (verification_status IN ('unverified', 'in_review', 'verified', 'disputed')),
  research_edition       INTEGER NOT NULL DEFAULT 0 CHECK (research_edition IN (0, 1)),
  author_id              TEXT REFERENCES users (id) ON DELETE SET NULL,
  editor_id              TEXT REFERENCES users (id) ON DELETE SET NULL,
  reviewer_id            TEXT REFERENCES users (id) ON DELETE SET NULL,
  published_by           TEXT REFERENCES users (id) ON DELETE SET NULL,
  submitted_at           TEXT,
  published_at_workflow  TEXT,
  review_notes           TEXT,
  status                 TEXT NOT NULL DEFAULT 'draft'
                           CHECK (status IN ('draft', 'pending_review', 'approved', 'published', 'archived', 'rejected')),
  created_at             TEXT NOT NULL,
  updated_at             TEXT NOT NULL,
  UNIQUE (content_type, slug)
);

CREATE INDEX IF NOT EXISTS idx_content_items_type ON content_items (content_type, status, sort_order);
CREATE INDEX IF NOT EXISTS idx_content_items_slug ON content_items (slug);
CREATE INDEX IF NOT EXISTS idx_content_items_category ON content_items (category);

-- --------------------------------------------------------------------------
-- sources
--
-- A citation, held once and reusable across many records. The history of a
-- community is argued from evidence; this is where the evidence is named.
-- --------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS sources (
  id                TEXT PRIMARY KEY,
  title             TEXT NOT NULL,
  author            TEXT,
  url               TEXT,
  publication       TEXT,
  publisher         TEXT,
  publication_date  TEXT,
  accessed_date     TEXT,
  -- 'web', 'book', 'journal', 'oral_interview', 'archival_document',
  -- 'photograph', 'government_record', 'other'
  source_type       TEXT NOT NULL DEFAULT 'web',
  -- How much weight the archive gives this source. A secondary blog post and
  -- an interview with an elder are both useful and are not the same thing.
  reliability       TEXT NOT NULL DEFAULT 'unassessed'
                      CHECK (reliability IN ('unassessed', 'primary', 'secondary', 'tertiary', 'contested')),
  citation_text     TEXT,
  notes             TEXT,
  created_by        TEXT REFERENCES users (id) ON DELETE SET NULL,
  created_at        TEXT NOT NULL,
  updated_at        TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_sources_type ON sources (source_type);

-- --------------------------------------------------------------------------
-- content_sources — which sources support which record.
--
-- Polymorphic by (resource_type, resource_id) so that a citation can be
-- attached to a history entry, a leader profile, a language word or a
-- photograph without a join table per content type.
-- --------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS content_sources (
  id             TEXT PRIMARY KEY,
  resource_type  TEXT NOT NULL,
  resource_id    TEXT NOT NULL,
  source_id      TEXT NOT NULL REFERENCES sources (id) ON DELETE CASCADE,
  -- What this source is being cited for, e.g. "founding dates".
  supports       TEXT,
  page_reference TEXT,
  sort_order     INTEGER NOT NULL DEFAULT 0,
  created_at     TEXT NOT NULL,
  UNIQUE (resource_type, resource_id, source_id)
);

CREATE INDEX IF NOT EXISTS idx_content_sources_resource
  ON content_sources (resource_type, resource_id);

-- --------------------------------------------------------------------------
-- content_contributors — who supplied the material.
--
-- Kept separate from the content row on purpose. An article may be rewritten
-- many times by many editors; the person who supplied the 1974 photograph must
-- still be credited afterwards. Nothing in the editorial flow writes to this
-- table, so an edit cannot erase an acknowledgement.
-- --------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS content_contributors (
  id                 TEXT PRIMARY KEY,
  resource_type      TEXT NOT NULL,
  resource_id        TEXT NOT NULL,
  -- The account, where the contributor had one. Many will not: an elder's
  -- material may be carried in by a relative, and the credit still belongs to
  -- the elder, so the name is stored as text as well.
  user_id            TEXT REFERENCES users (id) ON DELETE SET NULL,
  contributor_name   TEXT NOT NULL,
  contributor_type   TEXT NOT NULL DEFAULT 'individual'
                       CHECK (contributor_type IN ('individual', 'family', 'organization',
                              'preservation_team', 'archive', 'photographer', 'interviewee', 'other')),
  -- How the credit should read on the page, e.g. "Photo contributed by".
  attribution_prefix TEXT NOT NULL DEFAULT 'Contributed by',
  submission_id      TEXT REFERENCES submissions (id) ON DELETE SET NULL,
  submitted_at       TEXT,
  approved_at        TEXT,
  approved_by        TEXT REFERENCES users (id) ON DELETE SET NULL,
  -- What the contributor permitted, recorded at the time they gave it.
  usage_permission   TEXT NOT NULL DEFAULT 'unspecified'
                       CHECK (usage_permission IN ('unspecified', 'archive_only', 'public_display',
                              'public_display_with_credit', 'unrestricted')),
  copyright_holder   TEXT,
  copyright_notes    TEXT,
  is_public          INTEGER NOT NULL DEFAULT 1 CHECK (is_public IN (0, 1)),
  sort_order         INTEGER NOT NULL DEFAULT 0,
  created_at         TEXT NOT NULL,
  updated_at         TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_content_contributors_resource
  ON content_contributors (resource_type, resource_id);
CREATE INDEX IF NOT EXISTS idx_content_contributors_user
  ON content_contributors (user_id);

-- --------------------------------------------------------------------------
-- content_versions — the archive's own memory of itself.
--
-- Every editorial change writes a snapshot here before the change is applied.
-- Versions are never deleted. If somebody rewrites "Ekoli was founded…", the
-- previous wording remains recoverable, which is the whole point: an archive
-- that can be silently rewritten is not an archive.
-- --------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS content_versions (
  id              TEXT PRIMARY KEY,
  resource_type   TEXT NOT NULL,
  resource_id     TEXT NOT NULL,
  version_number  INTEGER NOT NULL,
  -- Full JSON snapshot of the row as it was before this change.
  snapshot        TEXT NOT NULL,
  -- JSON map of changed column -> {from, to}, so a diff needs no computation.
  changed_fields  TEXT,
  change_summary  TEXT,
  status_at_time  TEXT,
  changed_by      TEXT REFERENCES users (id) ON DELETE SET NULL,
  changed_by_name TEXT,
  created_at      TEXT NOT NULL,
  UNIQUE (resource_type, resource_id, version_number)
);

CREATE INDEX IF NOT EXISTS idx_content_versions_resource
  ON content_versions (resource_type, resource_id, version_number DESC);
