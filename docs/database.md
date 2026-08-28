# Database

The D1 schema, and the reasoning behind it.

Migrations live in `database/migrations/` and are applied in order. **Never edit
a migration that has been applied** — add a new one. The `migrations_dir` in
`worker/wrangler.jsonc` points here, so the schema is versioned independently of
the API code.

```bash
npx wrangler d1 migrations apply ekoli-yeden-db --local
npx wrangler d1 migrations apply ekoli-yeden-db --remote --env production
```

## Conventions

- **TEXT primary keys**, generated in the Worker. Stable across environments and
  they do not leak row counts.
- **ISO-8601 UTC timestamps** as TEXT. SQLite has no date type.
- **INTEGER 0/1 booleans** with a CHECK constraint. SQLite has no boolean.
- **`status`** on every content table, with the same six-value CHECK. The
  constraint is repeated per table rather than centralised so a bad write fails
  at the database, not only in application code.

## The two status vocabularies

They are separate because they answer different questions.

**`status`** — where an entry is in the editorial process.

```
draft ──► pending_review ──► approved ──► published
             │                              │
             └──► rejected                   └──► archived
```

Only `published` is ever returned to an anonymous visitor.

**`verification_status`** — whether the community has confirmed the claim.

`unverified` → `in_review` → `verified`, or `disputed`.

Default `unverified`, never silently upgraded. An entry can be published and
still unverified — that is the honest state for material the archive holds but
has not yet confirmed, and the page says so.

---

## Migration 0001 — identity and settings

| Table | Purpose |
|---|---|
| `users` | Accounts. PBKDF2 hash and per-user salt; both null for an account that has not set a password. `preservation_team_position` records what a volunteer *does*; permissions come from roles. |
| `roles` | `permissions` is a JSON array. Super Admin holds `["*"]`. `is_system` marks roles that must not be deleted. |
| `user_roles` | Join table, unique on (user, role). |
| `sessions` | Only a **digest** of the refresh token, so a database snapshot cannot be replayed. `revoked_at` ends a session before its token would expire. `ip_hash` is salted — an IP address is personal data. |
| `site_settings` | Values an administrator changes without a deployment. Keys are created by migration so the client always knows what it may receive. `is_public` gates what `GET /api/settings` returns. |
| `audit_logs` | Append-only. No update or delete path exists in the application. |

---

## Migration 0002 — media and core content

`media_assets` is one row per object in R2. D1 holds the record; R2 holds the
bytes. `captured_at` and `location` stay null until somebody who knows supplies
them — an unlabelled photograph is still worth preserving, it is simply not yet
documented.

`pages`, `history_entries`, `leaders`, `people`, `news`.

Two columns on `history_entries` carry more weight than their size suggests:

- **`period_label`** is free text ("before 1900", "the colonial period") because
  much of what an elder can tell us has no exact date, and forcing one would
  invent precision that does not exist.
- **`source_reference`** exists so an entry can state where it came from. An
  archive that cannot answer that is not an archive.

`people.consent_reference` records that the person or their family agreed to be
listed. A living person's profile is personal data, not archive material.

---

## Migration 0003 — festivals, events, language

### `festivals`

Leboku is a **row, not a page**. Each year is its own record, unique on
(name, year), which is what makes `/leboku/2026` and `/leboku/2027` the same
code reading different rows — and what stops a festival page being overwritten
each year. `programme`, `sponsors`, `announcements` and `committee` are JSON
text because their shape differs year to year and the community should not need
a migration to change how a programme is laid out.

### `language_words`

**Every column here is filled in by a native speaker or a recognised Ekoli
language scholar.** The platform never generates, guesses or completes the
meaning of an Ekoli word. An entry with `english_meaning` null is displayed as
awaiting verification — which is the honest state for a word nobody has yet
confirmed.

`dialect_or_variation` exists because Ekoli-Yeden speech varies between families
and quarters, and recording the variation is part of preserving the language
accurately rather than flattening it.

### `language_audio`

A word may have several recordings — different speakers, different variations.
That is a feature of a language archive, not a duplicate to be removed. The
audio lives in R2 under `language/`.

---

## Migration 0004 — galleries, videos, directories

`galleries` and `gallery_items`. The descriptive columns on an item — who is
pictured, photographer, taken_at, location — are what turn a photograph into an
archive record. They stay null until somebody who was there tells us.

`videos` holds the YouTube catalogue record. `thumbnail_url` is optional; when
null the API derives it from the video id, so pages render without any YouTube
API call. **`transcript`** is what makes an oral-history recording searchable —
the difference between a video existing and a video being findable.

`businesses`, `organizations`, `community_projects`. Funding figures come from
the project committee's own records; the platform does not estimate them.

`submissions` — community contributions. A submission is a **proposal, never
content**. It enters `pending_review` and only a moderator moves it.
`reference_code` is a short human-quotable code (`EY-XXXXXX`) the contributor
uses to follow up.

---

## Migration 0005 — role seed

The nine platform roles with their permission arrays. Structure only: no
history, leader, person, language entry, festival or news record is seeded. Every
content table is intentionally empty.

---

## Migration 0006 — the editorial workflow

Adds to every content table: `author_id`, `editor_id`, `reviewer_id`,
`published_by`, `submitted_at`, `published_at_workflow`, `review_notes`.

`published_at_workflow` is deliberately distinct from the `published_at` already
on `news`. One is the editorial act of publishing; the other is the date the
news item itself states. Collapsing them would let an editor's click silently
rewrite a stated publication date.

| Table | Purpose |
|---|---|
| `content_items` | The generic article store. Culture articles live here, discriminated by `content_type`; any future "titled article with a body" can too, without its own table. |
| `sources` | A citation, held once and reusable. `reliability` distinguishes a primary source from a community blog post from a contested one. |
| `content_sources` | Which sources support which record. Polymorphic on (resource_type, resource_id), so a citation attaches to a history entry, a leader profile or a photograph without a join table per type. |
| `content_contributors` | **Who supplied the material.** Kept separate from the content row on purpose — see below. |
| `content_versions` | The archive's memory of itself. Never deleted. |

### Why contributor attribution is its own table

An article may be rewritten many times by many editors. The person who walked to
the Preservation Team with a photograph from 1974 must still be credited
afterwards. Nothing in the editorial flow writes to `content_contributors`, so
an edit **cannot** erase an acknowledgement.

`contributor_name` is stored as text as well as `user_id`, because many
contributors will have no account — an elder's material is often carried in by a
relative, and the credit belongs to the elder.

`usage_permission` records what the contributor actually agreed to, at the time
they agreed to it.

---

## Migration 0007 — the CMS

### `content_strings`

Every heading, paragraph, button label, caption, empty state, notice and SEO
field on the public site, keyed by a dotted path.

The important pair of columns is `value` (live) and `draft_value` (the editor's
work in progress). Editing writes only the draft, so a half-finished sentence
never reaches a visitor. Publishing copies the draft across and clears it.

`label` and `help_text` are shown to the editor in the CMS so they know what
they are changing and where it appears. `is_locked` reserves the small set of
strings that must not be edited.

### `hero_slides`

Exactly five, enforced by CHECK. `image_media_id` is null until the Media Team
attaches an approved photograph — the carousel draws a branded panel rather than
a broken image, so the homepage is presentable on day one and improves as real
photographs arrive.

### `navigation_items`

Menu labels, destinations and order, editable without a deployment.

---

## Migration 0008 — editorial roles

Four positions that split writing from publishing:

| Role | Permissions |
|---|---|
| `editorial_writer` | `content.create`, `content.edit`, `content.read`, `content.submit`, `media.metadata.edit`, `sources.read` |
| `editorial_editor` | the above plus `pages.edit`, `navigation.edit`, `homepage.edit`, `seo.edit`, `sources.manage` |
| `editorial_reviewer` | `content.read`, `content.review`, `submissions:read`, `submissions:review` |
| `editorial_publisher` | `content.read`, `content.publish`, `content.unpublish` |

**What is absent is the point.** None of them holds `users.manage`,
`roles.manage`, `permissions.manage`, `security.manage`, `settings.manage`,
`audit.view` or `content.delete`. The Worker denies by default, so a permission
that is not granted does not exist. Nobody gets `content.publish` merely by
being on the Editorial Team.

---

## Migration 0009 — content seed

Navigation, five hero slides, 68 content strings, three sources, and the history
article.

### The Initial Research Edition

The only content record seeded with substance, and it is handled carefully.

It is compiled from two secondary web sources, with **every claim attributed
inline**. It carries `research_edition = 1` and
`verification_status = 'unverified'`, which makes the page render it beneath a
notice stating it is a starting point for research and not settled community
history.

One of its sources is recorded with `reliability = 'contested'` because, at the
time it was consulted, the Wikipedia article carried Wikipedia's own banner
saying it cites no sources at all. That fact is written into the source's notes
rather than quietly omitted.

The article also flags an internal inconsistency in the blog source — its
description of migration phases does not sit comfortably with the dates it gives
— left as found rather than tidied away, because resolving it is the
Preservation Team's job and it illustrates why one web source is not sufficient.

The article ends with a section headed "What is missing", which is honest about
how little of Ekoli-Yeden's own account is present.


---

## Migrations 0010–0013 — page content, password reset, deputy admin

`0010` fills the section pages with real text. `0011` generalises Leboku into
Festivals and adds age grades, cultural groups and cultural music. `0012` adds
single-use password reset tokens, stored as digests. `0013` adds the Deputy
Administrator role and `submission_uploads`.

---

## Migration 0014 — a gallery for every festival

`galleries.festival_id` and `festivals.gallery_id` both existed and neither was
ever filled in, so a photograph taken at the 2026 festival belonged to no year
at all. After this every festival owns exactly one album, pointed at from both
directions and backfilled for the editions that already exist.

| Column | Why |
|---|---|
| `galleries.is_festival_gallery` | A festival may end up with several albums — "the wrestling", "the procession" — but exactly one is the album its page shows and new photographs default into. Flagged rather than inferred from creation order, which would silently pick the wrong one the first time somebody deleted and recreated an album. |
| `gallery_items.contributed_by` | A photograph from the public form and one a volunteer uploads are both gallery items, but only one has somebody outside the team to thank. |
| `gallery_items.submission_upload_id` | The link back to what was actually sent, so "is this really the photograph she gave us?" stays answerable. |

The album inherits the festival's status, so preparing next year's page cannot
put an empty album on the public site.

Because a festival album is an ordinary `galleries` row, its photographs appear
in the main Gallery section and in `GET /api/photographs` without being filed
twice.

---

## Migration 0015 — a real dictionary

`language_words` had one meaning, one part of speech and one example sentence
per row. That is a glossary. Four additions make it a dictionary:

| Table | Holds |
|---|---|
| `language_senses` | One row per distinct meaning, numbered, each with its own part of speech and definition. |
| `language_examples` | `sentence_ekoli`, `sentence_english` **and `pronunciation`** — plus `media_asset_id` for a recording of the whole sentence, which is worth more than all three text fields. |
| `language_variants` | Alternative forms with the quarter or family that says them. `variant_normalised` is searched alongside the headword, so looking up a variant finds the main entry. |
| `language_parts_of_speech` | A table rather than a CHECK constraint: Lokaa grammar is not English grammar, and the categories the community's language scholars want should not need a migration. Seeded with thirteen, including `ideophone`. |

On the headword itself: `parts_of_speech` (a JSON array — a word is often a noun
*and* a verb), `phonetic_respelling`, `ipa`, `tone_pattern`, `plural_form`,
`literal_translation`, `usage_notes`, `register`, `etymology`, `see_also`.

`word_normalised` is the headword lowercased and stripped of diacritics, so
somebody typing on a phone keyboard without tone marks still finds the word. It
is derived by the Worker on every write and is deliberately **not** a writable
column. `initial_letter` drives the A–Z index — stored rather than computed, so
the index is one indexed read instead of a scan.

The old columns are kept and backfilled rather than dropped: every existing
entry stays readable, and its meaning becomes sense 1.

`word_submissions` is a queue of its own. A word arrives with variants, parts of
speech, several meanings and a sentence, none of which fit "title" and
"description" — so it is held as structured JSON in the same shape the tables
above use, and promoting it is a copy rather than a re-typing.

---

## Migration 0016 — age grades that run themselves

An age grade was an article in `content_items` that only a Heritage Editor could
write. That is the wrong shape: the people who know what a grade has been doing
this year are its own members.

| Table | Holds |
|---|---|
| `age_grades` | The grade. A table of its own rather than another shelf in `content_items`, because rows that own other rows do not belong in a shared-discriminator table. |
| `age_grade_admins` | Who may speak for this grade. `lead` may appoint and remove; `admin` may write. |
| `age_grade_members` | The roster. `user_id` is nullable and usually null — most members will never hold an account here, and a roster that lists only the ones who do is not a roster. |
| `age_grade_posts` | The grade's own news, published under the grade's name. |

The article already written is migrated across **keeping its id**, because
`content_sources` and `content_contributors` reference it by
`('age_grades', id)`. Changing the id would orphan every citation attached to it.
The original row is marked `age_grades_migrated` rather than deleted — a
migration that destroys rows is one nobody can safely re-run.

### The authorisation this introduces

One new axis, deliberately the narrowest in the platform: **administers this
particular age grade**. It is one row in `age_grade_admins`, it is not a
platform role, and it grants nothing anywhere else. A person who administers
Ovat cannot touch Obam, cannot reach the media library, cannot see a user list.

What the grade controls: its description, its roster, its posts, its
photographs. What it does not: whether its page is published at all, and whether
the archive marks it verified. `AgeGradeRepository.updateOwnFields` cannot write
`status` or `verification_status`, and there is no route through which it can.

Three settings govern how much autonomy the grades have —
`age_grades_self_registration`, `age_grade_posts_require_review` (off by
default: an update that waits a week for an editor is an update that stops being
written) and `age_grade_members_require_review` (on by default, because a living
person's name is personal data).

---

## Useful queries

```bash
# What tables exist
npx wrangler d1 execute ekoli-yeden-db --local \
  --command "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name;"

# Roles and their permission counts
npx wrangler d1 execute ekoli-yeden-db --remote --env production \
  --command "SELECT slug, json_array_length(permissions) AS permissions FROM roles ORDER BY slug;"

# Anything waiting for review
npx wrangler d1 execute ekoli-yeden-db --remote --env production \
  --command "SELECT 'history' AS type, COUNT(*) FROM history_entries WHERE status='pending_review'
             UNION ALL SELECT 'submissions', COUNT(*) FROM submissions WHERE status='pending_review';"

# The edit history of one record
npx wrangler d1 execute ekoli-yeden-db --remote --env production \
  --command "SELECT version_number, change_summary, changed_by_name, created_at
             FROM content_versions WHERE resource_id='hist_initial_research_edition'
             ORDER BY version_number DESC;"
```

## Backups

```bash
npx wrangler d1 export ekoli-yeden-db --remote --env production --output backup.sql
```

Worth scheduling once the archive holds material that cannot be recovered from
anywhere else — which is, after all, the entire point of it.
