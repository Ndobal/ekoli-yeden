# Editorial tools

This change connects the existing archive APIs to four editing workflows.
It does not deploy the application or change the database schema.

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

The Worker suite includes real SQLite integration tests applying all 41 existing
migrations, then exercising settings, citations, quizzes, oral histories,
publication permissions and search separation. Run with Node 24 or newer:

```sh
cd worker
npm ci
npm test
npm run typecheck
```

Dart formatting provides a local syntax check. Full Flutter analysis, widget
tests and a release web build still need to run in a trusted Flutter environment.
Local Flutter setup was stopped by automatic approval review after it attempted
a request to the cloud instance metadata endpoint; it was not retried.

Before merge, run from `frontend/`:

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

## Remaining audit items

Carousel slide management, actual navigation-item management, a version-history
viewer, map coordinate editing and project funding inputs remain future work.
