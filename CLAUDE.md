# CLAUDE.md — Arête / Mīzān Platform

Rails monolith serving a read-only K-12 curriculum library plus a classroom presenter:
a projector "board" and a paired teacher phone ("companion") that drives it over
ActionCable. Teachers project lessons; there are **no student logins and no teacher
customizations**. Full rationale in `docs/STACK-DECISION.md` — read it before making
architectural changes.

## Non-negotiable rules

1. **The cable payload is `{ page: N }` and never contains notes.** The board is an
   unauthenticated subscriber (a projector). Teacher notes are rendered server-side
   into the authenticated phone's HTML at page load, never broadcast. Any change that
   puts notes, titles, or other lesson content on the wire is a bug.
2. **No student PII, ever.** No student accounts, names, progress, or reflection
   capture. Keep teacher PII minimal (email, name, role). This is a legal posture
   (Egypt PDPL 151/2020), not just a scope choice.
3. **Never write a directional CSS utility.** `ms-4` not `ml-4`, `pe-2` not `pr-2`,
   `start-0` not `left-0`, `text-start` not `text-left`. Same for `border-`,
   `rounded-`, `inset-`, `divide-`, `space-`, `float-`. Deliberate physical uses
   (e.g. a chevron that must not mirror) get an inline `rtl-ok` comment.
   `bin/lint-rtl` enforces this; it runs in CI.
4. **Every user-visible string lives in `config/locales/en.yml`.** Zero hardcoded
   English in views. A locale is a sibling `Lesson` row, not a translation gem —
   don't add `mobility`.
5. **Broadcast absolute state, never deltas.** `{ page: 7 }`, never `"next"`.
   ActionCable has no replay; a missed message must self-heal on the next tap.
   `TeachSession.current_page` in the DB is the source of truth; clients resync
   from it on reconnect.

## Stack (pinned)

- Rails 8.1.3, Ruby 3.4.10 (do **not** bump to Ruby 4.x)
- PostgreSQL only: app data, Solid Queue jobs (in Puma), Solid Cache, and
  ActionCable pub/sub
- ActionCable `postgresql` adapter (LISTEN/NOTIFY) — **not** Solid Cable, **not**
  `async`. `config/cable.yml` must say `postgresql` in development *and* production
  (`test` adapter in test). `async` is per-process and breaks silently under
  multiple Puma workers.
- **No PgBouncer / transaction-mode pooling** on the cable's connection —
  `LISTEN` needs a session-pinned connection. Connect Postgres on 5432 directly.
- Hotwire only (Turbo + Stimulus on importmap, Propshaft). No React, no Vite,
  no build step.
- Pundit for authorization. Roles: `super_admin` / `school_admin` / `teacher`.
- Tailwind 4 via tailwindcss-rails. Active Storage → Cloudflare R2.
- Search: Postgres `websearch_to_tsquery` + `text[]` tags with a GIN index.
  No search gem (~260 lessons).

## Data model (5 content tables + org)

```
Track        slug (mizan|arete|ihsan), name, position
Unit         track_id, grade (int, K=0), title, position
Lesson       unit_id, position, code, locale (en|ar), title, prime,
             close_prompt, estimated_minutes, tags text[], published_at
             UNIQUE (code, locale) · has_one_attached :deck · has_many_attached :materials
Slide        lesson_id, page_number (1-based, IS the ordering), notes
             UNIQUE (lesson_id, page_number) · has_one_attached :image
TeachSession lesson_id?, teacher_id?, pairing_code (nulled on pair),
             current_page (default 1), paired_at, expires_at, last_seen_at

School       name, country, timezone
User         school_id (nullable — super_admins have none), email,
             password_digest, role, ui_locale
```

Invariants:
- `page_number` **is** the ordering. No `position` column on slides, no reordering UI.
- Deck re-ingest may delete/recreate `Slide` rows freely — nothing references them —
  but must **preserve `notes` by page_number** so re-uploading a corrected PDF
  doesn't wipe teacher scripts.
- `published_at: nil` = draft. `scope :published, -> { where.not(published_at: nil) }`.
  No status enum.
- A locale is a sibling `Lesson` row sharing `code`. `UNIQUE (code, locale)` is the
  entire i18n data model.
- Material labels are filenames. Don't add a Material model in MVP.

## Presenter architecture (M4)

- Board (classroom PC) opens `/board` unauthenticated → gets a `TeachSession`, a
  signed cookie, and a pairing code. Phone (logged-in teacher) redeems the code —
  single use, nulled on pair, bound to the board's signed cookie.
- Pairing codes: 6 chars of Crockford base32 via `SecureRandom` (no `0/O/1/I/L`),
  upcased on lookup, expire in 2–5 minutes. Rate-limit pairing on **two axes**
  (by IP and by submitted code) with stacked `rate_limit` declarations.
  `rate_limit` needs a cache store with atomic increment — use Solid Cache in
  development too, never `:memory_store` (per-process) or `:null_store`
  (silently disables limiting).
- Channel auth: **never** `stream_from "session_#{params[:id]}"`. The board page
  embeds `session.signed_id(purpose: :board_stream, expires_in: 12.hours)` passed
  in subscription params (not the cable URL — that leaks into proxy logs).
  `subscribed` does `find_signed!` **plus** a live `expires_at` check, then
  `stream_for session`.
- Board preloads **every** page image hidden in the DOM; phone preloads all notes +
  preview variants. Advancing a slide is a CSS class toggle, never a server render.
  A dropped websocket therefore never blanks the projector.
- Reconnect: use `connected({ reconnected })` to re-read `current_page`. Add a
  `window.addEventListener("online", …)` reopen — ActionCable's client has no
  online/offline listeners. Board keeps keyboard nav (←/→/space/Esc) as fallback.

## Gotchas that will bite

- `pdftoppm` **must** use `-singlefile` — without it, output filename zero-padding
  derives from the deck's *total* page count, not the requested page.
- Use `-scale-to-x 1920 -scale-to-y 1080` (or `-scale-to 1920` + CSS letterbox if
  non-16:9 decks appear), not DPI.
- `rails new` generates `cable.yml` as `async` in dev — it must be overwritten
  (see stack section) or multi-worker sync bugs stay invisible until production.
- Never serve slide images through app-host bandwidth — always R2 behind Cloudflare.

## Commands

- `bin/dev` — run app (Puma + Tailwind watcher; Solid Queue runs inside Puma)
- `bin/rails test` / `bin/rails test:system` — tests
- `bin/lint-rtl` — grep for forbidden directional CSS utilities (CI-enforced)
- `bin/rails lessons:import[path]` — import a lesson from Markdown/YAML + deck PDF

## Deliberately out of scope (do not add)

Teacher customizations · slide builder · student anything · offline packs ·
admin dashboard · reflection capture · paper_trail · mobility · React · Redis.
