# Editorial tools

This change connects the existing archive APIs to four editing workflows.
It does not deploy the application. The layout editors added below require migration 0042.

## Workflows

- **Quizzes:** Editorial → Quizzes → New/Edit. Set the subject and level; add
  questions, two to six answers, one correct answer, an explanation and optional
  Ekoli text/audio. Move questions using the arrows. Save the draft, submit it
  or publish with the corresponding authority. Failed question/publication
  requests retain the draft ID so retrying cannot create another copy.
- **Oral histories:** Editorial → Voices of Ekori → New/Edit. Enter the speaker,
  YouTube film and/or audio, transcript, language, English interpretation,
  interpreter, recording details and consent reference. Consent is required
  before approval or publication, and cannot be removed from a published record.
- **Sources:** Sources & references → Add source records a citation, its source
  type and reliability. Search and page through the library. Use **Sources**
  beside an editorial content record to choose and attach a source, state which
  claim it supports and include a page reference. Search by title to locate
  citations beyond the first page. Creating/attaching needs sources authority;
  read-only users can inspect citations.
- **Settings:** Administration → Site settings. Edit text/numbers/JSON or toggle
  boolean switches, then save. Only changed values are sent. The server checks
  every supplied value before applying the batch. The write response updates
  the current app immediately without waiting for the public settings cache.

Upload and publish audio/images in the Media library before selecting them in
these forms. Selection uses file titles and filters to published files; the
server checks recording/cover MIME types and public availability. It also checks
question audio attachments. YouTube films do not require a media-library upload.

Quiz metadata and its question set are separate API writes. An error may leave
updated metadata saved while retaining the previous question set; the editor
keeps the saved ID and offers retry. Closing after a partial save refreshes the
record list. No learner answers or scores are sent to the server.

## Supporting corrections

- Empty edited fields now clear an existing stored value.
- The generic editorial content list has pagination beyond 60 records.
- Global search applies content-type discriminators, keeping stories and culture
  in their correct result groups.
- Direct generic status writes require the corresponding workflow authority.
  Quizzes and recordings must use the status endpoint so their publication
  checks cannot be skipped. Existing authorised festival creation is preserved.

## Validation

The Worker suite includes real SQLite integration tests applying all 42 existing
migrations, then exercising settings, citations, quizzes, oral histories,
publication permissions and search separation. Run with Node 24 or newer:

```sh
cd worker
npm ci
npm test
npm run typecheck
```

Frontend static analysis now passes with no issues. A standalone Dart 3.10.7
compiler using the project's Flutter 3.38.7 sources and engine artifacts compiles
both the application and its web bootstrap/plugin registration to JavaScript.
All hosted-package downloads used for offline analysis matched the existing
lockfile checksums. Browser checks against a temporary SQLite database and the
actual Worker code passed for carousel save/submit/approve/publish/history,
navigation publication, coordinate saving, and decimal funding form submission.
The four new screens were also rendered and inspected at 390 × 844, with no
horizontal page overflow and no failed API requests in these checks. This validation does not rerun Flutter setup: that command
was stopped by automatic approval review after an unexpected metadata request.
The normal Flutter CLI widget suite and deployment build still need a trusted
Flutter installation; the standalone validation does not claim to run them.

For the standard Flutter CLI validation/release path, run from `frontend/`:

```sh
flutter pub get
flutter analyze
flutter test
flutter build web
```

Then verify on narrow and desktop layouts: save and reopen a quiz; intentionally
fail a question save and retry; publish an interview with and without consent;
create a source and cite it; save a switch, a number and a cleared contact field.
Verify that an editor without publish authority cannot publish.


## Remaining editor screens completed

- **Homepage → Carousel:** select a published image, describe it, edit the
  heading, description and both buttons, preview the draft, and choose whether
  the slide will be visible. The separate homepage text editor remains linked.
- **Navigation:** edit each primary/footer menu item's label, destination,
  description, numeric order, button emphasis and visibility.
- **History:** the History button on archive records, news, layout items and map
  places lists earlier snapshots, dates, editors and before/after field values.
  Viewing a snapshot never restores or publishes it.
- **Map locations:** search all recorded places, including unpublished places;
  enter or clear a verified latitude/longitude pair. Saved positions are applied
  immediately. Stale saves are rejected and each update preserves a snapshot.
- **Community projects:** enter the funding target, funds raised, currency and
  completion date. Amounts accept decimals and can be cleared. Public details
  use the selected currency rather than always displaying naira.

Carousel and navigation changes now have independent drafts. Save → Submit →
Approve → Publish is enforced by the API. Editing an approved draft resets its
approval. Draft revisions prevent concurrent editors from overwriting each
other. Publishing writes the previous live snapshot, updates the live item and
clears the draft in one D1 batch. Discarding leaves the live item untouched.

Intentionally hiding every menu item or slide now stays hidden; a successful
empty CMS response no longer brings back the compiled fallback. Published hero
images are resolved in the public CMS bundle as well as the carousel endpoint.

## Deployment order

Migration **0042_layout_drafts.sql** is required by the new layout editors.
Apply it to the target database before deploying the Worker, then deploy the
frontend using the existing production configuration in `DEPLOY.md`:

```sh
cd worker
npx wrangler d1 migrations apply ekoli-yeden-db --remote --env production
npx wrangler deploy --env production
cd ../frontend
./deploy.sh
```

These instructions prepare the release; they do not mean it has been deployed.
The changes remain on the pull-request branch until reviewed and merged.

Validation recorded for this branch: **130 Worker tests passed**, TypeScript
checking passed, and frontend static analysis reported no issues.
