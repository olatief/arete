# UX alignment — data model, spec/wireframes, and milestone plans

**Origin:** review of `docs/UX-SPEC.md` + `docs/ux-wireframes.html` (30 Jul 2026) found
a set of data-model gaps the wireframes quietly imply, internal inconsistencies, and
flow gaps. This plan fixes them in three workstreams: (A) schema, (B) the UX documents
themselves, (C) the M3/M4/M5 build plans. Do them in that order — B and C encode the
decisions A makes concrete.

**Findings index** (referenced as F1… throughout):

| # | Finding |
|---|---|
| F1 | Slide titles appear in 3 wireframe surfaces but `Slide` has no title column |
| F2 | Per-slide timing (`02:30 / 03:00`, "≈ 3 min" in print) has no data source |
| F3 | Board holding state conflicts with resync-from-`current_page` (default 1); no "ended" state marker either |
| F4 | "My lessons" (`/my`) is in the nav but missing from the view inventory; "saved" has no model; TeachSession retention undecided |
| F5 | Spec says "twenty-three views", tables number 1–25 |
| F6 | "Every screen below is drawn there" is false — lightbox, settings, board-holding, accept-invitation, errors, structure, schools not drawn |
| F7 | Session-end copy contradicts itself (manual "Refresh" vs automatic return to pairing) |
| F8 | `estimated_minutes` is an integer but displays as a range ("≈ 35–40 min") |
| F9 | Wireframes hardcode the RTL arrow/chevron bug they warn about; shell CSS uses `float:right` |
| F10 | "Next (local only)" offline behavior has no reconciliation rule |
| F11 | "End" has no accidental-tap guard, and it's unrecoverable (code nulled on pair) |
| F12 | Accept-invitation is M5 but people exist from M0 — onboarding story unstated |
| F13 | Appbar "EN" chip is ambiguous (ui_locale? lesson locale?) |
| F14 | Board countdown drawn as static text; alt-text should strip markup; "Good morning, Nour" needs i18n/timezone; §10 "board × 4, companion × 3" count is wrong |

---

## Decisions (locked here so every edit below agrees)

1. **Slide gets real columns** — `title` (string, nullable) and `suggested_seconds`
   (integer, nullable). The notes markup convention (§5.2 of the spec) carries **only
   stage directions** (`**…**`). Titles and timing live in columns, editable in the
   notes editor and settable from the import file. Rationale: columns are queryable
   (next-slide preview, print, completeness stats) and survive re-ingest via the same
   preserve-by-`page_number` rule as notes. *(F1, F2)*
2. **TeachSession gets `started_at` and `ended_at`** (both datetime, nullable).
   Holding = paired, `started_at` nil. Ended = `ended_at` present. `current_page`
   stays `null: false, default: 1`. The board's resync logic keys off these, so a
   reconnect during pre-flight shows the holding screen, not slide 1. *(F3)*
3. **Paired sessions are retained as teaching history**; the sweep job deletes only
   expired *never-paired* sessions. "My lessons" (MVP) = recently-taught lessons
   derived from that history. No saved/bookmark model in MVP — "saved" moves to
   phase 2. This is teacher (not student) behavioural data; the spec states that
   posture explicitly. *(F4)*
4. **`estimated_minutes` displays as "≈ 38 min"** — the exact value, no synthetic
   range. If the Mīzān team wants ranges later, that's a display rule to add then,
   not a schema change now. *(F8)*
5. **Session end auto-issues a fresh pairing code.** On `{ended:}` the board
   transitions itself back to the waiting screen with a new code — the teacher never
   walks to the PC. *(F7, and makes spec §5.6 recovery layer 3 nearly free)*
6. **Offline companion navigation is script-browsing only.** Local Prev/Next while
   disconnected moves the *script*, never claims to move the board; on reconnect the
   phone resyncs to the server's `current_page` (what the class actually saw) with a
   brief "back on slide N" notice. *(F10)*
7. **End requires confirmation** — an in-page Turbo confirm ("End lesson? The board
   will clear."), not `window.confirm` (browser dialogs are banned in the companion).
   *(F11)*
8. **The browse appbar "EN" chip is removed.** UI locale lives in Settings; lesson
   locale lives on the lesson page next to Teach. Nothing locale-shaped in the chrome.
   *(F13)*
9. **Invitations stay in M5.** Until then users are created via seeds/console; the
   spec's build mapping says so in one line. *(F12)*
10. **Import-file syntax for titles/timing:** optional `title:` / `time:` leading
    lines inside a `### N` notes block (see Workstream C, M3). Easy to type in Google
    Docs, trivially parseable, no clever delimiters.

---

## Workstream A — data model

The five content migrations are **uncommitted** (see `git status`), so amend them in
place rather than stacking new migrations, then rebuild the dev DB.

### A1. Amend `db/migrate/20260730140004_create_slides.rb`

```ruby
t.string  :title                       # shown on companion + print; nullable
t.integer :suggested_seconds           # per-slide pacing target; nullable
```

Both nullable — a slide with neither is fully valid (timer shows elapsed only,
title line collapses).

### A2. Amend `db/migrate/20260730140005_create_teach_sessions.rb`

```ruby
t.datetime :started_at                 # nil until teacher taps Start (board holds)
t.datetime :ended_at                   # nil until End; retained rows = history
t.index [ :teacher_id, :last_seen_at ] # powers "My lessons" recents
```

### A3. Follow-through

- `bin/rails db:migrate:reset` (dev only — nothing is deployed), regenerate
  `db/schema.rb`.
- `app/models/slide.rb`: no new validations needed beyond existing; add
  `suggested_seconds` numericality (`> 0`, allow_nil).
- `app/models/teach_session.rb`: add `scope :taught, -> { where.not(paired_at: nil) }`
  and predicate helpers `holding?` / `ended?`.
- `db/seeds/` and `test/test_helpers/kindness_lesson_builder.rb`: give the Kindness
  fixture slides real titles + `suggested_seconds` (slide 5 = 180) so M4's companion
  and M5's print sheet have data to render.
- **`CLAUDE.md` data-model block**: update the `Slide` line to
  `page_number, title, suggested_seconds, notes` and the `TeachSession` line to add
  `started_at, ended_at`; extend the re-ingest invariant to "preserve **notes, title,
  and suggested_seconds** by page_number".

---

## Workstream B — UX spec + wireframes

### B1. `docs/UX-SPEC.md`

| Section | Edit |
|---|---|
| Line 3 | Change "Every screen below is drawn there" → "The key screens are drawn there" *(F6)* |
| §2 intro | Fix the count; add a row for **My lessons** `/my` ("recently taught, from teach-session history — no saved list in MVP") and number it; note it ships in M5 *(F4, F5)* |
| §2.6 | Move "saved lessons" explicitly to phase 2 *(F4)* |
| §4.4 table | Timer row: state the source — "target from `Slide#suggested_seconds`; elapsed resets on advance; no target → elapsed only". Add a row: **End confirms before ending** (decision 7). Add a row: **Offline nav is script-only; reconnect resyncs to the server page with a "back on slide N" notice** (decision 6). Slide-title and next-preview rows: source is `Slide#title` *(F1, F2, F10, F11)* |
| §4.6 | Note completeness counts title/timing too if the team adopts them (optional; keep "notes 2 / 6" as the headline stat) |
| §5.2 | Narrow scope to stage directions only; add pointer: "titles and timing are Slide columns, set in the notes editor or the import file — see M3 plan" *(F1, F2)* |
| §5.3 | Add the schema implication paragraph: holding is `started_at: nil`, ended is `ended_at`; the resync endpoint returns `{ page, started, ended }` so a reconnecting board self-heals into the correct state, never prematurely into slide 1 *(F3)* |
| §5.5 | Add: alt text derived from notes strips the `**…**` stage-direction markup *(F14)* |
| §5.6 | Update layer 3: session end auto-issues a fresh code (decision 5), so recovery = End (or board Esc) → new code appears |
| §5.7 / new §5.8 | Add "My lessons data source" note: retained paired TeachSessions; sweep deletes never-paired only; state the privacy posture (teacher-only behavioural data, consistent with PDPL stance) *(F4)* |
| §9 | Add display rule: estimated minutes render as "≈ N min", exact *(F8)* |
| §10 | Fix "board × 4, companion × 3" → "board × 3, phone × 4". Add view 4 note: "invitations land in M5; earlier users are seeded/console-created". Add My lessons to M5's row *(F12, F14)* |

### B2. `docs/ux-wireframes.html`

Copy/content fixes:

- **Session-ended empty-state card** (~line 693): "The board is free. Refresh to get
  a new pairing code." → "The board is showing a new pairing code." *(F7)*
- **Companion degraded "Next (local only)"** (~line 867): relabel button
  "Read ahead ▸" (or similar) and add one line to the note stating the
  reconciliation rule *(F10)*
- **Companion header**: add a fourth degraded/interaction frame or a note bullet for
  the **End confirmation** *(F11)*
- **Companion + print**: source lines for slide title / next preview / "≈ 3 min"
  already match the new columns — no visual change, but add "from `Slide#title` /
  `suggested_seconds`" to the notes so the mockup and schema visibly agree
- **Notes editor** (~line 1059): add per-row `title` input and `minutes` input above
  the textarea; update the header stat chips accordingly; keep the `**asterisks**`
  hint scoped to stage directions *(F1, F2)*
- **Appbar** (all browse frames): remove the `EN` chip *(F13)*
- **Library home** (~line 477): "Good morning, Nour" → "Welcome back, Nour" (no
  time-of-day logic; note that it's a `t()` string) *(F14)*
- **Board waiting** (~line 741): render a live-looking countdown ("expires in 2:41")
  instead of static "3 minutes" text *(F14)*
- **Estimated minutes**: change every "≈ 35–40 min" chip to "≈ 38 min" *(F8)*

New screens to draw (the three that earn it): *(F6)*

1. **Board · holding** — paired, pre-Start: Mīzān wordmark, no code, no slide.
   Nav entry between "Board · waiting" and "Board · teaching".
2. **Slide preview lightbox** — over the lesson page: slide large + its script +
   title, prev/next within the lightbox.
3. **Accept invitation** — shows school name + role being accepted, name + password
   fields (the content decision the spec already defends).

RTL honesty pass: *(F9)*

- Make Prev/Next/Teach glyphs and breadcrumb `›` separators mirror under the RTL
  toggle (CSS `[dir="rtl"]` swap or `::before` content) — the file is the living
  demo of the rule it states.
- Add an HTML comment at the shell CSS block: the wireframe shell is outside
  `bin/lint-rtl`'s jurisdiction (`float:right` etc. is deliberate there).

---

## Workstream C — milestone plans

### C1. `plans/M3-ingest-notes.md`

- **§1 Lesson form**: no change (title/timing are per-slide, not per-lesson).
- **New: admin lesson index** — the plan currently never mentions it. Add a short
  section: filters + **authoring-completeness column** ("notes 2 / 6") + locale
  column, per UX-SPEC §4.6.
- **§2 DeckIngestJob**: extend the upsert invariant — preserve `notes`, **`title`,
  and `suggested_seconds`** by `page_number` on re-ingest.
- **§3 Notes editor**: each row gains a `title` text input and a `minutes` input
  (stored as `suggested_seconds`), same autosave-on-blur pattern. Keep the per-row
  character-count/read-time hint from UX-SPEC §4.5.
- **§4 Import format**: extend the `### N` block with optional leading lines
  (decision 10):

  ```markdown
  ### 5
  title: No one claps
  time: 3m
  Read it, then **stop.** Do not answer your own question…
  ```

  `time:` accepts `3m`, `2m30s`, `150s` → `suggested_seconds`. Document in
  `docs/IMPORT_FORMAT.md` alongside the `**stage direction**` convention.
- **§5 Tests**: re-ingest preserves title + suggested_seconds (extend the existing
  notes-survival test); import round-trip applies title/time; `time:` parse errors
  abort with a line-numbered message.

### C2. `plans/M4-presenter.md`

- **§1 Pairing / lifecycle**: on pair, board shows the **holding screen** (wordmark),
  not slide 1. New endpoint or param: phone's pre-flight **Start** button →
  `PATCH /teach_sessions/:id/start` → sets `started_at`, broadcasts
  `{ started: true }`; board then shows `current_page`.
- **§3 Hot path**: unchanged (`{ page: N }` only). Update the allowed broadcast
  shapes list to `{page:}`, `{paired:}`, `{started:}`, `{ended:}` — still zero
  content.
- **§4 Board view**: resync endpoint returns `{ page, started, ended }`; board state
  machine waiting → holding → teaching → ended → **auto-new-code waiting**
  (decision 5 — on `{ended:}` the board requests a fresh session/code itself, no
  manual refresh). Reconnect during holding must land on holding (this is the F3
  regression test).
- **§5 Companion**: add four items —
  1. **Wake Lock** (UX-SPEC §5.1 says it belongs in M4; the plan currently omits
     it): `navigator.wakeLock.request("screen")`, re-request on `visibilitychange`,
     "awake" indicator in the header, silent fallback where unsupported.
  2. **Per-slide timer**: elapsed, resets on advance; target from
     `suggested_seconds` rendered `02:30 / 03:00`, muted, never red; elapsed-only
     when no target.
  3. **Slide title + next-slide preview** from `Slide#title` (fallback: "Slide N"
     when nil).
  4. **End confirmation** (in-page Turbo confirm) and the **offline
     reconciliation rule** (script-browsing only; resync to server page on
     reconnect with a "back on slide N" notice).
- **§6 Session lifecycle**: End sets `ended_at` (and `expires_at: Time.current`),
  broadcasts `{ended: true}`. **Sweep deletes only expired never-paired sessions** —
  paired rows are retained as teaching history for M5's My lessons (decision 3).
- **§7 Tests**: add —
  9. Board reconnecting during pre-flight shows holding, not slide 1.
  10. End requires confirmation; after end, board shows a fresh, working code.
  11. (manual) Wake lock holds through a 2-minute idle on a real phone.

### C3. `plans/M5-polish.md`

- **§1 Print**: each slide block renders `title` and "≈ Nm" from
  `suggested_seconds` when present; `**…**` stage directions render bold (matches
  the print wireframe, which already shows both).
- **§2 Invitations**: the accept screen **shows school name + role** being accepted
  (UX-SPEC view 4). Add to its tests.
- **New §: My lessons (`/my`)** — recently-taught list from retained paired
  TeachSessions (`taught` scope, distinct lessons by `last_seen_at` desc), plus the
  "Continue" row on the library home. Policy-scoped to the current teacher. Empty
  state: "Lessons you teach will appear here." No saved/bookmark feature — phase 2.
- **§3 Empty states**: align session-ended copy with auto-new-code (decision 5).
- **§5 Verification suite**: add "board holding survives reconnect (never leaks
  slide 1 early)" and "ended board auto-issues a usable new code" to the release
  gate list.

### C4. `plans/M2-library.md` — one-line touches (M2 is not yet built)

Out of the requested scope but two lines keep it consistent: add the **slide
preview lightbox** and **account settings** views (both are M2 in UX-SPEC §10, and
the M2 plan currently has neither), display estimated minutes as "≈ N min", and no
appbar locale chip.

---

## Order of work & acceptance

1. **A** (amend migrations, models, seeds, builder, CLAUDE.md) — everything else
   references these columns.
2. **B** (spec, then wireframes — the spec edits define the wireframe edits).
3. **C** (M3 → M4 → M5 → M2 touches).

Done when:

- [x] `bin/rails db:migrate:reset && bin/rails test` green with the amended schema;
      Kindness seed slides carry titles + `suggested_seconds`.
- [x] `CLAUDE.md` data model matches `db/schema.rb`.
- [x] UX-SPEC view inventory count is correct (26, `/my` = view 14), and every route
      in the §3 nav diagram appears in the inventory and the §10 build mapping.
- [x] Wireframes: three new screens present; RTL toggle mirrors arrows/chevrons;
      no "35–40 min" ranges, no appbar EN chip, session-end copy consistent.
- [x] Grep test: every UI element in the wireframes that displays per-slide title or
      timing has a named data source in the spec (`Slide#title` /
      `Slide#suggested_seconds`).
- [x] M3/M4/M5 plans mention no state, column, or flow that contradicts UX-SPEC, and
      vice versa (spot-check: holding state, end confirmation, sweep retention,
      import `title:`/`time:` syntax, wake lock in M4).
