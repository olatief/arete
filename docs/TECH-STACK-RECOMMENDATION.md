# Mīzān / Arête Platform — Tech Stack & Hosting Recommendation

**For:** Omar, solo developer building with Claude Code
**Date:** 30 July 2026
**Scope:** Phase 1 MVP as defined in *The Mīzān Curriculum Platform — Product Brief*, §9

---

## 0. What I read this project to be

The folder holds two different products, and it's worth naming which one this recommendation is for.

- **`DEVELOPER GUIDE.md` / `CONTENT GUIDE.md`** describe *Arête LMS* — a single-file React app, student self-paced, YouTube + slides + gated quizzes, `window.storage` persistence, AI teaching assistant. This is a working prototype.
- **`Mizan Platform Brief EN.pdf` / `Mizan Kindness Lesson EN.pdf`** describe the *Mīzān Curriculum Platform* — teacher-led, projected, two-surface (board + private script), ~260 lessons across three tracks (Mīzān, Arête, Iḥsān), bilingual EN/AR with full RTL, offline-capable, no student logins in v1.

**These are not the same app, and the second one is the real product.** Arête is one *track* inside Mīzān. The prototype's architecture — client-only state, JSON export as the backup strategy, quizzes as the progression mechanic, last-write-wins on a shared key — is the opposite of what the Platform Brief asks for.

Everything below targets the Platform Brief. The prototype's value is as a **design reference and a Phase 0 validation tool**, not as a codebase to grow. Treat it as a spike you already got the learning from.

> If I've got that backwards and you want the student-facing self-paced LMS first, tell me — most of the stack below still holds, but the CMS, offline, and privacy sections change materially.

---

## 1. The recommendation in one page

| Layer | Choice | Why |
|---|---|---|
| **Backend** | Ruby on Rails 8.1 | You know it. Claude Code is exceptionally strong in it. Rails 8's Solid Queue / Solid Cache / Solid Cable remove Redis entirely — one less service for a solo dev. |
| **Database** | PostgreSQL 17 | Not SQLite. You need real concurrency, JSONB, and a managed-backup path. |
| **Frontend** | **Inertia.js + React 19**, via `inertia_rails` + Vite Ruby — **with the Teach view as a client-routed island** | Gives you React where it earns its keep without a second app, a second deploy, an API contract, or token auth. The one screen that must work offline is deliberately carved out of Inertia — see §6. |
| **Styling** | Tailwind CSS 4.3 | v4's logical properties and `rtl:`/`:dir()` variants make bilingual RTL a build-time concern rather than a stylesheet fork. |
| **Bilingual** | **Paired columns** (`title_en` / `title_ar`), *not* a translation gem | Exactly two locales, forever. Queryable, joinable, diffable, trivially serializable into offline packs, and renders side-by-side so your Arabic author sees the English source. |
| **CMS** | **Rails-native.** ActiveAdmin for CRUD + a purpose-built React lesson editor + a bulk importer | §4. An external headless CMS costs 3–6 weeks and permanent operational surface, and buys nothing your model can use. |
| **Hosting (MVP)** | **Render, Frankfurt region** — realistically **$40–55/mo** all-in | ~57 ms to Cairo, automatic point-in-time backups, near-zero ops. Cost-down path to Hetzner + Kamal 2 in §5. |
| **Images / CDN** | **Cloudflare R2 + Cloudflare CDN**, custom domain with explicit cache rules | Zero egress fees and a Cairo edge presence. Highest-leverage infrastructure choice here — with a caveat in §5. |
| **Offline** | PWA — Cache Storage per unit + IndexedDB metadata, Workbox 7.4 | §6. **Note this is a Phase 2 item in your own brief; §6 explains what to do about that.** |
| **Two surfaces** | `window.open` + `postMessage` + heartbeat, progressively enhanced with the Window Management API | §7. Read the mirrored-display warning — it's the sharpest edge in the product. |

---

## 2. Why Rails + Inertia, and not the alternatives

You listed Rails, React, Vue, and TanStack. Here's the honest sort.

**Rails 8.1 is the right backend.** Current stable is 8.1.3 (24 Mar 2026); 8.1 gets bugfixes to Oct 2026 and security patches to Oct 2027. What matters for a solo dev:

- **Solid Queue / Solid Cache / Solid Cable** are database-backed, so background jobs (PDF slide rasterization, offline pack generation, image derivatives) need no Redis. One service, one backup.
- **The built-in authentication generator** gives you session-based teacher login in one command — you need three roles, not an identity platform.
- **Active Storage** handles the Canva/Google Slides PDF → per-slide PNG pipeline with variants, and points at S3-compatible storage (R2) with a config line.
- **Kamal 2** ships in the box, so the migration path off a PaaS is already written.

**Inertia over a separate SPA.** The tempting move is Rails-as-API + a standalone React app with TanStack Router and Query. Don't. That's two deployments, a hand-maintained API contract, JWT plumbing, CORS, and a duplicated authorization layer — for a product whose entire authenticated surface is "a teacher browses a library and opens a lesson." `inertia_rails` is at 3.22.0 (Jul 2026) and very actively maintained; Inertia core independently reached 3.6.1, adding a built-in XHR client and optimistic updates.

Two caveats worth knowing up front:

- Inertia is an *official Inertia.js* adapter, not Rails-core-blessed. There's no `rails new --inertia`. Mature community choice, adopted on its own merits.
- **Inertia is server-driven and therefore cannot be your offline path.** Every navigation is an XHR to a Rails controller. This is a real architectural constraint and §6 handles it explicitly — do not discover it at the end.

**Where TanStack fits — narrowly.** TanStack Query is excellent, but Inertia owns your data fetching; adding Query means two caches disagreeing. Use **TanStack Table v8** if the scope-and-sequence grid gets complex (v9 is beta). That's about it.

Actively avoid **TanStack Start** — despite npm versions reading `1.168.x`, the docs still label it a Release Candidate and a maintainer question about stable 1.0 has been unanswered since December 2025. Avoid **TanStack DB** (0.6.x, explicitly beta) even though "reactive client-side database" sounds perfect for offline. Your offline layer needs to be boring.

**Vue:** Inertia supports it equally well. Pick React only because it matches the existing prototype and has the deeper presentation-UI ecosystem. If you're faster in Vue, take Vue — genuinely a coin flip.

**Build tooling: Vite Ruby** (`vite_rails` 3.11.1), not `jsbundling-rails`, which hasn't shipped a release in ~2 years and gives no HMR or React Fast Refresh.

---

## 3. The data model — get this right first

This is where the Platform Brief is unusually clear, and where the prototype is unusually wrong. The brief's own words: *"lessons must be stored as structured data — separate fields for board content and script — rather than as flat PowerPoint or PDF files where the two are fused."*

```
School ──< Membership >── User (super_admin | school_admin | teacher)

Track (Mīzān / Arête / Iḥsān)
  └── Grade
        └── Unit
              └── Lesson
                    ├── header: title_en/ar, objectives_en/ar, est_minutes, tags
                    ├── prime_en / prime_ar        (teacher prep brief)
                    ├── close_en / close_ar        (reflection prompt)
                    ├── Slides (ordered)
                    │     ├── board_image_en / board_image_ar   ← imported PNG, PER LOCALE
                    │     ├── board_body_en / board_body_ar     ← text; v1: alt-text + search
                    │     ├── script_en / script_ar             ← PRIVATE, teacher only
                    │     ├── notes_en / notes_ar
                    │     └── suggested_seconds
                    ├── Materials (handouts) — file_en / file_ar
                    └── LessonRevision (monotonic, published snapshot)

TeacherLessonOverride (teacher_id, lesson_id, based_on_revision)
  ├── slide_order: [slide_id, ...]        ← ordered array, master + custom
  ├── hidden_slide_ids: [slide_id, ...]
  ├── SlideOverride (slide_id, board_body?, script?, notes?)   ← changed fields only
  └── CustomSlide (teacher-authored, source_slide_id = NULL)
```

Six design rules that will save you real pain:

**1. Every authored field is a pair — including the images.** `board_body_en` / `board_body_ar`, and critically `board_image_en` / `board_image_ar`. In Phase 1 the board content *is* the image, and a Canva deck exported to PNG is monolingual — an Arabic classroom needs an Arabic image set. This means two PDF imports per lesson and roughly double your offline pack size. Budget for it now; it's the easiest thing in this document to overlook and the most annoying to retrofit.

Not a `translations` JSONB blob, and not Mobility. You have two locales and will always have two. Paired columns mean `WHERE board_image_ar IS NULL` finds your untranslated backlog in one query, and an offline pack serializes with `to_json` and no locale-resolution step. **Mobility** (1.3.2) is genuinely Globalize's successor — Globalize's own maintainers say so — but it hasn't shipped since January 2025 and solves a problem you don't have.

**2. Overrides overlay; they never fork.** The brief leans copy-on-edit and asks the team to confirm. **Overlay, and here are the arguments that actually hold** (two of the obvious ones don't):

- *Storage and propagation for un-overridden fields.* A teacher who reworded one script line still receives every master correction to the other eleven slides. A fork receives none of them.
- *Offline pack size.* Overlays are small rows; forks are full duplicate trees × N teachers.
- ⚠️ *Not* "master fixes flow through automatically" without qualification — the one field a teacher overrode is precisely the field that will **silently mask** a later master correction. Handle this: when a lesson's revision increments, flag affected overrides as *"the original changed"* and show the teacher a diff. Don't let it be silent.
- ⚠️ *Not* "reset is one DELETE" — deleting a fork is equally cheap.

**3. Ordering is an array, not an integer column.** Store `slide_order` as an ordered array of slide IDs on the override. Per-slide integer `position` breaks the moment a master lesson inserts a slide: every teacher's positions shift meaninglessly. An array also gives you "add a custom slide at position 3" for free.

**4. Teachers can add slides — the schema must allow it.** Brief §9 Phase 1 says teacher adaptation is *"edit, hide, reorder, **add**."* A `SlideOverride` keyed to a master `slide_id` cannot represent a slide that has no master. Hence `CustomSlide` with a nullable `source_slide_id`, participating in the same `slide_order` array. Easy to design in, genuinely awkward to bolt on.

**5. Publishing is an explicit state, and PaperTrail is not the mechanism.** A lesson version is an *aggregate* — lesson + N slides + materials — not a row. PaperTrail versions rows and is the right audit log underneath, but you need an explicit `LessonRevision`: a monotonic counter plus a published snapshot, with draft edits invisible to teachers until published. Without this, an author editing a master at 10 a.m. changes what a teacher is mid-way through projecting. Overrides pin to `based_on_revision`.

**6. Board *text* is constrained, not rich text.** Store `board_body` as plain text with a tiny Markdown subset. Reasons: rich-text HTML fights offline pack serialization, and Arabic RTL behavior in Trix and Lexxy is untested (I could not verify it — it's the highest-risk unknown on the Rails-native path).

To be honest about the weaker version of this argument: "the design system should own board typography" is the right principle for the *native slide builder in Phase 2*, but in v1 Canva owns the typography, because the board is a PNG. So in v1, `board_body` earns its place as **alt text, search index, and the seed for Option C later** — not as the rendered board. Which is exactly why it should stay simple text. If you later want real rich text for the prime brief, add Action Text for that one field (8.1.3.1, healthy).

**Also unresolved in the brief, and worth deciding early:** the *pacing view* (§4) implies a `LessonDelivery` record — "teacher T taught lesson L to class C on date D." There are no student accounts, so this is a class-level, teacher-marked record. It's small, but it's a table nobody has drawn yet. Either add it or explicitly defer pacing to Phase 2.

### Arabic search will not work out of the box

Brief §4 requires search and filters by theme, virtue, and objective; §8 makes bilingual first-class. **PostgreSQL ships no Arabic dictionary or stemmer** — you get the `simple` configuration and nothing else. Before an index is usable you need tashkeel (diacritic) stripping, alef/hamza/taa-marbuta normalization, and Arabic-Indic → Latin numeral folding.

Practical answer: a normalized `search_vector_ar` column populated by your own normalization function, or `pg_trgm` as the pragmatic fallback for a 260-lesson corpus — at that size trigram similarity search is genuinely good enough and far less work. Don't discover this during the search ticket.

---

## 4. The CMS — build it, don't buy it

You asked for "some kind of CMS for the lesson plans." I looked hard at both paths. **Build it in Rails.**

### Why not a headless CMS

Three requirements each independently pull content back into your own Postgres:

- **Teacher overrides need a foreign key** to a master lesson row. You can't FK into Sanity or Strapi. So you mirror every lesson and slide into Rails tables anyway — and now you maintain the mirror *and* the sync *and* the override layer.
- **Offline packs need deterministic, complete, point-in-time content** including binary images. Fetching 260 lessons × 2 locales from a rate-limited CDN at pack-build time is fragile. You'll build a local mirror regardless.
- **Versioning must be joint.** An override pins to a master revision. CMS-side history versions the CMS document; your `LessonRevision` versions the aggregate. Two independent timelines requiring reconciliation is a reliable bug factory.

On top: webhooks are at-least-once and out-of-order (you need idempotency keys and a monotonic revision counter, or a late webhook silently reverts a newer edit); deletions must be soft or they orphan overrides; images must be mirrored into Active Storage anyway; and **none of the major CMS rich-text formats have a maintained Ruby renderer** — Sanity's Portable Text, Strapi's blocks, Payload's Lexical JSON would each be a serializer you own.

Realistic cost: **3–6 weeks plus permanent operational surface**, versus **1–2 weeks** to build the authoring UI in Rails.

Specific disqualifiers, in case someone advocates for one:

| CMS | The problem |
|---|---|
| **Sanity** | Free-tier datasets are **public** — private teacher scripts would be world-readable. Private datasets need Growth ($15/seat/mo). Free tier has no Editor role. The only Ruby client is explicitly unmaintained. |
| **Payload** | Best-in-class field-level i18n with a native `rtl: true` locale flag — technically ideal. But the admin panel *is* a Next.js app; outside Next you lose the admin panel, REST API, GraphQL, and media manager. Known bug: **localized array fields render blank in the secondary locale** — your Arabic translator would see empty slide cards with no English source. |
| **Directus** | Relicensed BUSL → MSCL at v12. Free use requires **under $5M revenue AND under 50 employees** — a school district or grown nonprofit trips the headcount test. Offline mode is Enterprise-only. |
| **Strapi v5** | Best of the bunch: MIT, self-hostable, core per-field i18n, Components and Dynamic Zones localize correctly. But Content History is paid Growth, and there's no locale-scoped edit permission for translators. **If you overrule me here, pick Strapi.** |
| **Contentful / Storyblok** | Contentful free caps at 2 locales and 2 roles; next tier is $850/mo with nothing between. Storyblok offers no i18n on free; Growth is $99/mo. |

### What to build instead — three pieces

**a) ActiveAdmin 3.5.1 for the CRUD.** Schools, memberships, teachers, roles, tracks, units, materials, tags. MIT, actively maintained (latest Mar 2026), Rails 8 supported on 3.x. Its forms DSL gives nested records with real drag-reorder for free:

```ruby
f.has_many :slides, sortable: :position, allow_destroy: true, new_record: "Add slide" do |s|
  s.input :board_image_en, as: :file
  s.input :board_image_ar, as: :file
  s.input :script_en
  s.input :script_ar
  s.input :suggested_seconds
end
```

Stay on 3.x — v4 has been in beta since early 2025. **One friction point to plan for:** ActiveAdmin 3.x uses Sprockets/importmap, which sits awkwardly alongside Vite + Inertia. It works, but budget an afternoon for the dual asset pipeline, and consider mounting ActiveAdmin on a separate layout.

> **Skip Avo.** Nicer UI, but its pricing lands *exactly* on the two features your model requires: Record Reordering is in the $75/mo Essentials bundle, Nested Records in the $145/mo Growth bundle — **$220/mo, $2,640/year** (capped at $249/mo if you take the Everything bundle), per app, for what ActiveAdmin does free.

**b) A purpose-built React lesson editor** for the one screen that matters. Your authors will spend hundreds of hours here. For **v1**, where the board is an imported image, the right layout is:

- Slide list on the left, drag-reorder.
- For the selected slide: **the EN board image and AR board image side by side** (so the author sees immediately which locale is missing), with **EN script and AR script panes below**, and notes and timing beside them.
- Alt-text / search-text fields folded in, not front and centre.

When Option C (native slide builder) arrives in Phase 2, this same screen becomes the four-pane text editor — the layout survives, the top row changes from images to rendered board text.

**c) A bulk importer — do not skip this.** Your own Content Guide tells authors *"Write slides in a doc first."* Nobody is hand-entering 260 lessons × ~10 slides × 2 languages through a web form. Define a lesson interchange format (YAML front-matter + Markdown, or a Google Sheets template with one row per slide), write a Rails importer that validates and upserts by a stable `lesson_key`, and make it **idempotent and re-runnable**. Authors draft where they already work, you bulk-load, and the web editor becomes the *maintenance* surface rather than the *creation* surface.

This answers the brief's open question *"Who authors the ~260 lessons, in what tool, and what ingestion format?"* — **Google Docs/Sheets for drafting, a defined YAML/CSV schema for ingestion, the web editor for revision.**

---

## 5. Hosting

### Start on Render, Frankfurt

| Item | Cost |
|---|---|
| Web service, Standard (1 CPU / 2 GB) | $25/mo |
| Background worker, Starter — PDF rasterization | $7/mo |
| Postgres, Basic-1gb | $19/mo |
| Cloudflare R2 (images) | ~$0 — inside the permanent free tier at MVP volume |
| Domain, transactional email, error tracking | ~$5–10/mo |
| **Realistic total** | **~$56/mo** |

You can start at **$26/mo** (Starter web $7 + Postgres $19) and it will work for a demo — but three things push the real number up, and it's better to know now:

- **PDF → PNG rasterization will OOM a 512 MB Starter instance.** Run it on a separate worker, or size up to Standard.
- **poppler and libvips are not in Render's native Ruby runtime.** You need a Dockerfile. Rails 8 ships a tuned production one, so this is minor — but it changes your deploy config from day one, so do it on day one.
- **7-day PITR requires the Pro workspace plan**; the Hobby workspace gets a 3-day window on the same $19 database.

Also: Rails 8 expects separate `queue`, `cache`, and `cable` databases by default. On a single Render Postgres instance, point them at the primary with separate schemas, or set `config.solid_queue.connects_to` accordingly. It's a five-minute config decision that's a confusing hour if you hit it blind.

Why Render for the MVP: automatic point-in-time recovery on all paid databases, a first-class Rails 8 path, and essentially no ops. As a solo dev, your scarce resource is attention.

**One hard rule: do not serve slide images from Render.** Bandwidth past the allowance is **$0.15/GB** — 15× DigitalOcean App Platform, and infinitely more than R2.

### Why Frankfurt, and not the Middle East

Crowd-sourced probe latency from Cairo:

| Cairo → | Latency |
|---|---|
| Paris | ~49 ms |
| **Frankfurt** | **~57 ms** |
| London | ~58 ms |
| Riyadh | ~99 ms |
| US-East | ~121–130 ms |
| Bahrain | ~139 ms |

Paris is marginally faster, but Render has no Paris region — Frankfurt is its only EU location, and 8 ms is not worth changing provider over. Egypt's fibre lands on Mediterranean cables running to Marseille and Europe; Gulf traffic often backhauls through Europe anyway. **Frankfurt beats Bahrain by more than 2×.** AWS `me-central-1` (UAE) and Azure UAE North are the only "near Egypt" regions, and they're more expensive, higher-ops, and *slower from Cairo*. No hyperscaler has a region inside Egypt.

### The cost-down path, once it's proven

**Hetzner CX-line VPS in Falkenstein + Kamal 2** — €5.49–€15.99/mo for the whole app including Postgres on the same box, same ~57 ms to Cairo. Rails 8 ships Kamal, so this is a config exercise, not a rewrite.

Note **Hetzner raised prices on 15 June 2026**, very unevenly: CPX and CCX lines went up 2.1–2.75× while CX and CAX (Arm) rose only ~1.3×. The cheap sweet spot is now **CX or CAX, not CPX**. Add Hatchbox at $10/server if you'd rather have a UI than raw Kamal.

**Avoid Fly.io**: no free tier for new customers, Managed Postgres starts at $38/mo, Africa egress is $0.12/GB, and their region consolidation left Johannesburg (~200 ms from Cairo) as the sole Africa region. **Avoid Heroku** — 3–4× the cost for no advantage.

### Images: R2 + Cloudflare

- **Cloudflare R2**: $0.015/GB-month storage, **$0 egress, always**. The free tier (10 GB storage, 10M reads/month) is permanent and your MVP corpus likely fits inside it.
- **Cloudflare currently lists a Cairo PoP** — one Egyptian city out of 337, currently Operational.
- ⚠️ **Don't over-rest on that.** Cloudflare has *removed* the Cairo colo before, with Egyptian users reporting they were served from Marseille at 75 ms+. Egyptian ISP peering is the binding constraint, not PoP existence. R2 + Cloudflare is still clearly the right choice — zero egress alone decides it — but treat the Cairo edge as a bonus, not a foundation. It's another argument for offline packs: the network you can't control is the one you shouldn't depend on mid-lesson.
- ⚠️ **R2 objects are not edge-cached by default.** You need a custom domain on the bucket plus explicit Cache Rules. Skipping this quietly gives you origin fetches on every image.
- Bunny.net also has Cairo but charges **$0.06/GB for Middle East & Africa** — its priciest zone — with no latency advantage.

### Egypt's PDPL — a real deadline, months out

**Personal Data Protection Law No. 151 of 2020 is now live.** Executive Regulations were issued 1 November 2025 (PM Decree No. 816 of 2025) with a one-year transition — **compliance lands around October/November 2026**, and some counsel read enforcement as beginning by October.

- **No data localization requirement.** Frankfurt hosting is legally fine. ✅
- **But cross-border transfer needs prior PDPC approval** — a supplementary permit, a transfer impact assessment, and evidence of equivalent protection at the destination. Frankfurt hosting *is* a cross-border transfer.
- **A registered DPO is mandatory** for legal entities, with qualification requirements and annual reporting.
- **Children's data carries enhanced protections and written guardian consent.** For a K-12 platform, the highest-risk area by a distance.
- Breach notification: PDPC within 72 hours.
- Penalties: EGP 200,000–2,000,000 generally, **rising to EGP 5,000,000** for sensitive-data offences, with criminal sanctions for unlawful disclosure.
- *(Unverified: a reported fee exemption for entities holding 1–100,000 records. Plausible and would apply to you, but confirm with counsel rather than relying on it.)*

**Worth saying out loud to the Mīzān team: the decision that students don't log in is now a compliance asset, not just a scoping win.** No student accounts means no children's personal data, which sidesteps the hardest part of PDPL. The brief flags it *[Likely worth holding to]* — **hold to it.**

One caveat on that: §8's *"reflection / formation capture, light in v1 but designed in"* is a plausible route back into children's data if reflections are free text captured from students. Keep v1 capture teacher-authored or fully anonymous, and if student-attributable reflection ever ships, it ships with a lawyer.

---

## 6. Offline — and the Inertia collision

### First, a scope correction

**Your brief puts "downloadable offline packs" in Phase 2, not Phase 1.** I think that's the wrong call — but it's a scope expansion, so name it rather than smuggling it in. Two honest options:

- **Option 1 — build it in Phase 1.** Costs perhaps 2–3 weeks. Justified because §8 calls low-bandwidth Cairo classrooms a first-class requirement, and offline is genuinely expensive to retrofit.
- **Option 2 — keep it in Phase 2, but bind Phase 1 to three design constraints** so the retrofit stays cheap: (a) the Teach view is client-routed and hydrates from a single JSON payload, never mid-lesson server calls; (b) all pack assets are content-hashed and enumerable from a manifest; (c) no lesson content is rendered server-side.

**Either is defensible. What isn't defensible is the middle** — calling offline critical and then scheduling it last, which is how retrofits become rewrites.

### The Inertia problem, stated plainly

Inertia navigations are XHRs to Rails controllers. Offline there is no controller, no session round-trip, and no asset-`version` handshake. So:

> **The Teach view is a self-contained client-routed island, not an Inertia page.**

Concretely: the service worker serves a cached app-shell HTML for `/teach/*`; React boots and hydrates the entire lesson from IndexedDB and Cache Storage; no Inertia visit occurs on the offline path. The rest of the app — library, lesson page, admin, editor — stays happily server-driven Inertia. You also need an offline auth gate: a long-lived local session token written into the pack, since you can't validate a cookie against a server that isn't there.

This is a clean boundary and a small amount of work *if you draw it at step 6*. If you draw it at step 10, you rebuild the Teach view.

### The pack mechanics

1. **On first launch**, call `navigator.storage.persist()` and **check the return value** — then `estimate()` — before offering any downloads. Don't show a "downloaded" state unless persistence was actually granted.
2. **Ship a per-unit manifest** listing asset URLs plus content hashes.
3. **Lesson JSON and metadata → IndexedDB. Images and handout PDFs → a named Cache Storage bucket per unit** (`caches.open('pack-arete-g6-u2')`). Cache Storage handles Response bodies better than blobs in IndexedDB and gives free `cache.match()` serving. Deleting a unit is one cache delete plus one IndexedDB sweep.
4. **Include the Materials.** Handout PDFs are on the Phase 1 lesson page and are per-locale — they belong in the manifest. Easy to forget; very visible when a teacher can't print the handout.
5. **Download from the page, not the service worker**, in concurrency-limited batches of 4–6 with per-file retry and resumable progress. **Do not use `cache.addAll()`** — it fails atomically, so one dropped image on Cairo bandwidth loses the whole pack. Loop `cache.put()`.
6. **Feature-detect Background Fetch** (Chrome/Edge only) as an enhancement — real OS download UI, survives tab close. Fall back to the in-page loop.
7. **Override resolution must run client-side.** The pack ships master content *and* the teacher's overlay; merging happens in the browser. Don't bake a merged copy server-side or you lose the ability to update either half independently.
8. **Offline edits need write-behind.** Phase 1 allows teacher adaptation, so a teacher editing a script mid-lesson offline needs a local mutation queue that flushes on reconnect, with last-write-wins per field and a visible sync indicator. Small, but not free — another argument for Option 1 above.
9. Service worker: cache-first for pack assets, stale-while-revalidate for the shell. **Workbox 7.4.1** (May 2026) is current.
10. Show "X of Y downloaded · N MB" and an explicit **Delete unit** button. Browser eviction is all-or-nothing per origin — teachers must manage space deliberately, not discover it's gone mid-lesson.

⚠️ **Safari will silently evict your pack.** Safari caps script-writable storage at **7 days of no interaction** for non-installed sites. A teacher who downloads on Monday and returns the following week finds it gone. Mitigation: require **Add to Dock / Add to Home Screen** for Safari users before offering downloads, and say why.

Quotas are otherwise generous: Chrome/Edge ~60% of disk per origin, Safari 17+ similar, Firefox min(10% of disk, 10 GiB). Even with paired EN/AR image sets, a unit is nowhere near any limit.

**Self-host your fonts.** The Google Fonts CDN is a hard offline failure and slow on Cairo bandwidth. Subset with `pyftsubset`, serve WOFF2, precache.

---

## 7. The two-surface Teach view

The brief recommends Option A (dual display) first. **Agreed — but the API you'd reach for isn't ready, so build the fallback as the primary path.**

**The Window Management API** (`screen.isExtended`, `getScreenDetails()`, `requestFullscreen({screen})`) is **Chromium-only** and not Baseline — no Firefox (Mozilla objected on fingerprinting grounds), no Safari, no mobile. **The Presentation API is effectively dead** — Candidate Recommendation since 2017, never implemented outside Chromium.

### ⚠️ The mirrored-display problem — read this first

**Most teachers plug in HDMI and get a mirrored display by default.** In a two-window design, mirroring means **the class sees the private script.** Given the brief calls the public/private split *"the single design decision the whole platform turns on,"* this is the sharpest practical edge in the entire product, and it will happen in the first week of real classroom use.

Handle it deliberately:

- Gate "Start lesson" on `screen.isExtended` where available.
- If the display is mirrored or extension can't be confirmed, show a **blocking interstitial**: *"Your screen appears to be mirrored — students will see your script. Extend your display, or continue anyway."*
- Have the board window detect it shares a screen with the teacher window and render a visible warning rather than the slide.
- Cover it in teacher onboarding with a screenshot for both Windows and macOS.

### The architecture

Borrowed from how reveal.js's speaker view actually does it:

1. **`window.open()` the board view on a user gesture** — the teacher clicks "Start lesson." A gesture is required or the popup blocker eats it.
2. **Sync over `postMessage`** on the window handle, with origin validation, as the primary channel. Add **BroadcastChannel** (94.8% support, Safari 15.4+) as a secondary bus for late-joiners and reload recovery.
3. **Send a heartbeat.** This is the detail that makes it robust: either window can reload and reconnect mid-lesson. reveal.js learned this the hard way.
4. **The teacher window owns the clock and the slide index.** The board window is a dumb renderer. If the projector display is off or occluded, Chromium may throttle that window's timers — never let it hold state.
5. **Progressive enhancement:** `if (screen.isExtended)` → "Send to projector" → `getScreenDetails()` → position the board window on the external screen and `requestFullscreen({screen})`.
6. **The fallback must feel good**, because it's what Safari and Firefox users get. Give them an **in-app "Full screen" button** calling `requestFullscreen()` on the board window — do not tell them to press F11, which is Windows-only. On macOS it's Ctrl+Cmd+F, and it creates a new Space, which makes dragging the window worse.
7. **Acquire a Screen Wake Lock** while teaching (Baseline; Safari 16.4+, Chrome 84+, Firefox 126+). A 45-minute lesson with no keyboard input will otherwise sleep the laptop and blank the projector mid-class. Re-acquire on `visibilitychange`.
8. Investigate keyboard-lock so arrow keys don't hit browser UI — note the API surface has historically been `navigator.keyboard.lock()`; verify the current form before wiring it.

**A deployment note worth telling the schools:** Chrome's **Automatic Fullscreen** content setting (Chrome 126+) allows gesture-free multi-display fullscreen for allowlisted origins via the `AutomaticFullscreenAllowedForUrls` enterprise policy. If Mīzān's partner schools manage their Chrome fleet, allowlisting your origin makes the projector flow seamless — a one-line ask to a school IT admin that materially improves the core interaction.

### On Phase 2's companion device — a warning and a cheap answer

**Chrome shipped a Local Network Access permission prompt in Chrome 142.** HTTPS pages connecting to LAN IPs or `.local` addresses now trigger a user prompt, with WebSocket and WebRTC integration planned. So "phone talks to a small server on the classroom PC" now costs a prompt and may get further restricted. And since offline is required, you can't route sync through your server either.

Realistic options: a WebRTC data channel with QR-code manual signaling (works, fiddly), a native helper on the PC, or:

**A $10 USB or Bluetooth presenter clicker.** It enumerates as a keyboard sending PageUp/PageDown, needs zero web platform support, works fully offline, and solves the actual stated problem — *"teachers need to move around the room."* Ship this as the v1 answer to Option B, recommend it in teacher onboarding, and spend the saved weeks elsewhere.

---

## 8. RTL — the things that will bite you

Tailwind v4 handles most of it. These are the failure modes:

- **Set `dir` once on `<html>`**, driven by the language choice on the lesson page. The brief is explicit that this is a whole-interface switch, never per-slide and never both languages on screen at once — that simplifies things considerably.
- **Use logical properties everywhere**: `ms-`/`me-`, `ps-`/`pe-`, `text-align: start`. Note Tailwind **v4.3 deprecated `start-*`/`end-*` in favor of `inset-s-*`/`inset-e-*`** — use the new names. (The block-direction logical utilities — `mbs-*`, `pbe-*` — landed in v4.2.)
- **`:dir(rtl)` became Baseline Widely Available on 7 June 2026**, so you can use it instead of `[dir="rtl"]` attribute selectors.
- **Never apply `letter-spacing` to Arabic** — it breaks cursive ligature joining. This ships to production constantly.
- **Arabic needs more line-height**: ~1.7–1.85 body, 1.3–1.4 headings, versus 1.5–1.6 / 1.1–1.2 for Latin. Tashkeel needs the room. On projected slides this is legibility, not aesthetics.
- **Arabic renders visually larger** at the same px size — typically set it 1–2px smaller than the Latin equivalent.
- **Numerals:** `ar-EG` defaults to Eastern Arabic-Indic digits (١٢٣). Decide deliberately and set `Intl.NumberFormat('ar-EG', { numberingSystem: 'latn' })` explicitly. Never mix systems on one screen.
- **Mirror directional icons** under `:dir(rtl)`.
- **Use `dir="auto"` and `<bdi>` for user-supplied strings** — teacher names, custom script edits. An English lesson title interpolated into Arabic UI will reorder its punctuation without this.

**Fonts:** **IBM Plex Sans Arabic** is the best choice for a bilingual UI — 7 weights, harmonized with Plex Latin, so one family covers both scripts and you avoid the pairing problem. **Cairo** is a strong alternative for board headings. Both OFL, both on Google Fonts. ⚠️ **Rubik has no Arabic on Google Fonts** despite several 2026 blog roundups claiming otherwise.

---

## 9. Answers to the brief's open questions (§10)

| Question | Answer |
|---|---|
| Dual-display first, or companion device sooner? | **Dual-display first**, as you proposed — but ship a **$10 presenter clicker** as the "move around the room" answer. Chrome's new Local Network Access prompt makes the phone-remote path harder than when the brief was written. And solve the **mirrored-display** trap before anything else in §7. |
| Is importing images enough for v1? | **Yes** — but the image is **per locale** (EN and AR PNG sets), and it hangs off a *structured* slide record so the native builder can arrive later without a migration. |
| How hard is the offline requirement? | **Treat it as a dealbreaker** — but note it's a Phase 2 item in your own brief, so it's a scope expansion. §6 gives you two defensible paths. What doesn't work is calling it critical and scheduling it last. |
| Fork or overlay for teacher edits? | **Overlay** — but for the right reasons (propagation of *un*overridden fields, pack size), and with an explicit "the original changed" diff, because an overridden field silently masks master corrections. Ordering is an array; teacher-added slides need their own table. |
| Will students ever log in? | **Hold the line on no.** Post-PDPL this is a compliance asset worth real money. Keep v1 reflection capture teacher-authored or anonymous so it doesn't quietly reintroduce children's data. |
| Who authors the 260 lessons, and in what format? | **Google Docs/Sheets for drafting → a defined YAML or CSV schema for bulk ingestion → the web editor for maintenance.** Build the importer in week one. |
| Expected scale year one? | Whatever the answer, the stack handles it. A few hundred teachers with projected, teacher-led lessons is very low concurrency — this is a content-delivery problem, not a scale problem. Revisit past ~50 schools. |
| Hosting, residency, privacy? | **Frankfurt.** No localization requirement under PDPL, and Frankfurt is 2× faster from Cairo than Bahrain. You need a cross-border transfer permit, a registered DPO, and PDPL registration around Oct/Nov 2026. Get Egyptian counsel. |

---

## 10. Suggested build order

Roughly the order I'd hand to Claude Code, each step shippable:

1. **Rails 8.1 + Postgres + Inertia + Vite + Tailwind 4**, on a Dockerfile (you need poppler/libvips), deployed to Render Frankfurt on day one. Deploy before you build.
2. **The data model and the importer.** Schools, memberships, tracks, grades, units, lessons, slides, materials — paired `_en`/`_ar` columns throughout, including images. Then the YAML/CSV importer, seeded with the Kindness Grade 6 lesson from `Mizan Kindness Lesson EN.pdf` as the reference specimen. **If you can round-trip that one lesson in both locales, the model is right.**
3. **Authentication and roles** (super-admin, school admin, teacher) via the Rails 8 generator, plus `LessonRevision` and draft/publish.
4. **The library**: Track → Grade → Unit → Lesson navigation, plus scope-and-sequence and search. Build this screen **in Arabic**, not the twentieth — RTL bugs found here are cheap.
5. **The lesson page**: prime, slide thumbnails, materials, EN/AR selector, Teach button.
6. **The Teach view — as a client-routed island** (see §6), with the mirrored-display guard, heartbeat, wake lock, and timer. The core of the product; give it the time.
7. **Slide ingestion**: per-locale PDF/PNG upload → per-slide images → R2 via Active Storage, processed in Solid Queue on the worker.
8. **Teacher overrides**: overlay model with `slide_order` array, custom slides, hide, reset-to-original, "the original changed" diff.
9. **ActiveAdmin** for CRUD, plus the custom lesson editor from §4b.
10. **Offline packs** (if Option 2 in §6): service worker, per-unit download, write-behind queue, storage management UI.

Steps 1–6 are the demo that gets Phase 1 signed off. Deferred by choice, not oversight: pacing view, admin dashboard, native slide builder, companion device.

And the brief's **Phase 0 is right** — run one live cohort on Google Slides plus a shared script doc before writing platform code. The prototype in this folder is a perfectly good tool for that, which is the best possible use of it.

---

## Appendix — verified versions, July 2026

| | Version | Note |
|---|---|---|
| Rails | 8.1.3 (24 Mar 2026) | No 8.2 or 9.0 exists. Security patches to Oct 2027 |
| `inertia_rails` | 3.22.0 (17 Jul 2026) | Independently versioned from Inertia core (3.6.1) — the matching 3.x numbers are coincidence |
| `vite_rails` | 3.11.1 (3 Jul 2026) | `jsbundling-rails` is stale, ~2 yrs no release |
| Tailwind CSS | 4.3.3 (16 Jul 2026) | v4.2 added block-logical utilities; v4.3 deprecated `start-*`/`end-*` |
| ActiveAdmin | 3.5.1 (24 Mar 2026) | v4 still beta since early 2025 — stay on 3.x |
| PaperTrail | 17.0.0 | Audit log under `LessonRevision`, not the versioning mechanism |
| Action Text | 8.1.3.1 | Trix now decoupled into `action_text-trix` |
| Workbox | 7.4.1 (4 May 2026) | |
| TanStack Query / Router | 5.101.4 / 1.170.18 | Both stable |
| TanStack Start | 1.168.x | ⚠️ Docs still say Release Candidate. Avoid |
| TanStack DB | 0.6.x | ⚠️ Beta. Avoid for offline |
| Mobility | 1.3.2 (Jan 2025) | Recommended gem, but quiet 18 months. Not needed here |

**Flagged as unverified:** Trix and Lexxy Arabic/RTL rendering quality — untested, which is why §3 routes around rich text. The exact current form of the fullscreen keyboard-lock option. Directus v12's GA date (the relicense itself is confirmed). PDPL's reported 1–100,000-record fee exemption. Latency figures are crowd-sourced probes, not vendor SLAs — the Frankfurt number is corroborated bidirectionally and is the one I'd trust.
