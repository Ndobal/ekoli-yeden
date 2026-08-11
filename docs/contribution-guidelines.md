# Contribution guidelines

Two audiences, and the second matters more.

- [For the Preservation Team](#for-the-ekoli-yeden-preservation-team) — the
  people who fill the archive.
- [For developers](#for-developers) — the people who maintain the software.

---

## For the Ekoli-Yeden Preservation Team

### The one rule

**Nothing is invented.**

Not a date, not a name, not a chief, not the meaning of a word, not a
population figure. Where something is not known, the archive says so. An empty
field is honest; a plausible guess is a lie that becomes harder to correct every
year it sits there.

This is enforced in the software as well as in practice. Content defaults to
`draft`. Verification defaults to `unverified`. Only `published` records are
visible to a visitor.

### Before publishing anything

Ask three questions.

1. **Where did this come from?** Record it. An oral account from a named elder
   is a source. So is a photograph, a document, a book. "Everyone knows" is not.
2. **Who confirmed it?** Historical claims, leadership records and language
   entries need somebody with standing to confirm them before they are marked
   verified.
3. **Who supplied it, and did they agree?** Record the contributor and what they
   permitted. A living person's profile needs their consent, or their family's.

### The workflow

```
draft ──► pending_review ──► approved ──► published
             │                              │
             └──► rejected ──► revise        └──► archived
```

Writing and publishing are separate on purpose. A Writer drafts and submits; a
Reviewer approves; a Publisher makes it live. Being on the Editorial Team does
not give anybody the ability to put something on the public site by themselves —
that is a deliberate safeguard for an archive the community will rely on.

### Language entries

The most important rule in the whole platform lives here.

**Never enter a meaning you are not certain of.** A word with no confirmed
meaning is recorded with the meaning left blank and shown as awaiting
verification. That is correct and useful — it tells the next person exactly what
work remains. A guessed meaning is worse than nothing, because it looks
finished.

Record the speaker. Record the dialect or variation — Ekoli-Yeden speech varies
between families and quarters, and flattening that variation loses information
the archive exists to keep.

### Photographs

A photograph without a caption is preserved but not documented. What turns it
into an archive record is: who is pictured, where, when, and who took it. Even a
partial answer is valuable. "Three women at a Leboku in the 1980s, names not
known" is far better than nothing, and somebody may recognise a face later.

### Material from the internet

Treat it as a lead, not as fact. The history section currently carries an
"Initial Research Edition" compiled from two web sources, with every claim
attributed and the whole thing flagged unverified. One of those sources carries
Wikipedia's own warning that it cites no sources at all.

That is the model: import it, cite it, mark it, then do the real work of
confirming or correcting it from the community's own knowledge.

### Editing the website's text

You do not need a developer. Sign in, open the Editorial dashboard, and edit any
heading, paragraph, button label or notice on the site. Your change is saved as
a draft — visitors keep seeing the current text until it has been reviewed and
published. Nothing you type there can break the site.

---

## For developers

### Before you commit

```bash
cd frontend && flutter analyze && flutter test
cd ../worker && npx tsc --noEmit
```

All three must be clean. The analyzer is configured to treat unused imports,
unused locals and dead code as errors, not suggestions.

### Where things go

| Adding | Goes in |
|---|---|
| A content type | A migration, then an entry in `worker/src/services/content-registry.ts` |
| An endpoint | `worker/src/routes/*.routes.ts` with an explicit permission |
| Business logic | `worker/src/services/` |
| SQL | `worker/src/repositories/` — nowhere else |
| A screen | `frontend/lib/features/<section>/` |
| An API call | A repository in `frontend/lib/repositories/` — screens never call `ApiClient` |
| Visible text | The CMS, with a fallback in code |

### Rules that are not negotiable

**Authorise on the server.** Every protected route names its permission. Hiding
a control in Flutter is a courtesy to the user, never a security measure. If the
only thing stopping an action is that the button is hidden, it is not stopped.

**Never trust the client.** Status, ownership and permissions come from the
database, not from the request body. `pickWritable` exists so an unexpected
column cannot be written; `fixedFilters` exists so a resource cannot reach
another's rows.

**Never invent content.** This applies to code as much as to editors. Do not
seed example history. Do not add placeholder chiefs. Do not write a default
meaning for a word. If a fixture is needed for a test, make it obviously
fictional and keep it out of migrations.

**Every CMS call site supplies a fallback.** The site must render correctly with
an empty database.

**No secrets in Flutter.** The bundle is public. If it must be secret, it lives
in the Worker as a Cloudflare secret.

**Migrations are append-only.** Never edit one that has been applied.

### Comments

Explain *why*, not *what*. The code says what it does. A comment earns its place
by recording a constraint, a trade-off, or a decision that would otherwise look
arbitrary — the PBKDF2 iteration cap, why contributor attribution is a separate
table, why the capability-to-resource permission bridge is guarded.

### Testing

The tests that matter most here are the ones covering rules that would be
expensive to get wrong: CMS fallbacks, the permission model, and formatters
handling missing data. A bug in any of those either breaks the site for
everybody or quietly grants access that should not exist.

The permission model in particular is worth testing thoroughly. A test is what
caught `content.read` accidentally satisfying `users:read` — a privilege
escalation that would have handed every Editorial Team member the user list and
the audit trail.

### Commits

Explain the change and its reasoning. A future maintainer reading `git log`
should understand why, not just what.

---

## Reporting a security issue

Do not open a public issue. Contact the Technology Team of the Ekoli-Yeden
Preservation Team directly. This platform holds personal data about community
members and material families have entrusted to it.
