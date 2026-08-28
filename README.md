<div align="center">

<img src="frontend/assets/images/branding/ekoli_yeden_logo.png" alt="Ekoli Yeden" width="150">

# EKOLI YEDEN DIGITAL HOME

**Preserving Our Past. Celebrating Our Present. Building Our Future.**

A permanent digital home and heritage archive for Ekoli-Yeden.

[Live site](https://ekoli.pages.dev) · [API](https://ekoli-yeden-api.ndovera.workers.dev/api/health)

</div>

---

## What this is

Most of what a community knows about itself lives in places that were never
built to last — personal phones, WhatsApp groups, family albums, and the
memories of elders. A photograph is lost when a phone breaks. A message
disappears. Knowledge that is never recorded goes with the person who held it.

This is the alternative: one permanent, searchable, verified place for the
history, language, culture, people, leadership and festivals of Ekoli-Yeden.

### The rule the whole system is built around

**Nothing is invented.**

No history, chief, leader, date, cultural claim, statistic or meaning of an
Ekoli word appears on this site because software produced it. Where the
community has not supplied something, the page says so plainly rather than
filling the space with a plausible guess. Material drawn from outside sources
is labelled with its provenance and marked unverified until the Preservation
Team has checked it.

That principle is enforced in the schema, not just in the interface: content
defaults to `draft`, verification defaults to `unverified`, and only
`published` records are reachable by an anonymous visitor.

---

## Architecture

```
              Flutter Web  ──►  Cloudflare Pages          ekoli.pages.dev
                    │
                    │  HTTPS · JSON · bearer token
                    ▼
            Cloudflare Worker (TypeScript)      ekoli-yeden-api.ndovera.workers.dev
                    │
        ┌───────────┼───────────┐
        ▼           ▼           ▼
       D1          R2        YouTube
    records      files       videos
```

The Worker is the whole backend and the only component that holds a D1 binding,
an R2 binding or a secret. The Flutter bundle is downloaded by every visitor, so
anything inside it is public by definition — which is why it contains no
Cloudflare credential of any kind and talks to nothing but this one API.

| Layer | Technology |
|---|---|
| Frontend | Flutter Web |
| Hosting | Cloudflare Pages |
| API | Cloudflare Workers (TypeScript) |
| Database | Cloudflare D1 |
| File storage | Cloudflare R2 |
| Video | YouTube |

Videos are never stored in R2. YouTube hosts them; D1 holds the catalogue
record. That keeps storage costs proportional to photographs and audio, and it
means videos the community has already published can be organised here without
being re-uploaded.

---

## Repository layout

```
ekoli-yeden/
├── frontend/          Flutter Web application
│   ├── lib/
│   │   ├── core/          config, routing, theme, shared widgets, utils
│   │   ├── models/        typed views over the API's JSON
│   │   ├── services/      API client, auth, token storage
│   │   ├── repositories/  one per domain — the only callers of the API client
│   │   ├── features/      one directory per public section
│   │   └── admin/         Super Admin screens
│   └── assets/images/branding/   the supplied logo
│
├── worker/            Cloudflare Workers API
│   └── src/
│       ├── routes/        route tables — public, auth, contribute, editorial, admin
│       ├── controllers/   request handling
│       ├── services/      business rules, permissions, the content registry
│       ├── repositories/  D1 access
│       ├── middleware/    router, CORS, authorisation, rate limiting, errors
│       ├── types/         bindings and row shapes
│       └── utils/         crypto, validation, responses, R2 helpers
│
├── database/migrations/   D1 schema, applied in order
└── docs/                  architecture, database, contribution guidelines
```

### Four ideas worth knowing before reading the code

**The content registry** (`worker/src/services/content-registry.ts`) describes
every content type in one place: its table, its writable columns, its
searchable fields, and who may manage it. Routes, permissions, validation and
search are all generated from it. Adding a content type is a migration plus a
registry entry — not a new controller, repository and route file.

**The CMS** (`content_strings` table) holds the website's text. Every heading,
paragraph, button label, empty state and notice a visitor can read is a row in
the database, editable by the Editorial Team without touching code. Each call
site in Dart supplies a fallback, so the site renders correctly before the
database is seeded and survives the API being briefly unreachable.

**A photograph belongs to a year.** Every festival edition owns exactly one
gallery, created with it. A picture from Leboku 2026 goes into that album and is
filed under 2026 for good — and because a festival album is an ordinary row in
`galleries`, the same picture also appears in the main Gallery section and in
the combined photograph stream. One upload, three places it can be found,
nothing copied.

**One narrow extra authority.** Everything protected in this platform is
decided by a permission on a role, with one deliberate exception: *administers
this particular age grade*, one row in `age_grade_admins`. It grants nothing
anywhere else — a person who administers Ovat cannot touch Obam, cannot reach
the media library, cannot see a user list. See `services/age-grade.service.ts`.

---

## Roles

Nine platform roles, plus four editorial positions. The distinction that
matters: **the Editorial Team is not the Super Admin.**

| Role | May do |
|---|---|
| Super Admin | Everything, including users, roles, security and audit |
| Content Administrator | All content; no user or security administration |
| Heritage Editor | History, leadership, people, culture |
| Language Editor | The dictionary, its recordings, and the words the community proposes |
| Media Manager | Photographs, galleries, the video archive |
| Leboku Manager | Festival editions, programmes, festival events |
| Moderator | Reviews community contributions |
| Contributor | Submits material for review |
| Public Visitor | Reads published content |

And one authority that is not a role at all: an **age grade administrator**,
appointed by their own grade, may write that grade's page and nothing else.

Editorial positions split writing from publishing, so a volunteer can be
trusted to draft without being able to make anything live:

**Writer** → drafts and submits · **Editor** → edits pages, navigation, homepage,
SEO, sources · **Reviewer** → approves or rejects · **Publisher** → makes
approved content live.

None of the editorial roles holds `users.manage`, `roles.manage`,
`security.manage`, `settings.manage`, `audit.view` or `content.delete`. Those
permissions are simply absent from their arrays, and the Worker denies by
default — a permission that is not granted does not exist.

---

## The editorial workflow

```
draft ──► pending_review ──► approved ──► published
             │                              │
             └──► rejected ──► (revise)      └──► archived
```

Only `published` is visible to a visitor. Each transition needs its own
permission — submitting, approving and publishing are three different
authorities — and each writes a version snapshot and an audit entry.

**Version history.** Every editorial change snapshots the record before it is
applied, into `content_versions`. Versions are never deleted. If somebody
rewrites a paragraph of the history page, the previous wording remains
recoverable. An archive that can be silently rewritten is not an archive.

**Contributor attribution.** Who supplied a photograph is stored in
`content_contributors`, keyed to the record — not in the article. Nothing in
the editorial flow writes to that table, which is exactly why an
acknowledgement survives every later edit to the article it belongs to.

**Sources.** Citations live in `sources` and attach to any record through
`content_sources`. A history page shows where each claim came from, and flags a
source the archive considers contested.

**What an age grade says about itself** is a third kind of statement, and the
site keeps it apart from the other two. A grade's own post is published under
the grade's name and labelled as the grade speaking for itself — useful, and
not the same as something the Preservation Team has checked. A grade cannot
publish its own page, and cannot mark itself verified: those columns are not
writable through the routes its administrators use.

---

## News

The section is a small newspaper with an archive underneath it. A story carries
a category, the date it *happened* (not the date it was written up), where, a
body built from typed blocks, any number of photographs each with its own
caption and its own credit, any number of YouTube videos, tags, and its sources.

Three decisions worth knowing:

**The body is structured blocks, not HTML.** The brief asked for a rich-text
editor and for server-side sanitisation. The usual way to do both — take HTML
and scrub it — is a denylist, and denylists lose. So a paragraph is
`{type, text}`, a heading carries a level, a link is a range with an address.
Validation is an allowlist over a shape. The Editorial Team never writes markup,
and there is no path by which anything they paste becomes script.

**Nothing scheduled is readable early.** The public queries require both
`status = 'published'` and a publication time that has passed. A cron every ten
minutes publishes what is due.

**The contributor cannot be edited out.** Who sent a story in lives on the
record, not in the article text, and the edit endpoint strips those fields from
the payload before writing. An editor rewording a headline cannot take somebody's
name off it, by accident or otherwise.

Social media stays the distribution channel. This is the permanent record —
which is why a story embeds the YouTube video the community already published
rather than asking anybody to upload it again.

---

## The dictionary

A word is not a row. `language_words` holds the headword; four tables hold what
a language actually does:

| | |
|---|---|
| `language_senses` | One row per distinct meaning, each with its own part of speech. Collapsing them into one field is what makes a second meaning unfindable. |
| `language_examples` | The sentence in the language, its English, **and how the Lokaa is pronounced**. All three matter to a learner, and the third most — it is the part written words preserve worst. |
| `language_variants` | How another quarter says it, an older form, a plural. Searched alongside the headword, so somebody who only knows their own family's form still finds the entry. |
| `language_audio` | Recordings of the headword. Several per word is a feature of a language archive, not a duplicate. |

A word can be several parts of speech at once — `parts_of_speech` is a list, not
a column. Search covers headwords, variants, meanings, definitions and example
sentences in one query, and matches a word typed without its tone marks.

Contributing a word has a form of its own (`/language/contribute`) rather than
sharing the general contribution form: an entry arrives with variants, parts of
speech, several meanings and a sentence, and none of that survives being
squeezed into "title" and "description". A language editor reviews something
that already reads like a dictionary entry and accepts it in one action.
Accepting creates a **draft, unverified** entry — "this is worth having" and
"this is what the word means" are different statements.

---

## Who somebody is, and what they may do

Two independent facts about every person, deliberately kept apart:

```
USER
 ├── relationship to Ekoli-Yeden   indigene · resident · married in · friend ·
 │                                 researcher · organisation · other
 └── platform role                 user · contributor · editorial · admin
```

They do not vary together. An indigene may be an ordinary user or the Super
Admin; a researcher from a university may be a contributor; a friend of the
community may run the media library. Folding them into one word — "member" —
forced every such person to be described as something they were not.

**The relationship grants nothing.** It is recorded, shown on a profile where
the person chose to show it, and it is what the Indigene Directory lists by.
Every permission decision reads `roles` and nothing else.

**Registering is joining.** There is no separate contributor account. There used
to be, and it could not contribute: the `contributor` role held no permissions,
and contributing requires a profile it never created. Everybody who registers is
a user of Ekoli-Yeden with the dashboard, the ability to send material to the
archive, and whatever role a Super Admin later assigns on top.

---

## The community, and the platform it runs on

The archive is one half of this. The other is the community using it, and those
share one Okoli account — the forums, the opportunities board and the directory
have no sign-in of their own.

| Section | What it is |
|---|---|
| **Yakoli membership** | One account, one profile, and privacy settings that default to off. An Editorial Team volunteer may have an account and never join; a member may join years after registering. |
| **The forums** | Three spaces. Two of them may contain minors, which decides most of the design: a members-only space is never readable anonymously, is kept out of search engines, and an author card there carries a name and nothing else. |
| **Opportunities** | Jobs, scholarships, training and grants, ordered by what a member can do and how near it is. The fraud warning on every listing is not decoration — a fake recruiter asking for a "processing fee" borrows this archive's credibility to do it. |
| **The directory** | Members who chose to be findable. Opt-in, enforced in the query rather than filtered afterwards. |
| **Family and birthdays** | Who is related to whom, confirmed by both people, and the wishes a member has been sent. |
| **Remembrance** | Nobody is removed when they die. Their account is stilled, what they made public stays public, and they are remembered in the Ancestry Records. |
| **Messages** | Write to anybody in the community. Search a name, press send. |
| **News** | A publication, not a noticeboard — announcements, a featured story, photographs, film, sources and a submission path for members. |
| **The places of Ekori** | Ajere, Ntan, Epenti, Afrekpe — and everything inside them. |

The directory is the one part of this that requires a session. It lists real
people with their professions and where they live, and that is not a page to
leave open to whoever finds the address; everything else above is readable by
anybody, and joining takes a minute.

### Writing to the Preservation Team

The contact page takes a message rather than offering an email address, because
a `mailto:` is where most people on a phone stop. A message reaches every
administrator instead of one inbox, carries its own state so two people do not
answer it twice, and gives the sender a reference they can quote.

Two topics jump the queue: *"what do you hold about me"* and *"please remove
something about me"*. Neither needs an account — somebody asking for their own
material to be taken down must not first have to create a record of themselves
to ask. [Terms](/terms), [Privacy](/privacy) and [Cookies](/cookies) are linked
from the footer of every page and describe what the platform actually does; if
you change how something works, change them in the same commit.

### You can reach somebody without being given their number

That sentence is the whole design of the messaging module, and everything in it
follows from the sentence. A member is findable by name, can be written to, and
can reply — and at no point does either person's phone number or email address
leave the database. A search result carries a name, a handle and a headline; a
conversation carries messages.

The thing people want from a directory is *contact*. The thing they are rightly
unwilling to publish is *contact details*. Those are separable, and this
separates them.

If somebody does want the number — to call about a funeral, to send a document —
they ask, with a reason the other person reads before deciding. Approving writes
one row to `contact_grants`, and that row is the only thing in the system that
releases a phone number: `visibleProfile()` consults it on every profile it
shapes, uncached, so revoking takes effect on the next request. Everybody can
see who holds their details and take them back in one press.

### Three of these deserve a paragraph of their own

**Remembrance is built around the wrong case.** Recording a living person as
dead is the most damaging thing anybody can do here, and four things stand in
the way, none of them sufficient alone: a report changes nothing; confirmation
requires somebody who was *already* family, accepted before the report was
filed; the account holder is told and can undo it themselves in one press, with
no deadline and no review; and the account stays readable throughout, because an
account locked out of contesting its own death cannot correct the mistake. The
Preservation Team can reverse any of it at any point.

**The list of places grows from what people type.** No list an administrator
writes will ever contain every compound in Ekori, and a member whose home is
missing from a dropdown picks the wrong thing or gives up. So the field is free
text, every answer is kept in the member's own words, and a name that *two
different people* give is promoted into the real list automatically — one person
typing something is a spelling; two people typing the same thing is a place.

---

## Local development

Requires Flutter 3.38+, Node 20+ and a Cloudflare account.

```bash
# 1. API
cd worker
npm install
cp .dev.vars.example .dev.vars          # then set JWT_SECRET to 32+ random chars
npx wrangler d1 migrations apply ekoli-yeden-db --local
npm run dev                             # http://localhost:8787

# 2. Website  (in a second terminal)
cd frontend
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8787
```

Check the API is healthy:

```bash
curl http://localhost:8787/api/health
# {"success":true,"service":"Ekoli Yeden Digital Home API","status":"healthy"}

curl http://localhost:8787/api/health/ready   # also checks D1, R2 and the secret
```

### Before committing

```bash
cd frontend && flutter analyze && flutter test
cd ../worker && npx tsc --noEmit
```

### Locked out of an administrator account

```bash
cd worker
npm run admins                                        # who holds super_admin
node scripts/reset-password.mjs --email you@example.com
```

The reset-link flow cannot help here — generating a link needs an account that
already works — so this writes straight to D1, using the same PBKDF2 parameters
as the Worker. It shows the SQL, asks before writing, and revokes every existing
session for the account. See DEPLOY.md.

---

## Deployment

```bash
# API
cd worker
npx wrangler d1 migrations apply ekoli-yeden-db --remote --env production
npx wrangler secret put JWT_SECRET --env production
npx wrangler deploy --env production

# Website
cd frontend
flutter build web --release \
  --dart-define=API_BASE_URL=https://ekoli-yeden-api.ndovera.workers.dev \
  --dart-define=ENVIRONMENT=production \
  --dart-define=SITE_URL=https://ekoli.pages.dev
npx wrangler pages deploy build/web --project-name ekoli --branch main
```

`frontend/web/_redirects` provides the SPA fallback that makes clean URLs work
on Pages — without it, `/history` would 404 because that path exists only
inside the Flutter router.

### Environment variables

Set with `--dart-define` at build time. All are public; none is a secret.

| Variable | Purpose |
|---|---|
| `API_BASE_URL` | Where the Worker lives |
| `ENVIRONMENT` | `development`, `staging` or `production` |
| `SITE_URL` | Canonical origin, used to build SEO URLs |

### Secrets

Held only by the Worker, set with `wrangler secret put`, never in source and
never sent to the client.

| Secret | Purpose |
|---|---|
| `JWT_SECRET` | Signs session tokens. 32+ characters, required |
| `YOUTUBE_API_KEY` | Optional. Pre-fills video metadata for an administrator |

---

## Security

- **Zero trust.** Every protected request is authenticated, resolved to a user,
  checked for role and granular permission, and denied by default. The decision
  is made in `worker/src/services/permissions.ts` and never delegated to the
  client. Hiding a button in Flutter is a courtesy; the API is what refuses.
- **Passwords** are PBKDF2-HMAC-SHA256 with a per-user salt, at the Workers
  runtime's maximum of 100,000 iterations.
- **Sessions** store only a digest of the refresh token, so a database snapshot
  cannot be replayed. Refresh rotates the session; a stolen token is usable at
  most once. Suspending an account or changing a password revokes every session
  immediately.
- **CORS** is an explicit allow-list per environment. There is no `*` fallback.
- **Errors** never expose a stack trace, an SQL fragment, a binding name or a
  secret. A request id ties the message a visitor sees to the log line that
  explains it.
- **Uploads** are checked against a per-folder MIME allow-list and size limit,
  and re-checked after reading rather than trusting client-reported metadata.
- **IP addresses** are stored only as a salted digest in the audit log.
- **The audit log** is append-only. There is no update or delete path in the
  application.

---

## Documentation

| Document | Contents |
|---|---|
| [docs/architecture.md](docs/architecture.md) | How the layers fit together, and why |
| [docs/database.md](docs/database.md) | Every table and the reasoning behind it |
| [docs/contribution-guidelines.md](docs/contribution-guidelines.md) | For developers, and for the Preservation Team |

---

## Status

Every module is built. Modules 1 and 2 — the archive itself and its editorial
workspace — are deployed; the community modules (membership, the forums,
opportunities, the directory, family and birthdays, remembrance and the places
of Ekori) are complete in the repository and go out with the migrations listed
in [DEPLOY.md](DEPLOY.md).

The platform is finished and the archive is empty — which is the correct state
for a community archive on its first day. Every section is ready to receive
verified material.

The one exception is the history section, which carries an **Initial Research
Edition**: a compilation from two secondary web sources, every claim attributed
inline, flagged unverified, and published under a notice saying it is a
starting point for research rather than settled community history. One of those
sources carries Wikipedia's own banner stating it cites no sources at all, which
is recorded in the citation.

The first real work is not more code. It is constituting the Preservation Team,
creating their accounts, and beginning to collect what the elders still
remember.

---

<div align="center">

**Unity · Progress · Development**

</div>
