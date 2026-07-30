# M5 — Polish + verification (2 days)

**Goal:** the unglamorous 20% that makes it shippable: print stylesheet, teacher
invitations, empty states, real object storage, backups, and the system-test suite
that locks the invariants in place.

## 1. Print stylesheet — the notes packet

The brief lists "a printed sheet" as a valid teacher surface; it's the insurance
against a dead projector *and* a dead phone.

- `GET /lessons/:id/print` (authenticated, published-only via policy): one page
  per slide — thumbnail, page number, `Slide#title` and "≈ Nm" from
  `Slide#suggested_seconds` (both lines collapse when nil), notes — preceded by
  lesson title, prime, and close prompt. `**…**` stage directions render bold
  (matches the print wireframe, which shows both).
- `@media print` styles: hide chrome, `break-inside: avoid` per slide block,
  black-on-white. A "Print" button on the lesson page.
- Logical properties still apply (rule 3) — print CSS is not exempt.

## 2. Teacher invitations

The auth generator gives sessions + password reset; invitations are one model +
one mailer on top:

- `Invitation` model: `email`, `school_id`, `role`, `token_digest`, `expires_at`,
  `accepted_at`, invited_by. School_admins invite teachers to their school;
  super_admins invite school_admins (Pundit-enforced).
- Mailer with an accept link (signed token, 7-day expiry) → set-password form →
  creates the `User` with the invitation's school + role, marks accepted.
- The accept screen **shows the school name and role being accepted** (UX-SPEC
  view 4) — it's the only moment a teacher ever sees their role spelled out, and
  the last moment a wrong invitation can be stopped without a support ticket.
- Tests: expired/reused token rejected; role/school escalation impossible (a
  school_admin cannot mint a super_admin); accept page displays the invitation's
  school + role.

## 2b. My lessons (`/my`)

The second (and last) teacher nav item, derived rather than curated:

- Recently-taught list from retained paired TeachSessions — `TeachSession.taught`
  scope, distinct lessons ordered by `last_seen_at` desc — plus the "Continue"
  row on the library home. Policy-scoped to the current teacher.
- Empty state: "Lessons you teach will appear here."
- **No saved/bookmark feature** — that's phase 2 (UX-SPEC §2.6). Teacher-only
  behavioural data, consistent with the PDPL posture (UX-SPEC §5.8).

## 3. Empty states

Every list needs a considered empty state, they are the first thing the Mīzān
team sees: library with no published lessons, search with no results, lesson with
no materials, notes table before first deck upload ("Upload a deck to create
slides"), board waiting-to-pair screen, My lessons before first teach. The
session-ended state says **"The board is showing a new pairing code."** — end of
session auto-issues a fresh code (M4); no copy may tell the teacher to refresh
anything. All strings in `en.yml`.

## 4. Storage + infrastructure

- **Cloudflare R2 via Active Storage** (S3-compatible): `production` service in
  `storage.yml`, credentials in Rails credentials, bucket in EU. Serve public
  slide images through the Cloudflare-fronted custom domain — never through
  Render bandwidth ($0.15/GB there, $0 via R2). Notes/PDF originals can stay on
  private redirects.
- Confirm variants (1920×1080 board, 480×270 preview, 320×180 thumbnail) are
  pre-processed at ingest, not first-request.
- `/up` health check already wired (M0) — verify it fails when Postgres is down.
- **Off-box Postgres backups**: Render Basic-1GB has daily snapshots, but add an
  independent nightly `pg_dump` to R2 (Solid Queue recurring job or GitHub
  Actions cron) with restore instructions in `docs/RUNBOOK.md`. Test one restore.
- Later cost move (documented, not built): Hatchbox + Hetzner CX33 at ~$23/mo.

## 5. Verification suite — the release gate

Some exist from M3/M4; make sure ALL of these are green and in CI:

1. Pair → advance → both devices agree.
2. Pairing code is single-use **and** expires.
3. **Cable payload contains no notes** (exact-keys assertion).
4. Deck re-upload preserves notes.
5. Board survives a killed websocket and resyncs on reconnect.
6. Rate limiting returns 429 on both axes (IP burst, per-code).
7. Draft lessons invisible to teachers everywhere (library, search, print, teach).
8. Invitation lifecycle (accept, expire, no escalation).
9. `bin/lint-rtl` green over the entire final codebase.
10. Board holding survives reconnect — a board that reconnects pre-Start shows
    the holding screen, never leaks slide 1 early.
11. An ended board auto-issues a usable new code (redeemable, drives a session).

## 6. Pre-launch checklist (not code)

- [ ] CDN measurement from Cairo: test a Cloudflare-fronted URL, a Bunny-fronted
      URL, and bare origin from TE Data, Orange Egypt, and Vodafone Egypt. If
      Cloudflare doesn't terminate in Cairo, move media to Bunny (keep R2 as
      origin).
- [ ] Classroom wifi field test done (M4 requirement) and findings addressed.
- [ ] PDPL: local counsel engaged on the cross-border transfer permit (Germany
      hosting) ahead of the ~1 Nov 2026 deadline; confirm teacher-PII minimalism.
- [ ] Rotate all credentials that were used during development; confirm
      `RAILS_MASTER_KEY` handling.
- [ ] Error tracking (e.g. free-tier Sentry or Honeybadger) wired to production.

## Acceptance checks

- [ ] Printed Kindness lesson reads as a usable teaching script on paper.
- [ ] A school_admin can invite a teacher end-to-end on production.
- [ ] Slide images verifiably served from the Cloudflare/R2 domain in production.
- [ ] A production `pg_dump` restore has been performed once, successfully.
- [ ] Full CI suite green; the eleven verification tests all present and passing.
