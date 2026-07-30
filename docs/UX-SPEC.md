# Arête / Mīzān — UX Specification

**Companion file:** `docs/ux-wireframes.html` — open it in a browser. The key screens are drawn there, with light/dark and LTR/RTL toggles.
**Scope:** MVP (M0–M5) in full detail; phase-2 screens listed so navigation never needs redesigning.
**Date:** 29 July 2026

---

## 1. The one idea this design is built on

**There are two modes, and they are used minutes apart in opposite conditions.**

| | **Browse mode** | **Teach mode** |
|---|---|---|
| When | Lesson prep, at a desk, lights on | In class, room dimmed, facing a projector |
| Devices | Laptop / desktop | Phone (companion) + classroom PC (board) |
| Attention | Reading, comparing, deciding | 2-second glances while talking to thirty children |
| Chrome | Full app navigation | **None at all** |
| Theme | **Light** — parchment, from the Mīzān brief's own palette | **Dark, always** |
| Failure cost | Mild annoyance | Standing in silence in front of a class |

Teach mode is **dark by hard-coding, not by `prefers-color-scheme`.** A teacher whose phone is set to light mode should still get a dark companion: a white phone screen in a darkened classroom blinds the teacher and distracts the students in the front row. This is a property of the situation, not a user preference.

Everything else in this document follows from that table. Where a decision looks odd, check it against the row it came from.

---

## 2. Complete view inventory

Twenty-six views for the MVP. Marked ⭐ are the three that carry the product.

### 2.1 Unauthenticated

| # | View | Route | Notes |
|---|---|---|---|
| 1 | Sign in | `/session/new` | No public sign-up — say so explicitly, or people hunt for it |
| 2 | Forgot password | `/passwords/new` | Auth generator |
| 3 | Reset password | `/passwords/:token/edit` | Auth generator |
| 4 | Accept invitation | `/invitations/:token` | Set name + password. **Show which school and role you're accepting** — it's the only time a teacher sees this |
| 5 | Board — waiting to pair | `/board` | Unauthenticated, scoped by signed cookie |
| 6 | Errors | 404 / 422 / 500 | In-brand, not the Rails default page |

### 2.2 Browse — teacher

| # | View | Route | Notes |
|---|---|---|---|
| 7 | Library home | `/` | Track cards + search + "continue teaching" |
| 8 | Scope & sequence | `/tracks/:slug` | Grade rail → units → lesson rows |
| 9 | Search results | `/?q=…&grade=…&tags[]=…` | Bookmarkable; flat list with per-row breadcrumbs |
| 10 | **Lesson page** ⭐ | `/lessons/:id` | The hub. Mockup A |
| 11 | Slide preview lightbox | (overlay on 10) | Slide large + its script, for pre-class review |
| 12 | Printed script | `/lessons/:id/print` | M5 |
| 13 | Account settings | `/settings` | Name, email, password, UI locale |
| 14 | My lessons | `/my` | Recently taught, derived from teach-session history (§5.8) — no saved list in MVP. Ships in M5 |

### 2.3 Teach mode

| # | View | Route | Surface |
|---|---|---|---|
| 15 | Enter pairing code | `/lessons/:id/teach` | Phone |
| 16 | Board — paired / holding | `/board` (paired) | Projector — neutral until the teacher starts |
| 17 | Board — teaching | `/board` (live) | Projector — slide only |
| 18 | Companion — pre-flight | `/teach_sessions/:id/companion` | Phone — the Prime, one uninterrupted screen |
| 19 | **Companion — teaching** ⭐ | same | Phone |
| 20 | Session ended | same | Phone — shows the Close prompt |

### 2.4 Authoring — admin (`/admin`, super_admin)

| # | View | Route | Notes |
|---|---|---|---|
| 21 | Lesson index | `/admin/lessons` | Filters + **authoring-completeness column** |
| 22 | Lesson form + deck ingest | `/admin/lessons/:id/edit` | Metadata, PDF upload, materials |
| 23 | **Notes editor** ⭐ | `/admin/lessons/:id/notes` | One row per page, autosave on blur |
| 24 | Structure (tracks/units) | `/admin/structure` | The tree; rarely touched |

### 2.5 People — school_admin / super_admin

| # | View | Route |
|---|---|---|
| 25 | People & invitations | `/admin/people` |
| 26 | Schools | `/admin/schools` (super_admin only) |

### 2.6 Phase 2 — reserve the space, don't build

Pacing view (a class's progress through the sequence) · **saved / bookmarked lessons** (in MVP, "My lessons" is recents-only — see §5.8) · admin dashboard & usage analytics · offline pack manager · Arabic-edition coverage report · certified-trainer role · teacher onboarding / quick-start.

**Only one of these needs a top-level nav slot: Pacing.** Everything else lives under `/admin`. Design the teacher nav as two items now and three later — never more.

---

## 3. Navigation structure

```
BROWSE MODE  ── app chrome, light
│
├── Library                    /                    ← default
│   ├── Track                  /tracks/:slug
│   │   └── Lesson             /lessons/:id  ⭐
│   │       ├── Slide preview  (overlay)
│   │       ├── Print          /lessons/:id/print
│   │       └── ▶ TEACH ──────────────────────────┐
│   └── Search results         /?q=…              │
├── My lessons                 /my                │  ← recently taught, not a 2nd library
└── ▾ Account                                     │
    ├── Settings               /settings          │
    ├── Admin ⚙                /admin             │  ← only if super/school admin
    └── Sign out                                  │
                                                  │
TEACH MODE  ── no chrome, dark  ←─────────────────┘
│
├── Enter code       /lessons/:id/teach      (phone)
├── Pre-flight       …/companion             (phone)
├── Teaching         …/companion             (phone)  ⭐
└── End session ─────────────────────► back to Library

BOARD  ── separate device, no user, no nav
└── /board   waiting → paired → teaching → ended → waiting
```

### Rules

1. **Teacher nav is two items, permanently.** Library, My lessons. Every extra item is a decision a teacher makes at 7:50am. Admin appears in the account menu only for those who have it.
2. **Teach is a mode, not a page.** Entering it replaces the entire chrome; exiting is deliberate ("End"). There is no app navigation inside teach mode — a teacher cannot accidentally navigate away mid-lesson.
3. **Admin has visually distinct chrome** — darker bar, an "Admin" mark, its own four-item nav (Lessons · Structure · People · Schools). It must never be ambiguous which mode you're in, because the same person switches between them.
4. **The board has no navigation at all.** It's an output device. Its only interactions are the fullscreen button and keyboard fallback.
5. **Everything filterable is a GET query param.** Search and filter state lives in the URL so it's bookmarkable and shareable — a head of department sends a colleague a link to "Grade 6, kindness".

---

## 4. Screen-by-screen decisions worth defending

### 4.1 Lesson page — the hub

**The Prime sits above the slides.** The brief's central claim is that formation depends on the teacher's own readiness, not the content. Putting the read-before-you-teach brief above the fold, in an accented block, is that claim made structural.

**One primary button.** Teach is the only filled button on the page. Print, Download, and the locale switch are secondary. If everything is prominent, nothing is read.

**The EN/AR switch lives here, next to Teach — not in global settings.** Per *One Lesson, End to End* §1, language is chosen once, before teaching, and sets everything downstream. It belongs beside the decision it modifies. When no Arabic sibling row exists, **grey it out rather than hiding it** — a hidden feature is never discovered.

**Slide thumbnails are clickable.** Not in the brief, but a teacher reviewing at their desk needs slide 5 large with its script before deciding how to handle the silence. It's a lightbox over content already on the page.

**Admins see drafts inline with a Draft chip.** Teachers don't see them at all — that's `policy_scope`, not a CSS class, and M2 tests it.

### 4.2 Board — waiting to pair

The pairing code is set at ~78px because it must be legible from wherever the teacher is standing. Three details:

- **Grouped `K7Q M2X`** — six unbroken characters are hard to read across a room.
- **Crockford base32 excludes `0/O` and `1/I/L`**, so there is nothing to misread. Server-side, normalize `O→0` and `I/L→1` anyway.
- **`dir="ltr"` unconditionally.** Codes read left-to-right in both locales.

Show time remaining. A code that silently stops working is the most likely support call in the product.

### 4.3 Board — teaching

**The slide and nothing else.** No page counter (it tells students how much is left and changes how they listen), no branding, no cursor (hide after 2s idle), **no transitions** — a cross-fade on a projector reads as lag.

**The app cannot fix a bad slide.** These are rasterized PDF pages. That makes a **deck template spec a real deliverable for the Mīzān team**, and it's not in any current plan:

> 16:9 · minimum ~28pt body type · safe margins clear of projector overscan · high contrast · no thin weights · no hairline rules · nothing critical in the outer 5%.

A slide that reads fine on a designer's laptop is routinely illegible from the back row. This document is cheaper than discovering that after 260 lessons are built.

### 4.4 Companion — teaching ⭐

Every decision here traces to one sentence: *held one-handed, in a dim room, glanced at for two seconds while talking.*

| Decision | Reason |
|---|---|
| **Script at 20px / 1.62** — larger than any browse-mode body text | Readable without focusing. Do not shrink it to fit more on screen; fitting more is not the goal |
| **Stage directions visually distinct** | "Read it, then **stop**" is an instruction, not words to say. See §6 |
| **Next is large and thumb-reachable; Prev is deliberately smaller** | Forward is 95% of taps; an accidental backward tap is more disruptive than a missed forward one |
| **Elapsed time, not a countdown** — `02:30 / 03:00`, muted, never turns red | The brief wants suggested timing. Target comes from `Slide#suggested_seconds`; elapsed resets on advance; when a slide has no target, show elapsed only |
| **Slide title in the header, next-slide preview as one line of text** — both from `Slide#title` (fallback: "Slide N"), never a thumbnail | The teacher needs to know where they are and what's coming, not to see it |
| **End confirms before ending** — an in-page Turbo confirm ("End lesson? The board will clear."), never `window.confirm` | An accidental tap is otherwise unrecoverable — the pairing code was nulled on pair. Browser dialogs are banned in the companion (they block the cable) |
| **Offline navigation is script-browsing only** — local Prev/Next moves the script, never claims to move the board; on reconnect the phone resyncs to the server's `current_page` with a brief "back on slide N" notice | The class saw what the board showed; the phone must rejoin *that* reality, not assert its own |
| **Connection indicator always visible** | A teacher must learn a tap didn't land *before* standing in silence facing a stale slide |
| **Screen Wake Lock** — see §5 | Otherwise the phone locks after 30 seconds of talking |

### 4.5 Notes editor

One row per page: thumbnail, textarea, autosave on blur. No nested forms, no drag handles, no add/remove — because `page_number` *is* the ordering and the PDF defines it. This is the whole payoff of the PDF-as-deck decision.

Two additions worth the hour:

- **A per-row read-time or character estimate.** A note longer than the phone screen means scrolling mid-lesson — exactly what the companion exists to prevent.
- **Progress in the header** ("6 written · 2 empty"). Across 260 lessons this is the state that actually matters.

### 4.6 Admin lesson index

**The column that earns its place is authoring completeness** — `notes 2 / 6`. "Deck uploaded but scripts not written" is the most common half-finished state at 260 lessons and is invisible in a published/draft flag. Pair it with a locale column so the EN/AR gap shows on one screen; that gap is what will drift. (If the team adopts per-slide titles/timing as authoring targets, the completeness stat may count those too — optional; "notes 2 / 6" stays the headline.)

---

## 5. Things the plans don't cover yet

Ordered by how much they'll hurt if missed.

### 5.1 Screen Wake Lock — a genuine gap ⚠️

Nothing in M4 prevents the teacher's phone from locking mid-lesson. It will lock after ~30 seconds of talking, and **iOS suspends WebSockets when the screen locks** — so every unlock costs a reconnect and a resync. In a 40-minute lesson that's dozens of times.

```js
let lock = null
async function keepAwake() {
  try { lock = await navigator.wakeLock.request("screen") } catch {}
}
// The lock is released whenever the tab is hidden — re-request on return.
document.addEventListener("visibilitychange", () => {
  if (document.visibilityState === "visible" && sessionActive) keepAwake()
})
```

Show the awake state in the header so the teacher trusts it. Fall back silently where unsupported. **This belongs in M4, not a polish pass.**

### 5.2 A markup convention for stage directions

The Mīzān scripts already mix two registers — words to say, and things to *do* ("Read it, then stop. Count to ten before you speak"). On a phone glanced at for two seconds these must look different.

Recommend `**asterisks**` in the notes field, rendered as accented bold on the companion and bold in print. **Agree this with the Mīzān team during authoring** — it costs nothing now and is expensive to retrofit across 260 lessons.

The convention carries **stage directions only**. Slide titles and per-slide timing are *not* notes markup — they are `Slide` columns (`title`, `suggested_seconds`), set in the notes editor or the import file (see the M3 plan). Columns are queryable (next-slide preview, print, completeness stats) and survive re-ingest by the same preserve-by-`page_number` rule as notes.

### 5.3 The board holding state

Between pairing and slide 1 the board should show a neutral wordmark, not slide 1. Students shouldn't be reading the opening slide while the teacher is still settling the room. Slide 1 appears when the teacher taps **Start**, which makes the beginning of the lesson a deliberate act.

Schema implication: holding is `paired_at` present with `started_at: nil`; ended is `ended_at` present (`TeachSession` carries both columns). The board's resync endpoint returns `{ page, started, ended }` — not just the page — so a board that reconnects during pre-flight self-heals into the holding screen, never prematurely into slide 1.

### 5.4 Deck template spec

See §4.3. A one-page PDF for the curriculum team.

### 5.5 Alt text for slide images

Board images carry all the student-facing content and currently have no text alternative. Not an MVP blocker (the board is projected output, and `aria-hidden` on the board is defensible), but the lesson page's thumbnail grid and the print sheet are both genuinely inaccessible without it.

Cheapest honest fix: reuse the slide's `notes` as the thumbnail `alt` on the lesson page and mark the board images decorative. Alt text derived from notes must strip the `**…**` stage-direction markup — asterisks read aloud are noise. A dedicated `board_alt` column is phase 2 — note the decision so it's deliberate rather than forgotten.

### 5.6 Session recovery

The pairing code is nulled on pair, so a teacher whose phone dies mid-lesson cannot re-pair. Three layers, cheapest first:

1. **Board keyboard nav** (already in M4) — walk to the PC, use arrow keys.
2. **The printed script** (M5) — teach from paper.
3. **Session end auto-issues a fresh code.** On `{ended:}` (or the board's Esc shortcut) the board transitions itself back to the waiting screen with a new pairing code — no one touches the classroom PC. Recovery is therefore: end the session from any surviving surface and pair again with the code now on the wall.

Layer 3 falls out of the end-of-session flow and closes the loop.

### 5.7 Two more states the plans don't name

- **Deck processing** — the ingest job is async. The notes table should be live and typeable while pages render ("Rendering 9 of 15"), since notes survive re-ingest anyway.
- **Ingest failed** — a clear "poppler is not installed on the server", not a silent empty slide list. M3 requires the job to fail loudly; the UI has to show it.

### 5.8 My lessons — where the data comes from

"My lessons" (view 14) is derived, not curated: **paired `TeachSession` rows are retained as teaching history** (the sweep job deletes only expired *never-paired* sessions), and `/my` lists that teacher's distinct recently-taught lessons by `last_seen_at`. No saved/bookmark model in MVP — "saved" is phase 2 (§2.6).

Privacy posture, stated deliberately: this is **teacher** behavioural data (which lessons a teacher projected, when), scoped to the teacher's own account. It involves no student data of any kind, consistent with the platform's PDPL stance — no student PII, ever.

---

## 6. Design system

Full token list, component states, and swatches are rendered in `ux-wireframes.html` → **Design system**. Summary:

### Color

Light (browse) — parchment drawn from the brief's own print palette:

```
bg #FBF6EC · surface #FFFDF8 · surface-2 #F4EBDB · border #E3D7C2
ink #2A2723 · ink-strong #16304F · ink-muted #6E655A
accent #B5502E · success #2F6D4F · warning #8A5E10 · danger #A32C22
```

Dark (teach) — accent lightens to hold contrast:

```
bg #14171C · surface #1C2027 · border #333A45
ink #E8E2D8 (warm off-white, not pure white) · ink-muted #9AA1AC
accent #E0784F
```

Contrast: ink on bg 13.4:1, ink-muted 5.1:1, accent 5.9:1 — all AA. Dark accent 5.4:1 on dark bg.

### Type

| Role | Family | Size / line | Used for |
|---|---|---|---|
| Display | Fraunces 600 | 22–32 / 1.25 | Lesson titles, section heads |
| Prose | Spectral 400 | 16.5 / 1.7 | Prime, close prompt |
| **Script** | Spectral 400 | **20 / 1.62** | Companion notes — sized for a 2-second glance |
| UI | system sans | 13–15 / 1.5 | Chrome, chips, tables, forms |
| Numeric | system sans, `tabular-nums` | — | Page counts, timers, codes |
| Arabic prose | Noto Naskh Arabic | +1px, line-height +0.15 | Arabic needs more leading at the same optical size |

### Spacing, radius, motion

- Spacing `4 · 8 · 12 · 16 · 24 · 32 · 48 · 64`. Nothing between steps.
- Radius `4` inputs/thumbs · `8` buttons/blocks · `14` cards · pill chips.
- Tap targets min 44×44; companion Prev/Next 56px tall.
- Motion 120ms hover, 180ms ease-out enter. **Slide advance has zero transition.**
- `prefers-reduced-motion` drops all transitions; nothing depends on animation to be understood.

### Components

Button (primary / secondary / ghost / danger / disabled / teach) · chip (default / accent / draft / live) · connection indicator (ok / warn / err) · card · list row · breadcrumb · field + textarea + select · banner (info / ok / warn / err) · empty state · thumbnail grid · pairing-code display · notes row · print block.

States for every interactive component: default, hover, **focus-visible** (2px `--focus` at 2px offset — never removed), active, disabled, loading, error.

---

## 7. RTL — what mirrors and what doesn't

Toggle **RTL** in the wireframes to see all of this live.

| Element | Mirrors? | Why |
|---|---|---|
| Layout, nav, breadcrumbs, tables, thumbnail grid | **Yes** | Logical properties handle it automatically |
| **Prev / Next arrows** | **Yes** | **The classic bug.** In Arabic "next" points left. Bind the glyph to reading direction, not a fixed `‹ ›` |
| Page-number progress | **Yes** | Fills from the start edge |
| **Slide images** | **No** | Rasterized from the PDF; the Arabic deck is a different file already laid out RTL. **Never CSS-flip a slide** |
| Pairing code | **No** | Latin base32, reads LTR in both locales. Force `dir="ltr"` |
| Numerals | **Decide once** | Recommend Western digits in both locales — page numbers must match the printed deck and the PDF viewer |

Mechanism (already in `CLAUDE.md` rule 3): `<html dir>` flips everything; logical utilities only; `bin/lint-rtl` in CI. Print stylesheets are the most common place the discipline silently lapses — they are not exempt.

---

## 8. Accessibility

- **Focus visible everywhere**, 2px ring at 2px offset. The board's keyboard nav is a documented feature — it must be focusable.
- **Board keyboard nav** ←/→/space/Esc, live but visually silent.
- **Companion controls** are real `<button>`s with `aria-label`s, not divs. Announce page changes via a polite live region so a teacher using VoiceOver hears "slide 5 of 8".
- **Colour is never the only signal** — the connection indicator pairs its dot with a word ("Connected" / "Reconnecting" / "Disconnected").
- **Slide images** — see §5.5.
- **Target size** min 44×44 throughout; 56px for the companion's primary controls.
- **Reduced motion** honoured.

---

## 9. Copy principles

1. **Error copy gives the next physical action, not a diagnosis.** "Use the arrow keys on the classroom computer to keep going" — not "check your connection". The teacher is in front of thirty children and cannot debug wifi.
2. **One deliberate exception:** a failed pairing code says "code not found or expired" without saying which. Distinguishing them turns the form into an oracle for guessing codes.
3. **Empty states explain what will appear and who puts it there.** They are the first screens the Mīzān team sees, before any content exists.
4. **Every string in `config/locales/en.yml`.** Zero hardcoded English in views — `CLAUDE.md` rule 4.
5. **Estimated minutes render as "≈ N min" — the exact value**, never a synthetic range. `estimated_minutes` is one integer; inventing "35–40" from it manufactures precision the data doesn't have. If the Mīzān team wants ranges later, that's a display rule to add then.

---

## 10. Build mapping

| Milestone | Views |
|---|---|
| **M0** | 1–3, 6 (sign in, passwords, error pages) |
| **M2** | 7–11, 13 (library, track, search, lesson page, lightbox, settings) |
| **M3** | 21–24 (admin index, lesson form, notes editor, structure) |
| **M4** ⭐ | 5, 15–20 (board × 3, phone × 4) **+ Wake Lock (§5.1) + board holding state (§5.3)** |
| **M5** | 4, 12, 14, 25–26, all empty states (§5.7) — invitations, print, My lessons, people, schools |

View 4 note: invitations land in **M5** — until then, users are created via seeds or the console (M0's auth ships sign-in, not onboarding).

Two additions to the existing plans, both small and both in M4: **Screen Wake Lock** and the **board holding state**. The stage-direction markup convention (§5.2) and the deck template spec (§5.4) are decisions to make with the Mīzān team before authoring starts, not code.
