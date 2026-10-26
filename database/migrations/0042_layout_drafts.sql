-- Keep proposed carousel/menu changes separate from the live records.
-- Retain the row after publication/discard so its revision never resets.
CREATE TABLE layout_drafts (
  kind TEXT NOT NULL CHECK (kind IN ('hero', 'navigation')),
  resource_id TEXT NOT NULL,
  payload TEXT,
  state TEXT CHECK (state IN ('draft', 'pending_review', 'approved', 'rejected')),
  revision INTEGER NOT NULL DEFAULT 0 CHECK (revision >= 0),
  updated_by TEXT REFERENCES users(id) ON DELETE SET NULL,
  reviewed_by TEXT REFERENCES users(id) ON DELETE SET NULL,
  updated_at TEXT NOT NULL,
  PRIMARY KEY (kind, resource_id)
);
