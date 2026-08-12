# Deploying

Everything below is committed and built. The only step outstanding is the
deploy itself, which needs a Cloudflare session.

## 1. Sign in to Cloudflare

The OAuth token expires periodically. Renew it in a terminal you can interact
with — it opens a browser:

```bash
cd worker
npx wrangler login
npx wrangler whoami        # should show the Ndovera account
```

## 2. Create the submissions bucket

New in this release: contributed files go to a bucket of their own, kept apart
from the published archive. It has not been created yet.

```bash
cd worker
npx wrangler r2 bucket create ekoli-yeden-submissions
```

## 3. Apply the new migrations

Four migrations are pending on production: `0010`–`0013`.

```bash
cd worker
npx wrangler d1 migrations apply ekoli-yeden-db --remote --env production
```

## 4. Deploy the API

```bash
cd worker
npx wrangler deploy --env production
```

## 5. Deploy the website

The build in `frontend/build/web` is current — the release build was run
against the production API. To rebuild from scratch:

```bash
cd frontend
flutter build web --release \
  --dart-define=API_BASE_URL=https://ekoli-yeden-api.ndovera.workers.dev \
  --dart-define=ENVIRONMENT=production \
  --dart-define=SITE_URL=https://ekoli.pages.dev

npx wrangler pages deploy build/web --project-name ekoli --branch main
```

The Pages Functions in `frontend/functions/` deploy with it — that is what
rewrites the per-page SEO metadata at the edge.

## 6. Check it worked

```bash
API=https://ekoli-yeden-api.ndovera.workers.dev

curl -s $API/api/health
curl -s $API/api/health/ready          # D1, R2 and the secret

# The share preview a WhatsApp link produces:
curl -s -A "facebookexternalhit/1.1" https://ekoli.pages.dev/history/history-of-ekoli-yeden-initial-research-edition \
  | grep -oE 'property="og:(title|description|image)" content="[^"]*"'
```

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
