# M2 — Library + lesson page (2–3 days)

**Goal:** the teacher-facing browse experience — server-rendered
`Track → Grade → Unit → Lesson` tree with search and filters, and the lesson page
with the **Teach** button. This is the first demoable artifact for the Mīzān team.

Everything here is plain server-rendered Rails + Turbo. No Stimulus should be
needed beyond trivial disclosure toggles.

## 1. Routes & controllers

```ruby
resources :tracks, only: [:index, :show], param: :slug
resources :lessons, only: [:show]
# search/filter live on the library index via query params
root "tracks#index"
```

- `TracksController#index` — the library home: tracks with grade groupings.
- `TracksController#show` — one track's `Grade → Unit → Lesson` tree.
- `LessonsController#show` — the lesson page.
- All behind authentication (M0 generator). Pundit policies:
  - Teachers/school_admins see **published** lessons only.
  - Super_admins see drafts too (badge "Draft" chip).
  - `policy_scope(Lesson)` implements this — every lesson query goes through it.

## 2. Library index + tree

- Track cards (Mīzān / Arête / Iḥsān) → track page with units grouped by grade
  (K displayed as "K", stored as 0).
- Lesson rows show: code, title, estimated minutes, tag chips, draft badge
  (admins only).
- N+1 discipline: `includes(units: :lessons)` etc.; add `bullet` in dev if useful.

## 3. Search + filters

Query params on the library index, combinable:

- `q` — `Lesson.search(q)` (the `websearch_to_tsquery` scope from M1).
- `tags[]` — `where("tags @@ ?", …)` → use array overlap `tags && ARRAY[?]` for
  any-match; GIN index already exists.
- `grade` — joins units.
- Results render as a flat lesson list (with breadcrumb context per row) replacing
  the tree; empty state with a clear-filters link.
- Filter form submits as GET (bookmarkable); use a Turbo Frame around the results
  so typing/filtering doesn't full-page reload.

## 4. Lesson page (UX-SPEC §4.1, view 10 — drawn in `docs/ux-wireframes.html`)

Top to bottom:

1. Breadcrumb `Track → Grade N → Unit → Lesson`.
2. Title + chips (grade, estimated minutes rendered "≈ N min" — the exact value,
   never a synthetic range — tags). The EN/AR locale switch sits here next to
   Teach; there is **no locale chip in the appbar** (UX-SPEC decision — nothing
   locale-shaped in the chrome).
3. **Prime** block — the read-before-you-teach brief, visually distinct.
4. Page thumbnails — grid of `Slide` images in `page_number` order (small variant
   via `image.variant(resize_to_limit: [320, 180])`). **Clickable → slide preview
   lightbox** (UX-SPEC view 11): slide large + `Slide#title` + its notes, prev/next
   within the lightbox, Esc closes. Content is already on the page — no fetch.
5. Materials — list of attached files, filename as label, download links.
6. **Close prompt** block.
7. **Teach** button — for M2 this links to a placeholder route (real flow is M4).
   Style it as primary; it is the whole point of the page.

## 4b. Account settings (`/settings`)

UX-SPEC view 13 puts this in M2: name, email, password, UI locale (`ui_locale`).
Plain form, nothing clever — it exists so the appbar needs no locale chrome.

## 5. i18n + RTL discipline

- Every label through `t()` into `en.yml` (rule 4).
- Logical utilities only — the breadcrumb, chips, and thumbnail grid are exactly
  where `ml-`/`pl-` habits creep in. `bin/lint-rtl` must stay green.

## 6. Tests

- Policy tests: teacher cannot see a draft lesson (404/redirect), super_admin can.
- Request tests: search returns the Kindness fixture; tag + grade filters combine;
  empty-state renders.
- System test: sign in → browse tree → open Kindness lesson → all sections render,
  thumbnails present, Teach button visible.

## Acceptance checks

- [ ] Library and lesson page fully server-rendered, no custom JS beyond Turbo.
- [ ] Draft lessons invisible to teachers, visible-with-badge to super_admins.
- [ ] Search, tag filter, and grade filter work and combine; bookmarkable URLs.
- [ ] Kindness · Grade 6 page matches the UX-SPEC §4.1 lesson-page structure
      (wireframe: "Lesson page") and looks presentable —
      this milestone ships to the Mīzān team for feedback.
