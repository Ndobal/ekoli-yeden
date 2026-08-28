# Deploying

Everything below is committed and built. The steps outstanding need a
Cloudflare session.

---

## 0. Locked out? Reset a Super Admin password first

The reset-link flow cannot help when nobody can sign in — generating a link
requires an account that already works. So there is a script that goes straight
to D1:

```bash
cd worker

# Who currently holds super_admin
npm run admins

# Reset one. With no --password, a six-word passphrase is generated.
node scripts/reset-password.mjs --email you@example.com

# Or choose your own (at least 12 characters — the API refuses less)
node scripts/reset-password.mjs --email you@example.com --password "a phrase you will remember"
```

It shows you the password and the exact SQL, asks for confirmation, and only
then writes. Every existing session for that account is revoked in the same
statement — a reset that leaves somebody else's session alive has not actually
taken the account back.

The hashing is PBKDF2-SHA256, 100,000 iterations, matching
`worker/src/utils/crypto.ts` exactly. `--print-sql` shows the statements without
running anything, if you would rather paste them into the Cloudflare dashboard.
`--local` acts on the development database instead.

Once you are in, change it from **Account → Password**: the script cannot avoid
showing you the password on the way in, and a password an administrator has
seen written down should not stay in use.

---

## 1. Sign in to Cloudflare

The OAuth token expires periodically. Renew it in a terminal you can interact
with — it opens a browser:

```bash
cd worker
npx wrangler login
npx wrangler whoami        # should show the Ndovera account
```

## 2. Apply the pending migrations

Nothing is pending. `0001`–`0030` are applied to production as of
28 August 2026 — the API and the website were deployed from this commit.

To check, or after adding one:

```bash
cd worker
npx wrangler d1 migrations apply ekoli-yeden-db --remote --env production
```

What they do, in the order they run:

| | |
|---|---|
| `0014` | A photograph album for every festival, every year, backfilled for the editions that already exist. |
| `0015` | The dictionary: senses, variant forms, example sentences with pronunciation, parts of speech, and a queue for words the community proposes. Existing entries are carried across, not replaced. |
| `0016` | Age grades become records the grades themselves run, with their own administrators, roster and posts. The age grade article already written is migrated across, keeping its id so its citations still resolve. |
| `0017` | Yakoli membership: one Okoli account for the whole platform, its profile, skills, interests, privacy settings and notifications. |
| `0018` | The community forums — three spaces, categories, topics, replies, reactions, reports, moderation actions and sanctions. Adds the Community Moderator role. |
| `0019` | Age grades generalise into `community_groups`, so a family, a dance troupe and an age grade are the same kind of record. |
| `0020` | Family connections, birthdays, and remembrance: death reports, the ancestry records, and tributes. |
| `0021`–`0023` | Membership navigation, event albums, temporary passwords. |
| `0024` | Yakoli Opportunities — jobs, scholarships, training and grants, with skill matching and reports. |
| `0025`–`0027` | Membership moves into the dashboard; profiles and news gain their own structured contribution paths. |
| `0028` | The places of Ekori: one nested table, the aliases that stop the same compound arriving three times, and the candidate list the tree grows from. |
| `0029` | Messages from the public — the contact form's inbox — and the seeded strings the Terms, Privacy and Cookies pages read their dates and addresses from. |
| `0030` | Messages between members, and the contact requests that govern them: conversations, direct messages, and the `contact_grants` row that is the only thing releasing anybody's phone number. |

Every one has been applied to a scratch database from `0001` and verified.

**`0028` seeds Ekori and its four wards** — Ajere, Ntan, Epenti and Afrekpe — and
nothing below them. That is deliberate: the quarters and compounds arrive from
what members type into their own profiles, and a name two different people give
becomes a place on its own. Administration → The community shows what has been
typed and is not yet recognised.

## 3. Deploy the API

```bash
cd worker
npx wrangler deploy --env production
```

## 4. Deploy the website

The build in `frontend/build/web` is current — the release build was run
against the production API. To rebuild from scratch:

```bash
cd frontend
./deploy.sh
```

**Use the script. Do not run `flutter build web` by hand.**

A bare `flutter build web --release` succeeds and produces a bundle that points
every visitor at `http://localhost:8787`, because `API_BASE_URL` arrives through
`--dart-define` and silently falls back to the development default when the flag
is missing. The site then loads, renders every page, and cannot sign anybody in,
register anybody, or fetch a single record — and every failure reports itself as
"we could not reach the archive", which sends people to check an internet
connection that was never the problem.

That happened in production, to real people. The script passes the defines and
then greps the built bundle to prove they took effect, refusing to deploy if
they did not. The app also renders a red banner across every page if it ever
finds itself in that state, so the failure can never again be silent.

The command the script runs, for reference:

```bash
flutter build web --release \
  --dart-define=API_BASE_URL=https://ekoli-yeden-api.ndovera.workers.dev \
  --dart-define=ENVIRONMENT=production \
  --dart-define=SITE_URL=https://ekoli.pages.dev

npx wrangler pages deploy build/web --project-name ekoli --branch main
```

The Pages Functions in `frontend/functions/` deploy with it — that is what
rewrites the per-page SEO metadata at the edge.

## 5. Check it worked

```bash
API=https://ekoli-yeden-api.ndovera.workers.dev

curl -s $API/api/health
curl -s $API/api/health/ready          # D1, R2, where contributions land, and the secret

# The new endpoints
curl -s $API/api/language/index        # the A–Z index and how much is recorded
curl -s $API/api/photographs           # every photograph, from every album
curl -s $API/api/age-grades-activity   # what the grades have posted

# The community modules
curl -s $API/api/forums                # the three spaces, and who may enter each
curl -s $API/api/ancestry              # the people the archive remembers
curl -s $API/api/places                # Ekori, its wards, and everything under them
curl -s $API/api/contact/topics        # what the contact form offers

# Messaging is members only. All three must answer 401 without a token.
curl -s -o /dev/null -w '%{http_code}
' $API/api/messages
curl -s -o /dev/null -w '%{http_code}
' $API/api/messages/people?q=test
curl -s -o /dev/null -w '%{http_code}
' $API/api/messages/contact-requests

# The directory is members only. Both of these must answer 401 without a token.
curl -s -o /dev/null -w '%{http_code}
' $API/api/directory
curl -s -o /dev/null -w '%{http_code}
' $API/api/members/any-handle

# The share preview a WhatsApp link produces:
curl -s -A "facebookexternalhit/1.1" https://ekoli.pages.dev/history/history-of-ekoli-yeden-initial-research-edition \
  | grep -oE 'property="og:(title|description|image)" content="[^"]*"'
```

---

## After deploying: two things that changed for administrators

### Somebody uses "forgot password"

The person asking sees exactly what they saw before — a message that says a
link has been sent if the address is registered, and nothing that reveals
whether it is.

What is new is that **every Super Admin and Deputy is now told**, in their
notifications:

- when the link **was** delivered, it says so and where to (masked), and there
  is nothing to do;
- when it **was not** — no email service configured, a bounced address, a
  number that changed — **the notification carries the link**, because in that
  case nobody has it and the administrator passing it on personally is the only
  delivery left.

**Administration → Users** now has two actions on every row:

| | |
|---|---|
| **Reset link** | Generates a fresh link and shows it once, to copy or read out. Nobody learns the person's password. |
| **Temporary password** | Three words and a number, readable down a phone line. It replaces their password, ends every session on the account, and only gets them as far as the change-password screen. |

A temporary password is **not** issued automatically by the public form, and
that is deliberate: issuing one replaces the account's password, so doing it on
an unauthenticated request would let anybody lock any member out by typing that
member's address into a form. It stays one press away, where a real
administrator decides.

### Passwords: what changed, and why

**The minimum is now six characters, and common passwords are refused.** Twelve
characters produces `Password123!` on a sticky note far more often than it
produces security, and this community is reached on shared phones. What actually
breaks into accounts is a list of a few hundred strings, so that list is refused
outright — `123456`, `password`, `qwerty`, runs off the keyboard, one character
repeated, and the person's own name or email. See
`worker/src/utils/password-quality.ts`.

**No reset link is ever stored.** An earlier version put the link into the
notification sent to administrators. A reset link is, for the hour it lives, as
good as the password — and the service stores only a digest of it precisely so a
copy of the database is not a pile of working credentials. The notification now
says who asked and whether it reached them; the link is one press away in
**Administration → Users**, minted fresh and shown once.

**Temporary passwords now expire.** `temp_password_ttl_hours` (default 72) was in
the settings table from the start and nothing enforced it, so a password read
down a phone line in March still worked in December for anybody who kept the
note. Sign-in now refuses an expired one and says so.

### The member directory is now members-only

`/api/directory`, `/api/directory/facets` and `/api/members/:handle` all require
a session, the pages behind them offer membership instead of a list, and
`/directory` is marked `noindex` at the edge. A list of real people with their
professions and locations is not something to leave standing open to whoever
finds the URL. Joining is free and takes a minute, which is the point of the
directory in the first place.

---

## Messages between members

Members can now write to each other from `/messages` — search a name, press
send. **Nobody's phone number or email is disclosed by any of it.** A search
result carries a name, a handle and a headline; a conversation carries messages.

Contact details are released by exactly one mechanism: somebody asks, and the
person says yes. That produces a row in `contact_grants`, which
`visibleProfile()` reads on every profile it shapes — never cached, so taking it
back works on the next request. A member sees who holds their details, and takes
them back in one press, at **Account → Requests**.

Two settings live in **Account → Privacy**, both defaulting to on: *let members
find me by name* and *let members write to me*. They are separate from the
directory listing on purpose — not wanting to be in a published list is not the
same as not wanting your cousin to be able to say hello.

---

## Where contributed files go

Contributions now land in R2 and the upload form works. This is what changed
and why.

The design was a separate `ekoli-yeden-submissions` bucket for material nobody
has reviewed. That bucket was never created — and a binding to a bucket that
does not exist fails the whole deploy, which took the contribution form down
with it. A form that rejects every upload teaches the community that the
archive does not want their photographs, which is a worse outcome than sharing
a bucket.

So the binding is commented out in `wrangler.jsonc`, and contributed files go
into `ekoli-yeden-media` instead.

**What keeps them private is not the bucket.** `/api/media/file/*` resolves a
storage key through the `media_assets` table and returns 404 when there is no
row — and a contributed file has no row until it is approved. Guessing the key
gets a visitor nowhere. This is verified: an uploaded contribution returns 404
on the public route and 401 on the review route without a token.

A separate bucket is still preferable, for reasons the media route does not
cover: different retention, different lifecycle rules, and defence in depth
against a future change to that route. To turn it back on:

```bash
cd worker
npx wrangler r2 bucket create ekoli-yeden-submissions
# uncomment the SUBMISSIONS binding in wrangler.jsonc — two places:
#   the top-level r2_buckets, and env.production.r2_buckets
npx wrangler deploy --env production
```

Storage keys are identical either way, so records written before the change keep
resolving after it. `/api/health/ready` reports which arrangement is live.

---

## Optional: automatic delivery of password reset links

The reset flow works today without either of these. When neither is
configured, an administrator generates the link from **Users** and passes it
on personally — which is deliberate, and remains a useful fallback for
somebody whose email has stopped working.

To have links sent automatically:

### Email

Needs a domain you control, verified with an email provider. The
implementation uses [Resend](https://resend.com).

```bash
cd worker
npx wrangler secret put RESEND_API_KEY --env production
npx wrangler secret put RESET_EMAIL_FROM --env production   # e.g. archive@ekoliyeden.org
```

### WhatsApp

Needs a Meta WhatsApp Business account and an approved sender number. This is
a slower process — expect business verification.

```bash
cd worker
npx wrangler secret put WHATSAPP_TOKEN --env production
npx wrangler secret put WHATSAPP_PHONE_NUMBER_ID --env production
```

A user with `preferred_contact` set to `whatsapp` is sent their link there
first, falling back to email.

---

## Optional: a custom domain

The site is on `ekoli.pages.dev`. To move it to the community's own domain:

1. Add the domain to Cloudflare and point its nameservers there.
2. In the Pages project, add the custom domain.
3. Update three places so links, CORS and SEO all agree:

   - `worker/wrangler.jsonc` — `ALLOWED_ORIGINS`, `SITE_URL`,
     `PUBLIC_MEDIA_BASE_URL` under `env.production`
   - `frontend/functions/_middleware.js` — the `SITE` constant
   - `frontend/functions/sitemap.xml.js` — the `SITE` constant
   - `frontend/web/robots.txt` — the `Sitemap:` line

4. Rebuild with `--dart-define=SITE_URL=https://yourdomain`, and redeploy both.

An origin missing from `ALLOWED_ORIGINS` receives no CORS headers and the
browser blocks it, so that list is the one to check first if the site loads
but no data appears.

---

## Creating the second administrator

The Deputy Administrator has every administrative permission except appointing
or removing a Super Admin.

```bash
# 1. Have them register at /register, or create the account under
#    Administration → Users.
# 2. Grant the role:
cd worker
npx wrangler d1 execute ekoli-yeden-db --remote --env production --command \
  "INSERT OR IGNORE INTO user_roles (id, user_id, role_id, assigned_by, created_at)
   SELECT lower(hex(randomblob(16))), u.id, 'role_deputy_super_admin', NULL, datetime('now')
   FROM users u WHERE u.email = 'their@email';"
```

Or from **Administration → Users** once the role-assignment form is in place.

To confirm the limit holds, sign in as the deputy and try to grant somebody
`super_admin` — the API returns 403 with *"Only a Super Admin can appoint
another Super Admin."*

---

## After deploying: confirming the age grades

Age grades registered by the community arrive at `pending_review` and are
invisible until somebody confirms them. That is the only gate — after it, the
grade runs its own page.

```bash
cd worker
npx wrangler d1 execute ekoli-yeden-db --remote --env production --command \
  "SELECT slug, title, formed_year, status, created_at FROM age_grades
   WHERE status = 'pending_review' ORDER BY created_at;"
```

Publish one from the Editorial workspace (**Content → Age grades**), or:

```bash
npx wrangler d1 execute ekoli-yeden-db --remote --env production --command \
  "UPDATE age_grades SET status = 'published', updated_at = datetime('now')
   WHERE slug = 'the-slug';"
```

A grade cannot publish itself, and cannot mark itself verified — those columns
are not writable through the routes its administrators use. What it says about
itself is labelled on the page as the grade's own words rather than as verified
community history.
