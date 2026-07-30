# Arête / Mīzān Platform — MVP Stack & Build Plan

**For:** Omar — solo dev, Rails-first, building with Claude Code
**Date:** 29 July 2026 · **Revision 2** — simplified scope
**Sources:** *Mīzān Curriculum Platform — Product Brief*, *One Lesson, End to End* (Kindness · Grade 6), *Developer Guide*, *Content Guide*, *Arête K12 Curriculum*

### Scope, as locked

| Decision | Effect on the build |
|---|---|
| Teacher-projected only, no student logins | No student accounts, no quizzes, no progress tracking. Minimal PII. |
| **No teacher customizations** of lessons or slides | **Deletes the single riskiest part of the previous design.** No override table, no stable-slide-key requirement, no fork-vs-overlay question. Lessons are read-only to teachers. |
| **Each presentation is a PDF**; teacher notes are a text field per slide | The "CMS" is an upload form and a notes table. No slide builder, no rich board editor, no per-slide layout. |
| **Companion device is in the MVP** — phone/tablet shows notes + small preview of the active slide, and drives the board | This is now the main engineering work. Sync must cross devices, so it goes over the server. |
| English-only, i18n-ready | Sibling rows per locale; one discipline in the CSS (§7). |
| Decent classroom wifi assumed | No offline packs. But the presenter still has to survive a dropped websocket — see §4. |
| Option A only | Rails monolith. No Payload/Directus comparison in this revision. |

**Net effect versus revision 1: the data model drops from 9 tables to 5, the authoring work drops from ~10 days to ~2, and the presenter grows from ~5 days to ~5 days but changes shape entirely.** Total estimate falls from 4–6 weeks to **2.5–3 weeks**.

---

## 1. Stack

| Layer | Choice | Version (checked July 2026) | Notes |
|---|---|---|---|
| Framework | **Rails 8.1.3**, **Ruby 4.0.6** | Rails 8.1.3 (2026‑03‑24) | Pin Ruby 4.0.6 (current). *(Revised from 3.4.10 — decision taken to build on Ruby 4; some gems' compatibility matrices may lag, so verify at bundle install.)* |
| Database | **PostgreSQL 16/17** | — | One database for app data, jobs, cache, and websocket pub/sub. |
| Jobs / cache | **Solid Queue** (Puma plugin) **+ Solid Cache** | Rails 8 defaults | No Redis. Solid Queue in-process keeps you to a single web service. |
| **Websocket pub/sub** | **ActionCable `postgresql` adapter** — *not* Solid Cable | Rails 8.1.3 built-in | See §4. This is a change from revision 1 and it matters. |
| Auth | `bin/rails generate authentication` | Rails 8.0+ | Also generates a `connection.rb` for ActionCable that works out of the box. Add invitations yourself (one model, one mailer). |
| Authorization | **Pundit 2.5.2** | 2.5.2 | Three roles: `super_admin / school_admin / teacher`. |
| CSS | **Tailwind 4.3.3** via tailwindcss-rails 4.6.0 | 4.6.0 (2026‑06‑17) | §7 has the one rule that makes Arabic cheap later. |
| JS | **Hotwire only — Stimulus + Turbo, on importmap** | Propshaft 1.3.2, importmap-rails 2.2.3 | **Drop React and vite_rails from the MVP.** With slides as preloaded images and the hot path being "show page N", the board and companion views are ~150 lines of Stimulus each. No build step at all. If the companion UI grows real complexity later, add `vite_rails` + `turbo-mount` then — it's additive, not a rewrite. |
| PDF → images | **`poppler-utils`** (`pdfinfo` + `pdftoppm`) | — | Exact invocations in §3. |
| Images | ruby-vips 2.3.0 / image_processing 2.0.2 | — | Only for the small companion-preview variant. |
| Storage | Active Storage → **Cloudflare R2** | — | §6. |
| Search | Postgres `websearch_to_tsquery` + `text[]` tags with GIN | — | 260 rows. No search gem. |

**Deliberately not in the MVP:** teacher customizations · native slide builder · Google Slides embed · offline packs · admin dashboard · reflection capture · student anything · paper_trail · mobility · React.

---

## 2. Data model — five tables

```ruby
Track    slug (mizan|arete|ihsan), name, position

Unit     track_id, grade (integer, K=0), title, position

Lesson   unit_id, position, code, locale (en|ar), title,
         prime           text            # the read-before-you-teach brief
         close_prompt    text            # the exit question
         estimated_minutes integer
         tags            text[]  default: [], null: false   # GIN index — theme/virtue filters
         published_at    datetime                            # nil = draft
         UNIQUE (code, locale)
         has_one_attached  :deck          # the source PDF
         has_many_attached :materials     # handouts; filename is the label for MVP

Slide    lesson_id,
         page_number integer             # 1-based; IS the ordering — no separate position column
         notes       text                # the private teacher script for this slide
         UNIQUE (lesson_id, page_number)
         has_one_attached :image          # rendered board PNG (NOT a column)

TeachSession  lesson_id (nullable until paired),
              teacher_id (nullable until paired),
              pairing_code  string       # nulled on pair — single use
              current_page  integer default: 1, null: false
              paired_at, expires_at, last_seen_at
              INDEX on pairing_code WHERE pairing_code IS NOT NULL
```

Plus the org tables the auth generator and roles need:

```ruby
School   name, country, timezone
User     school_id (NULLABLE — super_admins belong to no school),
         email, password_digest, role, ui_locale
```

### Why this shape

- **`page_number` is the ordering.** The PDF defines the sequence, so there is nothing to reorder and no need for a `position` column, drag-and-drop, or a deferrable unique constraint. This is the single biggest simplification the PDF decision buys you.
- **No `LessonEdition` table.** With one language at a time (*One Lesson, End to End* §1: the two languages are never on screen together), a locale is just a sibling `Lesson` row sharing a `code`. `UNIQUE (code, locale)` is the whole i18n data model.
- **No teacher override table**, and therefore **no stable-slide-key requirement**. Re-importing a deck can freely delete and recreate `Slide` rows — nothing points at them. This was the sharpest trap in revision 1 and your scope decision removes it outright.
- **`published_at` instead of a status enum.** `nil` means draft. `scope :published, -> { where.not(published_at: nil) }`. If the curriculum team later needs to revise a live lesson without teachers seeing half-finished edits, that's the point to add a draft mechanism — not now.
- **Materials as `has_many_attached` with no metadata.** The filename is the label. Real tradeoff: you can't have a label like "Reading — Frankfurt excerpt" for a file called `handout3.pdf`, so tell authors to name files well. If that chafes, promoting it to a `Material` model later is a one-hour migration.
- **`TeachSession` is persisted, not ephemeral.** That's what makes reconnection trivial: a phone that drops re-reads `current_page` from the row instead of needing message replay.

---

## 3. The "CMS" — an upload form and a notes table

Three screens total. This is genuinely small.

**1 · Lesson form.** Title, code, locale, grade/unit placement, `prime`, `close_prompt`, estimated minutes, tags, materials, and a PDF upload. Standard Rails scaffold territory.

**2 · Deck ingest (background job).** On PDF attach:

```bash
pdfinfo deck.pdf                      # → parse /^Pages:\s+(\d+)/ ; ~8ms
# then per page N:
pdftoppm -png -singlefile -f N -l N -scale-to-x 1920 -scale-to-y 1080 deck.pdf out/page
```

Then upsert one `Slide` per page with that `page_number`, preserving any `notes` already typed for that page number (so a re-upload of a corrected deck doesn't wipe the scripts). Measured: **~1.3s and ~27MB peak RSS for a 15-page vector deck**; photo-heavy decks run 2–5× slower. A background job is right, but this is a seconds-long job, not a minutes-long one.

Three flags worth understanding, because two of them are traps:

- **`-singlefile` is not optional.** Without it, `pdftoppm`'s output filename zero-padding is derived from the document's **total page count, not the requested range** — a 15-page deck renders `page-07.png` but a 120-page deck with `-f 7 -l 7` renders `page-007.png`. Hardcoding `%02d` breaks on long decks. `-singlefile` writes exactly `page.png`, byte-identical output, no digits to guess.
- **`-scale-to-x 1920 -scale-to-y 1080` beats picking a DPI.** A 16:9 slide is 13.333×7.5in, so 150 DPI gives 2000×1125 — fine, but geometry-dependent. Explicit target pixels are exact regardless of page size. Caveat: giving both x and y *stretches* a non-16:9 page, so if the Mīzān team might deliver 4:3 decks use `-scale-to 1920` and letterbox in CSS instead.
- Consider `-jpeg -jpegopt quality=85` for photo-heavy decks — the PNGs will otherwise be megabytes per page.

**3 · Notes table.** One row per page: a thumbnail, the page number, and a `<textarea>` for `notes`. Autosave on blur via a small Turbo form. That is the entire authoring interface for teacher scripts — no nested forms, no `<template>` + `child_index` Stimulus controller, none of the machinery revision 1 needed, because slides are created by the ingest job rather than by the author.

**Also build `rake lessons:import[path]`.** The Mīzān team already drafts in Google Docs (Content Guide §10). A structured Markdown/YAML file per lesson — header fields, `prime`, `close_prompt`, and a `notes` block per page number — plus the deck PDF is a much faster path for 260 lessons than typing into the web form, and it makes the curriculum diffable in git. This is the highest-leverage thing Claude Code can build for you, and it's an afternoon now that there are no override keys to preserve.

---

## 4. The presenter — board + companion device

This is the real work, and companion-device support changes the architecture from revision 1. BroadcastChannel is dead here: it only reaches windows in the same browser profile on the same machine. Sync now goes through the server.

### Pairing flow

Board-first, like casting to a TV — so nothing has to be typed on a shared classroom PC except a bookmarked URL.

1. **Classroom PC** opens `arete.app/board`. The server creates a `TeachSession` with a `pairing_code`, sets a **signed cookie** on that device holding the session id, and renders the code in large type. The board subscribes to the session's channel.
2. **Teacher's phone** (logged in) opens the lesson → **Teach** → enters the code. `POST /teach_sessions/pair` finds the unclaimed, unexpired session, sets `lesson_id` + `teacher_id`, and **nulls `pairing_code`** (single use).
3. The board receives the pair event and navigates to the paired lesson's board view, which renders **every page image at once, preloaded and hidden**.
4. The phone renders **every page's notes at once**, plus a small preview variant of each image, and shows notes for `current_page`.
5. **Prev/Next on the phone** → `PATCH /teach_sessions/:id` → broadcast `{ page: N }` → both devices reveal page N from content already in the DOM.

### Why "preload everything, broadcast only the page number"

Four things fall out of this one decision, and it's the crux of the design:

- **No private data ever crosses the channel.** The board is an unauthenticated subscriber (it's a projector — nobody should type a password on a classroom PC). If the broadcast payload contained notes, the board would receive the teacher's private script. Because notes are rendered server-side into the phone's HTML at load, the channel payload is `{page: N}` and nothing else. **Make this an explicit rule in `CLAUDE.md`** — it's the kind of thing that quietly regresses.
- **A dropped websocket doesn't blank the projector.** All images are already loaded, so the board just stays on the current slide. Teaching continues.
- **State is absolute, not a delta.** Broadcast `{page: 7}`, never `"next"`. ActionCable has no replay or buffering, so a missed message self-heals on the next tap. (Solid Cable retains rows but does *not* replay them to reconnecting subscribers — don't mistake its table for a backlog.)
- **Advancing a slide is a CSS class toggle**, not a render. No flash, no reflow, no server-rendered HTML on the hot path.

### Use the `postgresql` cable adapter, not Solid Cable

Solid Cable is **pure polling** — a `SELECT` against `solid_cable_messages` every `polling_interval` (default 0.1s), no `LISTEN/NOTIFY` anywhere. At 0.1s it's perfectly usable (adds 50ms mean, 100ms worst-case; measured ~146ms round trip at 250 virtual users), but you're on Postgres already and Rails' built-in `postgresql` adapter uses **`LISTEN/NOTIFY` with sub-millisecond fan-out and no polling load at all**. For an interactive tap-to-advance there's no reason to take the polling hit.

```yml
# config/cable.yml — set this in EVERY environment
development:  { adapter: postgresql }
test:         { adapter: test }
production:   { adapter: postgresql }
```

⚠️ **Two deployment landmines here, both of which produce "works on my laptop, broken in production":**

1. **`rails new` does not wire this up.** The generated `cable.yml` is `async` in development and `redis` in production. `async` is **per-process** — the moment you run 2+ Puma workers, the phone and the board land in different processes and the board never advances. Set `postgresql` in development too, not just production, or you won't see the bug until you deploy.
2. **The PG cable adapter is incompatible with PgBouncer transaction-mode pooling**, because `LISTEN` needs a session-pinned connection. Revision 1 told you to enable Render's integrated pooler on port 6432 — **don't, at MVP scale.** Basic-1GB gives you 100 connections and you have tens of teachers; point Rails at 5432 directly. If you ever do need the pooler, give `cable.yml` its own direct-port URL, or switch that one component to Solid Cable (which is polling-based and therefore pooler-safe — its one real advantage).

### Channel authorization

The board is unauthenticated but must only be able to subscribe to *its own* session. There is no official Rails pattern for a mixed authenticated/token setup (rails#30917 was closed with "ask on StackOverflow"), but the building blocks are solid:

```ruby
# app/channels/application_cable/connection.rb — permissive; authorize in the channel
identified_by :current_user, :board_session

# app/channels/teach_session_channel.rb
def subscribed
  session = TeachSession.find_signed!(params[:token], purpose: :board_stream)
  reject and return if session.expires_at.past?
  stream_for session
end
```

The board's page embeds `session.signed_id(purpose: :board_stream, expires_in: 12.hours)`, passed in the **subscription params** — not the cable URL, which lands in proxy logs and APM traces.

Four rules:

- **Never `stream_from "session_#{params[:id]}"`.** Any socket past `connect` could then subscribe to any session by guessing an integer. Verify a signed token, derive the stream name server-side. This is a well-known ActionCable vulnerability class.
- **A signed stream name is authentication, not authorization, and is not revocable.** Always pair `find_signed!` with `expires_in:` *and* a live check in `subscribed`.
- **Bind the pairing code to the board's signed cookie** so a code visible across a room can't be redeemed from a different device.
- **Rate-limit the pairing endpoint on two axes.** `rate_limit` (Rails **7.2+**, not 8 as many posts claim) is a fixed window, so stack two named limits — one by IP, one by the submitted code, since a distributed guesser defeats IP limiting trivially:

```ruby
rate_limit to: 5,  within: 1.minute, name: "burst"
rate_limit to: 20, within: 1.hour,   name: "hourly"
rate_limit to: 10, within: 1.hour,   by: -> { params[:code].to_s.upcase }, scope: :pairing
```

Two gotchas: `rate_limit` needs a cache store with atomic `increment` — **Solid Cache has it**, so no Redis — but the generated `development.rb` uses `:memory_store`, which is per-process and silently gives you 3× your limit under 3 workers. And a store returning `nil` disables rate limiting **with no error or warning**, so never point it at `:null_store`.

And **use entropy, not just rate limits**: 6 digits is 10⁶ (weak). Six characters of Crockford base32 — `SecureRandom`, ambiguous glyphs like `0/O` and `1/I/L` excluded, upcased on lookup — is ~1.07×10⁹. Expire codes in 2–5 minutes.

### Reconnection

ActionCable's JS client handles more of this than you'd expect. Verified behaviour in 8.1.3:

- Auto-reconnect with a 6-second stale threshold (two missed 3s pings) and exponential backoff stretching to ~24s.
- It registers a **`visibilitychange`** listener that reconnects ~200ms after the tab becomes visible — which is exactly the phone-unlock case, so wake is near-immediate rather than waiting out backoff. Expect a hard disconnect on iOS lock (WebKit suspends websockets when backgrounded); the board, screen on, stays up.
- **No `online`/`offline` listeners exist.** A wifi→cellular switch with the screen on is only caught by the 6s stale threshold. Add your own `window.addEventListener("online", () => consumer.connection.reopen())`.
- Resync on reconnect with the `connected({ reconnected })` callback (Rails 7.1+):

```js
connected({ reconnected }) { setStatus("connected"); if (reconnected) this.resync() }
disconnected({ willAttemptReconnect }) { setStatus("disconnected") }
rejected() { setStatus("rejected") }
```

`resync()` is just "re-read `current_page`" — cheap, because state is absolute and persisted on `TeachSession`.

### Fallbacks, which are not optional

The companion device is now on the critical path for teaching. Three cheap insurance policies:

1. **A visible connection indicator on the phone.** A teacher needs to know the tap didn't land *before* they're standing in silence.
2. **Keyboard nav on the board** (←/→/space/Esc). If the phone dies, the teacher walks to the PC and keeps going.
3. **A print stylesheet for the notes.** The brief explicitly lists "a printed sheet" as a valid teacher surface — one stylesheet, and it's real insurance against a dead projector or a dead phone.

### Dual display comes free

A `TeachSession` doesn't care what kind of device the board is. The teacher opens `/board` in a second window on their own laptop, pairs it with the code, and drags it to the projector — identical code path, zero extra work. Add one nicety on the board page: a **"Go fullscreen"** button. It has to be a button rather than automatic, because `requestFullscreen()` needs transient user activation *in that document* and a freshly opened window has none — the `window.open(…, 'fullscreen')` shortcut that would have solved this was abandoned by the W3C in March 2024. On Chromium you can additionally use `getScreenDetails()` to place the window on the external display automatically; Firefox and Safari get "drag it over and press F11."

---

## 5. Build sequence for Claude Code

Write `CLAUDE.md` first. Four things belong in it: the data model above, **"the cable payload is `{page: N}` and never contains notes"**, the RTL utility rule from §7, and **"no student PII, ever."**

| # | Milestone | Days |
|---|---|---|
| **M0** | **Skeleton.** `rails new arete --database=postgresql --css=tailwind`. Auth generator, Pundit, three roles. Solid Queue via the Puma plugin. **`cable.yml` → `postgresql` in all environments.** Deploy to Render Frankfurt immediately — a deployed hello-world on day one beats a perfect local app on day thirty. | ½ |
| **M1** | **Model + seed.** The five tables. Seed the real Arête K12 tree from the curriculum PDF, and the full Kindness · Grade 6 lesson from *One Lesson, End to End* — **use that lesson as the fixture everywhere.** It's a complete worked specimen and it will catch modeling mistakes the abstract schema hides. | 1 |
| **M2** | **Library + lesson page.** Server-rendered `Track → Grade → Unit → Lesson` tree, search, tag/grade filters. Lesson page per Mockup A: breadcrumb, title, chips, prime block, page thumbnails, materials, **Teach** button. *This is the first thing you can show the Mīzān team.* | 2–3 |
| **M3** | **Deck ingest + notes editor.** `pdfinfo`/`pdftoppm` job, slide upsert preserving existing notes, the notes table with autosave, and `rake lessons:import`. | 2 |
| **M4** | **Board + companion.** ⭐ The real work. Pairing (codes, signed cookie, rate limits), `TeachSessionChannel` with signed-id auth, board view with all images preloaded, phone view with all notes + preview variants, `{page: N}` broadcast, connection indicator, `connected({reconnected})` resync, keyboard nav, fullscreen button. | 4–5 |
| **M5** | **Polish + verification.** Print stylesheet, empty states, teacher invitations, `/up`, R2 + Cloudflare wiring, off-box Postgres backups. System tests for: pair → advance → both devices agree; **pairing code is single-use and expires**; **cable payload contains no notes**; deck re-upload preserves notes; board survives a killed websocket. | 2 |

**Total: 11.5–13.5 focused days — call it 2.5–3 weeks with real-life slack.**

Two ordering notes. **Do M4 before M3 if you want the scariest thing de-risked first** — you can hand-seed one lesson's slides in M1 and prove the two-device sync works on real classroom hardware before investing in authoring. Given that companion sync is the one genuinely novel piece here, that's what I'd do. And **test M4 on the actual classroom wifi early**, not at the end; it's the only requirement in this document that a laptop on your own network cannot validate.

---

## 6. Hosting

Unchanged from revision 1, with one correction that the cable adapter forces.

**Frankfurt is the right origin.** No major PaaS has an Egypt region, but Egypt's international transit lands at Alexandria and runs north to Marseille/Frankfurt/Milan; Gulf regions often route via Europe anyway, cost more, and have no cheap Rails PaaS. What actually helps classroom delivery is a CDN PoP inside Egypt — **Cloudflare has had a Cairo PoP since late 2015**; Bunny.net also lists Cairo, on its ISP-network tier.

**MVP: ~$23/mo**

| Item | Cost |
|---|---|
| Hetzner CX33 (4 vCPU / 8 GB / 80 GB), Falkenstein | ~$10 (€8.49 + €0.50 IPv4, post-15 Jun 2026 pricing) |
| Hatchbox.io — manages Postgres, backups, Solid Queue, cron, SSL, zero-downtime deploys | $10 |
| Cloudflare R2 (~100 GB stored, **zero egress**) | ~$1.50 |
| Cloudflare CDN (Free — Cairo PoP) | $0 |
| Domain | ~$1 |
| **Total** | **~$23/mo** |

The 8 GB is for `pdftoppm` + Vips headroom during ingest.

**Zero-ops alternative: Render Frankfurt, ~$26/mo** — Web Starter $7 + Postgres Basic-1GB $19, Solid Queue in the Puma plugin. Two caveats:

- **Do not enable Render's integrated connection pooler** (port 6432) — `LISTEN/NOTIFY` needs a session-pinned connection and PgBouncer transaction mode breaks it. 100 connections is ample at this scale. Connect on 5432.
- Render Starter is **512 MB / 0.5 CPU**. Fine for serving and for websockets, but not for bulk deck ingest — run `rake lessons:import` locally against production storage, or size a Standard worker (2 GB, $25) if authors need to upload decks through the web UI.

Never serve slide images through Render's own bandwidth ($0.15/GB overage) — always R2 behind Cloudflare, where egress is $0.

**Rejected:** Fly.io (Managed Postgres is $38/mo for 1 GB) · Heroku (EU region is Dublin, worse for Cairo) · Railway ($0.05/GB egress, fully metered) · Kamal 2 on a bare VPS (cheapest, but Docker's iptables rules bypass UFW, Docker volumes aren't backed up, and health-check failures produce mystery rollbacks — the ~$10/mo Hatchbox delta is the best money on this page) · Vercel/Netlify (egress, no ME region).

**Two things to do regardless.**

**Measure the CDN before committing.** Cloudflare's Cairo PoP is real but Egyptian ISPs have a documented history of routing to Amsterdam/Frankfurt instead. Test from a Cairo school on TE Data, Orange Egypt *and* Vodafone Egypt against a Cloudflare-fronted URL, a Bunny-fronted URL, and the bare origin. If Cloudflare doesn't land on Cairo, switch media to Bunny (MEA egress $0.06/GB) keeping R2 as origin. App hosting doesn't change.

**Egypt's PDPL deadline is close.** Law **151/2020**'s Executive Regulations (Decree 816/2025) were issued 1 Nov 2025 and publicly released 25 Dec 2025, starting a one-year compliance grace period — read as **1 Nov 2026**, roughly three months out, though the issuance/publication gap leaves the exact date contested (some practitioners read October 2026). Assume the earliest. Cross-border transfers need a PDPC permit and you'll be transferring to Germany under every viable host. Entities processing 1–100,000 records are exempt from licensing fees (Art. 19), so year one is fine on that axis. **Your no-student-accounts decision is worth more to your compliance posture than any region choice** — children's data carries explicit written-guardian-consent requirements for under-15s and a prohibition on profiling (Art. 15). Keep teacher PII minimal and get local counsel on the transfer permit before the first school contract.

---

## 7. The one discipline that keeps Arabic cheap

English-only is the right MVP call. Arabic stays cheap if you hold three rules from commit one, and gets expensive if you don't:

1. **Never write a directional CSS utility.** `ms-4` not `ml-4`, `pe-2` not `pr-2`, `start-0` not `left-0`, `text-start` not `text-left`. Tailwind 4.3.3 maps these to `margin-inline-start` etc. and ships `rtl:`/`ltr:` variants. Put the rule in `CLAUDE.md` **and add a CI grep broad enough to matter** — margins are the least of it:

   ```
   \b-?[mp][lr]-
   \b(left|right)-
   \btext-(left|right)\b
   \b(border|rounded|float|divide|space|inset)-(x-|[lr]\b|t[lr]\b|b[lr]\b)
   ```
   Allowlist deliberate physical uses (a chevron that shouldn't mirror) with an inline `rtl-ok` comment. Claude Code will reach for `ml-4` by habit — the grep is the only thing that actually enforces this.
2. **`<html lang="<%= I18n.locale %>" dir="<%= rtl? ? "rtl" : "ltr" %>">` in the first layout.** Then the whole flip is one attribute, exactly as *One Lesson, End to End* Figure 1 describes.
3. **Every user-visible string in `config/locales/en.yml` from day one.** Zero hardcoded English in views.

No `mobility` needed: a locale is a sibling `Lesson` row.

---

## 8. The short version

Rails 8.1.3 + Postgres + Hotwire, **no React**, five tables, PDF decks rasterized to per-page PNGs by `pdftoppm -singlefile`, notes as a plain text column, no teacher customizations. The presenter is a persisted `TeachSession` that any number of devices pair into with a single-use code; **every page image and every note is preloaded on load, and the only thing that crosses the websocket is `{page: N}`** — which is simultaneously why the projector survives a network blip, why advancing a slide is a class toggle, and why the unauthenticated board can never receive the teacher's private script. ActionCable on the `postgresql` adapter, set in every environment, with the pooler off. R2 + Cloudflare for media. Render Frankfurt now, Hatchbox + Hetzner when the bill matters.

**Three things most likely to bite you, all cheap to get right now:** `cable.yml` left on `async` in development (works locally, silently broken under multiple Puma workers) · the PgBouncer/`LISTEN` incompatibility · and `pdftoppm`'s filename padding, which is derived from the deck's total page count and not the page you asked for.
