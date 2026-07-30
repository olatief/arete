# M3 — Deck ingest + notes editor (2 days)

**Goal:** the whole "CMS": a lesson form, a background job that rasterizes an
uploaded PDF deck into per-page slide images, a notes table with autosave, and
`rake lessons:import` for bulk authoring from files.

> Execution note: the recommended order runs **M4 before M3** (see plans/README.md).
> This plan assumes M1's hand-seeded slides exist either way.

## 0. Prerequisite

`poppler-utils` must be present (`pdfinfo`, `pdftoppm`). Add to dev setup docs and
the production image/host provisioning. Fail the ingest job with a clear error if
the binaries are missing.

## 1. Admin lesson form

- Namespace `admin` (super_admin-only via Pundit): `Admin::LessonsController`
  with new/create/edit/update.
- Fields: title, code, locale, unit (grade/track placement), position, `prime`,
  `close_prompt`, estimated_minutes, tags (comma-separated text input →
  `text[]`), materials (multi-file), deck (single PDF), publish checkbox that
  sets/clears `published_at`.
- Standard scaffold-grade views; no JS beyond Turbo.

## 1b. Admin lesson index

`Admin::LessonsController#index` — the screen the Mīzān team lives in (UX-SPEC §4.6):

- Filters as GET params: search, track, grade, status (published/draft), locale.
- **Authoring-completeness column** — "notes 2 / 6" — the half-finished state a
  published/draft flag can't show. One query with a slides/notes counting join,
  not N+1.
- **Locale column**, so the EN/AR coverage gap is visible on one screen.
- Draft rows visually distinct (chip), "no deck uploaded" called out inline.

## 2. Deck ingest job

`DeckIngestJob` (Solid Queue), enqueued after a deck attach/replace:

```ruby
# 1. Download deck blob to a tempdir
# 2. pages = `pdfinfo #{path}`[/^Pages:\s+(\d+)/, 1].to_i
# 3. For page n in 1..pages:
pdftoppm -png -singlefile -f n -l n -scale-to-x 1920 -scale-to-y 1080 deck.pdf out/page
# 4. Upsert Slide rows
```

Hard requirements (all from measured traps — see CLAUDE.md gotchas):

- **`-singlefile` always.** Without it the output filename's zero-padding derives
  from the deck's total page count, not the requested page — `%02d` guesses break
  on long decks. With it, the output is exactly `page.png`.
- `-scale-to-x 1920 -scale-to-y 1080` — explicit pixels, not DPI. (If non-16:9
  decks ever appear, switch to `-scale-to 1920` and letterbox in CSS; note this
  in the job as a comment-free conditional only if it actually happens.)
- **Upsert must preserve notes, `title`, and `suggested_seconds`.** For each page
  1..N: find-or-initialize `Slide` by `(lesson_id, page_number)`, replace the
  attached `image`, keep existing `notes`, `title`, and `suggested_seconds`
  untouched. Delete slides with `page_number > N`. Wrap in a transaction.
- Generate the small companion preview as an Active Storage variant
  (`resize_to_limit: [480, 270]`) — pre-process it here (`.processed`) so M4's
  phone view doesn't rasterize on first teach.
- Set a simple ingest status the UI can show (e.g. `deck_ingested_at` timestamp
  column on `Lesson`, or infer from slides count vs `pdfinfo`); broadcast a Turbo
  Stream to refresh the notes table when done. Job is seconds-long (~1.3s / 15
  pages), so a spinner + Turbo refresh is enough.

## 3. Notes editor

`Admin::SlidesController#update` + one view on the admin lesson page:

- One row per slide: thumbnail, page number, a `title` text input, a `minutes`
  input (stored as `suggested_seconds`), and a `<textarea>` for `notes`.
- **Autosave on blur**: each row is its own small form; a ~10-line Stimulus
  controller submits via `requestSubmit()` on field blur (all three fields, same
  form); respond with a Turbo Stream that flashes a "Saved" indicator on the row.
- Per-row character-count / read-time hint (UX-SPEC §4.5) — a note longer than
  the phone screen means scrolling mid-lesson.
- No nested forms, no add/remove-slide UI — slides only come from ingest.

## 4. `rake lessons:import[path]`

The highest-leverage tool: the Mīzān team drafts in Google Docs, exports to a
folder per lesson, and this task ingests it. Makes 260 lessons feasible and the
curriculum diffable in git.

Folder format (document it in `docs/IMPORT_FORMAT.md`):

```
kindness-g6/
  lesson.md        # YAML front matter + sections
  deck.pdf
  materials/       # optional; filenames are the labels
```

`lesson.md`:

```markdown
---
code: MZN-G6-KIND
locale: en
track: mizan
grade: 6
unit: "Character & Community"
position: 3
title: "Kindness"
estimated_minutes: 45
tags: [kindness, virtue, community]
published: true
---

## Prime
…text…

## Close prompt
…text…

## Notes
### 1
Notes for page 1…
### 2
title: No one claps
time: 3m
Notes for page 2…
```

Each `### N` block accepts optional leading `title:` and `time:` lines (in either
order, before the notes text). `title:` fills `Slide#title`; `time:` fills
`Slide#suggested_seconds` and accepts `3m`, `2m30s`, or `150s`. Easy to type in
Google Docs, trivially parseable, no clever delimiters. Document both alongside
the `**stage direction**` convention in `docs/IMPORT_FORMAT.md`.

Behavior:

- Idempotent: match lesson by `(code, locale)`; update in place. Find-or-create
  the unit under the named track/grade.
- Attach `deck.pdf` and enqueue `DeckIngestJob` **inline** (`perform_now`) so the
  task finishes with slides present; then apply the `### N` notes blocks by page
  number (import notes win over existing notes — the file is the source of truth).
- Attach every file in `materials/`.
- Validate before writing: unknown keys, missing required fields, notes for pages
  beyond the deck's page count → abort with a line-numbered error, touch nothing.
- Also accept a parent directory of many lesson folders and import all,
  reporting a summary table.

Memory note from the stack decision: bulk import should run **locally against
production storage** (Render Starter is 512 MB; `pdftoppm` needs headroom).
Document the invocation in the task's `desc`.

## 5. Tests

- Job test with a small fixture PDF (build a 3-page PDF in the test, e.g. with
  `prawn` as a test-only dependency or a committed fixture): slides created,
  images attached, page count correct.
- **Re-upload preserves notes, title, and suggested_seconds**: ingest deck A
  (3 pages), type notes + a title + a time on page 2, ingest corrected deck A′
  (3 pages) → all three survive; ingest 2-page deck → slide 3 deleted.
- Import task round-trip on a fixture folder: creates the lesson, applies notes
  and the `title:` / `time:` lines (`3m`, `2m30s`, `150s` all parse to seconds),
  idempotent on second run; malformed front matter aborts cleanly; an unparseable
  `time:` aborts with a line-numbered message, touching nothing.
- Autosave: request test on `Admin::SlidesController#update` scoping (can't edit
  another lesson's slide without authorization).

## Acceptance checks

- [ ] Upload a real deck through the form → slides + images appear without reload.
- [ ] Re-uploading a corrected deck never wipes typed notes (test-proven).
- [ ] `bin/rails "lessons:import[docs/fixtures/kindness-g6]"` builds the complete
      Kindness lesson from files alone.
- [ ] Ingest of the 15-page fixture completes in seconds; job retries/fails loudly
      if poppler is absent.
