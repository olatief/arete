# M4 — Board + companion ⭐ (4–5 days)

**Goal:** the presenter. A classroom PC opens `/board` and shows a pairing code;
the teacher's phone pairs, shows per-page notes + previews, and drives the board.
The only thing that ever crosses the websocket is `{ page: N }`.

This is the milestone that carries all five CLAUDE.md rules at once. Re-read them
first. Test on real classroom wifi as early as possible — it is the only
requirement a laptop on your own network cannot validate.

## 1. Pairing flow (board-first, like casting to a TV)

### Board side — unauthenticated

- `GET /board` (`BoardsController#show`, skips authentication):
  creates `TeachSession` with `pairing_code` (Crockford base32 ×6, from M1),
  `expires_at: 12.hours.from_now`, **code expiry 3 minutes** (separate
  `code_expires_at` or encode into `expires_at` until pair — pick one, test it).
  Sets a **signed, httponly cookie** holding the session id. Renders the code in
  large type + "waiting to pair" state, and subscribes to the channel (below).
- Refreshing `/board` with a valid signed cookie for an unpaired, unexpired
  session re-renders the same code (idempotent); otherwise issues a new session.

### Phone side — authenticated

- Lesson page **Teach** button → `GET /lessons/:id/teach` → code entry form.
- `POST /teach_sessions/pair` with `{ code, lesson_id }`:
  1. Normalize: upcase, map `O→0`, `I/L→1` (Crockford decode convention).
  2. Find via `TeachSession.claimable.find_by(pairing_code: code)` — unclaimed,
     unexpired only.
  3. Set `lesson_id`, `teacher_id: Current.user.id`, `paired_at: Time.current`,
     and **null `pairing_code`** — single use — in one `update!`.
  4. Broadcast a `paired` event to the session's stream; redirect the phone to
     `/teach_sessions/:id/companion`.
- On failure: generic "code not found or expired" (don't distinguish — no oracle).
- **On pair the board shows the holding screen (wordmark), not slide 1** —
  `started_at` is nil until the phone's pre-flight **Start** button fires
  `PATCH /teach_sessions/:id/start`, which sets `started_at` and broadcasts
  `{ started: true }`; only then does the board show `current_page`. Starting the
  lesson is a deliberate act (UX-SPEC §5.3).

### Rate limiting — two axes, stacked

```ruby
class TeachSessionsController < ApplicationController
  rate_limit to: 5,  within: 1.minute, only: :pair, name: "burst"
  rate_limit to: 20, within: 1.hour,   only: :pair, name: "hourly"
  rate_limit to: 10, within: 1.hour,   only: :pair, name: "per_code",
             by: -> { params[:code].to_s.upcase }
end
```

Preconditions (verify, don't assume): cache store is Solid Cache in this
environment (M0 set it) — `:memory_store` triples limits under 3 workers and
`:null_store` disables limiting **silently**.

## 2. Channel

```ruby
# app/channels/application_cable/connection.rb — permissive; authorize per-channel
identified_by :current_user, :board_session   # current_user may be nil (board)

# app/channels/teach_session_channel.rb
class TeachSessionChannel < ApplicationCable::Channel
  def subscribed
    session = TeachSession.find_signed!(params[:token], purpose: :board_stream)
    return reject if session.expires_at.past?
    stream_for session
  rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveRecord::RecordNotFound
    reject
  end
end
```

Rules (each is a known vulnerability class — see stack decision §4):

- **Never** `stream_from "session_#{params[:id]}"` — an integer-guessing
  subscriber gets any session. Token → `find_signed!` → `stream_for`, always.
- Board and phone pages both embed
  `session.signed_id(purpose: :board_stream, expires_in: 12.hours)` in a
  `data-` attribute and pass it in **subscription params** — never in the cable
  URL (proxy logs, APM traces).
- Signed id = authentication, not authorization, and not revocable → always pair
  with the live `expires_at` check in `subscribed`.

## 3. Page advance — the hot path

- `PATCH /teach_sessions/:id` `{ page: N }` — authorized: `Current.user` must be
  the session's `teacher` (Pundit). Clamp `1..slide_count`. Update
  `current_page`, touch `last_seen_at`, then:
  `TeachSessionChannel.broadcast_to(session, { page: session.current_page })`.
- **The payload is exactly `{ page: N }`.** Absolute, never `"next"`/`"prev"`;
  never notes, titles, or any lesson content. The board is unauthenticated —
  anything else on the wire is a private-data leak. (CLAUDE.md rules 1 & 5.)

## 4. Board view (`/board` after pairing)

- On the `paired` broadcast, Turbo-visit the board lesson view (authorized by the
  signed session cookie, not a user).
- Renders **every page image at once**, preloaded, hidden except current:
  a stack of `<img>` (full 1920×1080 variants) toggled by a CSS class. Advancing
  is a class toggle — no fetch, no render, no flash. A dropped websocket never
  blanks the projector; it just stays on the current slide.
- Board state machine: **waiting → holding → teaching → ended → waiting (auto,
  new code)**. On the `ended` broadcast the board requests a fresh session/code
  itself and re-renders the waiting screen — the teacher never walks to the PC
  and never refreshes anything.
- Stimulus `board_controller`:
  - subscribes with the token; `received({ page }) → show(page)`; `{ started: }`
    and `{ ended: }` drive the state machine above.
  - `connected({ reconnected }) { if (reconnected) this.resync() }` where
    `resync()` fetches `{ page, started, ended }` from a tiny JSON endpoint
    (signed-cookie authorized) and re-enters the matching state — a board that
    reconnects during pre-flight lands on **holding**, never prematurely on
    slide 1 (regression test 9 below).
  - **Keyboard nav** ←/→/space/Esc that PATCHes the page (board-cookie-authorized
    variant of the update endpoint) — if the phone dies, the teacher walks to the
    PC and keeps going.
  - "Go fullscreen" **button** (`requestFullscreen()` needs a user gesture — it
    cannot be automatic). Progressive enhancement: on Chromium, offer
    `getScreenDetails()` to place the window on the external display.

## 5. Companion view (phone)

- Authenticated. Renders **all** notes server-side into the HTML at load (this is
  how notes stay off the wire), plus the small preview variant of every page —
  hidden except current, same class-toggle pattern.
- Controls: big Prev / Next, page `N / total`, current-page notes, prime and
  close-prompt accessible.
- Stimulus `companion_controller`:
  - Optimistic UI: advance locally on tap, PATCH in background; reconcile from
    broadcast (absolute state makes this safe).
  - `connected/disconnected/rejected` → **visible connection indicator**
    (green/amber/red dot + label). A teacher must know a tap didn't land before
    they're standing in silence.
  - `window.addEventListener("online", () => consumer.connection.reopen())` —
    ActionCable's client has no online/offline handling; wifi→cellular with the
    screen on is otherwise only caught by the 6s stale threshold.
  - Same `connected({ reconnected }) → resync()` re-read of `current_page`.
- **Screen Wake Lock** (UX-SPEC §5.1 — it belongs here, not in a polish pass):
  `navigator.wakeLock.request("screen")` while the session is active; the lock
  drops whenever the tab hides, so re-request on `visibilitychange`; show an
  "awake" indicator in the header so the teacher trusts it; fall back silently
  where unsupported.
- **Per-slide timer**: elapsed, reset on every advance; target from
  `Slide#suggested_seconds`, rendered `02:30 / 03:00`, muted, never red;
  elapsed-only when the slide has no target.
- **Slide title + next-slide preview** from `Slide#title`, one line of text each
  (fallback: "Slide N" when nil) — rendered server-side with the notes.
- **End confirmation**: an in-page Turbo confirm ("End lesson? The board will
  clear."), never `window.confirm`. **Offline reconciliation rule**: while
  disconnected, Prev/Next is script-browsing only ("Read ahead") — it never
  claims to move the board; on reconnect, resync to the server's `current_page`
  (what the class actually saw) with a brief "back on slide N" notice.
- Expect hard disconnects on iOS lock (WebKit suspends websockets) — the
  indicator + resync handles it; the board (screen on) stays up.

## 6. Session lifecycle

- "End session" on the phone (after the Turbo confirm) → sets `ended_at` and
  `expires_at: Time.current`, broadcasts `{ ended: true }` (still no content);
  the board auto-issues itself a fresh session/code and shows the waiting screen.
- Sweep job (Solid Queue recurring): **delete only expired, never-paired
  sessions.** Paired rows are retained as teaching history — they are the data
  source for M5's "My lessons" (`TeachSession.taught`). Teacher-only behavioural
  data; no student anything.
- Dual display needs nothing: the teacher's own laptop opening `/board` and
  pairing is the identical code path.

## 7. Tests — the ones that guard the invariants

System tests (two Capybara sessions where needed):

1. **Pair → advance → both agree**: board shows code, phone pairs, phone taps
   Next, board and phone both show page 2.
2. **Pairing code is single-use**: second redeem of the same code fails.
3. **Code expires**: travel 5 minutes, redeem fails.
4. **Cable payload contains no notes**: subscribe a raw test client to the
   stream, advance, assert the broadcast JSON keys are exactly `["page"]` and the
   payload never includes any substring of the fixture notes. This is the test
   that must never be deleted.
5. **Guessed stream is rejected**: subscription with a forged/absent token is
   rejected; `stream_for` name is not constructible from an integer.
6. **Board survives a killed websocket**: kill the consumer, advance from phone,
   board still shows *a* slide (stays on current); on reconnect, resyncs to
   `current_page`.
7. Rate limit: 6th pair attempt in a minute → 429.
8. Authorization: a different logged-in teacher cannot PATCH someone else's
   session.
9. **Board reconnecting during pre-flight shows holding, not slide 1** (resync
   returns `started: false` → holding screen).
10. End requires confirmation; after end, the board shows a fresh, working
    pairing code (redeemable, drives a new session).
11. (manual) Wake lock holds through a 2-minute idle on a real phone.

## Acceptance checks

- [ ] Full flow works with a laptop (board) + phone (companion) on the same wifi.
- [ ] Tests 1–10 above green in CI (11 is manual).
- [ ] Payload audit: grep the channel/broadcast code path — the only broadcast
      shapes are `{page:}`, `{paired:}`, `{started:}`, `{ended:}`. No content,
      ever.
- [ ] Manual: lock the phone mid-lesson, unlock → indicator recovers, page
      resyncs within ~1s.
- [ ] **Field test on actual classroom wifi scheduled** — this milestone is not
      done until tap-to-advance has been felt in a real classroom.
