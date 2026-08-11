# Architecture

How the Ekoli Yeden Digital Home is put together, and why each decision was
made. Written for whoever maintains this after the people who built it.

---

## 1. The shape of the system

```
                     Visitor's browser
                            │
                            ▼
              ┌─────────────────────────────┐
              │   Cloudflare Pages          │   ekoli.pages.dev
              │   Flutter Web bundle        │
              └─────────────┬───────────────┘
                            │  HTTPS · JSON · bearer token
                            ▼
              ┌─────────────────────────────┐
              │   Cloudflare Worker         │   ekoli-yeden-api.ndovera.workers.dev
              │   the entire backend        │
              └──┬───────────┬───────────┬──┘
                 ▼           ▼           ▼
                D1          R2       YouTube
             records      files      videos
```

### Why the Worker is the only thing that touches data

The Flutter bundle is downloaded, in full, by every visitor. Anything compiled
into it — an API key, a bucket name, a database id — is public the moment the
first person loads the page. There is no such thing as a secret in a browser
application.

So the client holds none. It knows one URL and one bearer token. Every rule
about who may read or write what is decided by the Worker, on the server, on
every request. This is not a layer of indirection for its own sake; it is the
only arrangement in which the archive's permissions mean anything.

It also means the same API will serve an Android app, an iOS app, or anything
else the community builds later, without the authorisation model being
rewritten.

---

## 2. The Worker

```
src/
├── index.ts          entry: CORS preflight, authentication, routing, errors
├── routes/           what exists, and what permission it needs
├── controllers/      request in, response out
├── services/         the rules
├── repositories/     the only code that writes SQL
├── middleware/       router, CORS, authorisation, rate limiting, errors
├── types/            bindings and row shapes
└── utils/            crypto, validation, responses, R2 and YouTube helpers
```

Requests flow one way: `route → middleware → controller → service → repository
→ D1`. A controller never writes SQL; a repository never decides a permission.

### Authentication runs once, globally

`index.ts` resolves the bearer token before routing, so `context.user` is always
populated — `null` for anonymous traffic, which is not an error, because most of
this archive is meant to be read by anyone.

Authorisation then happens per route. Separating the two means no handler can
forget to authenticate, and every handler must state what it authorises.

### The content registry

`services/content-registry.ts` is the single description of every content type:

```ts
history: {
  key: 'history',
  table: 'history_entries',
  writableColumns: [...],     // anything else is dropped on write
  searchableColumns: [...],   // what site search looks at
  sortableColumns: [...],     // what ?sort= accepts
  managedBy: [CONTENT_ADMIN, HERITAGE_EDITOR],
}
```

Public routes, admin routes, permission strings, validation and search are all
generated from it. Fourteen content types share one controller, one service and
one repository.

The payoff is concrete: adding a content type in a future module is a migration
plus a registry entry. No new route file to forget a permission on, no new
repository to get a status filter wrong in.

`fixedFilters` lets several resources share a table — `culture` lives in
`content_items` discriminated by `content_type`. The filter is applied on every
read and stamped on every write, so one resource can never see or overwrite
another's rows even by id.

### Authorisation

`services/permissions.ts` holds the single decision function. Two vocabularies
work together:

- **Resource-scoped** — `history:create`, `videos:publish`. Fine-grained. A
  Heritage Editor gets history, leadership and people, and nothing in the
  dictionary.
- **Capability** — `content.create`, `content.publish`. Broad. An Editorial
  Writer can draft any content type.

A capability satisfies the matching resource-scoped permission **only for
registered content resources**. That guard is load-bearing and was added after a
test caught the bug it prevents: without it, `content.read` satisfied
`users:read` and `audit:read` purely because they share the word "read", which
handed every Editorial Team member the user list and the audit trail. The
permission vocabulary is not a namespace to pattern-match across.

Nothing grants `users.*`, `roles.*`, `security.*`, `system.*` or `audit.view` by
implication. They are reachable only by holding them explicitly or by the Super
Admin wildcard.

### Status transitions are permissioned individually

The permission for a status change depends on where the content is going, not
merely that it is moving:

| Target | Permission |
|---|---|
| `draft` | `<resource>:update` |
| `pending_review` | `<resource>:submit` |
| `approved` / `rejected` | `<resource>:review` |
| `published` / `archived` | `<resource>:publish` |

This is checked inside the handler rather than in route middleware, because the
route cannot know the target status until the body has been read. It is what
lets the community grant someone the right to write without the right to
publish.

---

## 3. The CMS

The requirement: *if a visitor can read it, the Editorial Team can change it
without touching code.*

`content_strings` holds every heading, paragraph, button label, caption, empty
state and notice on the public site, keyed by a dotted path
(`home.hero.slide1.title`). `GET /api/cms/bundle` returns all published strings,
the hero carousel and the navigation in one request — one round trip on first
paint rather than three.

### Drafts never reach visitors

Each row has both `value` (live) and `draft_value` (the editor's work). Editing
writes only the draft. Publishing copies it across. A half-finished sentence can
never appear on the live archive, and an editor can save as often as they like
without consequence.

### Every call site supplies a fallback

```dart
CmsText('home.s1.title', fallback: 'Discover Ekoli-Yeden')
```

The database value wins when it exists; the fallback is used when it does not.
One rule, three benefits: a fresh checkout renders correctly before any
migration has run; a visitor arriving mid-deployment sees the archive rather
than a screen of blank labels; and a new string can be added in code and seeded
later without a broken release in between.

`fallback` is a required parameter, not an optional one — it forces whoever adds
a key to decide what the page says when it is missing.

**Deliberately excluded:** security and system-generated messages. A sign-in
failure or a permission denial must say what it means and must not be editable
into something misleading.

---

## 4. The Flutter client

```
lib/
├── core/          config, routing, theme, shared widgets, utils
├── models/        typed views over the API's JSON
├── services/      the API client, auth, token storage
├── repositories/  one per domain — the only callers of the API client
├── features/      one directory per public section
└── admin/         Super Admin screens
```

A screen calls a repository; a repository calls the API client; nothing else
does. One `ApiClient` is shared, so a token refresh triggered by one screen
benefits every other.

### Two behaviours worth knowing

**Transparent token refresh.** A 401 triggers one refresh-and-retry. An editor
part-way through writing a history entry should not lose it because a token
expired mid-request. Concurrent callers share one refresh rather than each
spending a token.

**Everything tolerates missing data.** The archive is full of deliberately
incomplete records — a photograph with no date, a word with no confirmed
meaning. Every JSON reader and every formatter takes a fallback and never
renders "null".

### Models are loose on purpose

`ContentRecord` carries the common spine — id, slug, title, status, timestamps —
and exposes the rest through `raw`. Fourteen near-identical Dart classes would
be a maintenance cost with no benefit, and a column added in a future module can
be displayed without a class change first.

---

## 5. Data

### D1

Migrations in `database/migrations/`, applied in order, never edited once
applied. TEXT primary keys generated in the Worker: stable across environments,
and they do not leak row counts.

Nine migrations: identity and settings, media and content, festivals and
language, galleries and directories, role seed, editorial workflow, the CMS,
editorial roles, and the content seed.

### R2

Files only: images, audio, documents, avatars, heritage scans, language
recordings, Leboku material. Keys are `<folder>/<year>/<month>/<random>.<ext>` —
browsable by a volunteer, and shallow as the archive grows.

`GET /api/media/file/*` is the only route that returns object bytes, and it
resolves the D1 record first. An unpublished heritage scan is not reachable by
guessing its key, and a miss and a permission failure return the same message so
the URL space cannot be probed.

### YouTube

Videos are never uploaded to R2. D1 holds the catalogue record; the thumbnail is
derived from the video id rather than fetched, so pages render with no YouTube
API call and no key. A stored `thumbnail_url` overrides it when the Media Team
has chosen a specific still.

---

## 6. The archive's own integrity

Three tables carry the weight of the claim that this is an archive rather than a
website.

**`content_versions`** — every editorial change snapshots the record before
applying it. Never deleted. If somebody rewrites "Ekoli was founded…", the
previous wording remains recoverable.

**`content_sources`** — citations attach to any record polymorphically. A
history page can show where each claim came from, what the source is cited for,
and whether the archive considers it contested.

**`content_contributors`** — who supplied the material, stored separately from
the article. Nothing in the editorial flow writes to this table, which is
exactly why an acknowledgement survives every later edit. An article may be
rewritten many times; the person who walked in with a photograph from 1974 is
still credited.

---

## 7. SEO

The archive exists so that when somebody searches for Ekoli-Yeden they find a
careful record rather than scattered social media posts. Every page therefore
has a real URL and declares its own metadata through `SeoMetadata` — title,
description, canonical URL, Open Graph and Twitter tags.

Flutter Web renders into a canvas and cannot rewrite `<head>` per route, so
`SeoMetadata.toMetaTags()` describes what each page *means* in a form a
prerendering step can consume. Adding prerendering later requires no change to
any page component. `web/_redirects` provides the SPA fallback that makes the
clean URLs resolve on Pages.

---

## 8. Responsive and accessible

Mobile-first, and not as a slogan: most visitors will arrive from a WhatsApp
link on a phone, often on a slow connection. Breakpoints at 600 / 905 / 1240 /
1600. Wide content — tables, the navigation strip — scrolls inside its own
container so the page body never scrolls horizontally.

Fonts come from the platform stack rather than a web-font download, because a
round trip is a real cost on a Nigerian mobile connection. Images show a
labelled placeholder rather than a broken-image icon. The hero carousel pauses
on hover and focus, stops permanently once the visitor operates it, and never
autoplays when the operating system asks for reduced motion.

---

## 9. Environments

| | Development | Staging | Production |
|---|---|---|---|
| API | `localhost:8787` | `ekoli-yeden-api-staging` | `ekoli-yeden-api` |
| D1 | local | `ekoli-yeden-db-staging` | `ekoli-yeden-db` |
| R2 | local | `ekoli-yeden-media-staging` | `ekoli-yeden-media` |
| Secrets | `.dev.vars` (git-ignored) | `wrangler secret put --env staging` | `wrangler secret put --env production` |

Staging resources are configured but not yet created; its `database_id` is a
placeholder until somebody runs `wrangler d1 create` for it.

---

## 10. Known limits

Honest notes for whoever picks this up next.

- **Rate limiting** is per-isolate, in memory. It stops casual scripted abuse of
  sign-in and the contribution form; it is not a distributed limiter. Cloudflare
  WAF does the real work at the edge. Promote it to a Durable Object if the
  community needs stricter guarantees.
- **Search** is a fan-out of `LIKE` queries — correct and cheap while the
  archive is small. Because the registry already declares each resource's
  searchable columns, moving to D1 FTS5 is a change to `search.service.ts`
  alone.
- **PBKDF2 at 100,000 iterations** is the Workers runtime's ceiling, not the
  ideal. Worth revisiting if the cap is raised. Changing it invalidates existing
  hashes and needs a re-hash-on-login migration.
- **Media uploads** are implemented end to end in the API but the contribution
  form currently collects a description rather than a file; the upload UI is the
  next piece of client work.
- **The video player** links out to YouTube rather than embedding. An honest
  link is better than a broken player.
- **Pages preview deployments** get a `<hash>.ekoli.pages.dev` origin, which is
  not in the CORS allow-list. Add specific preview origins when needed.
