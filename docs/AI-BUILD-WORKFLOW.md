# Building the views with Claude Code — workflow, prompts, and setup

**Companion to:** `docs/UX-SPEC.md`, `docs/ux-wireframes.html`, `plans/M0–M5`
**Date:** 29 July 2026

---

## 0. The finding that should shape everything

GitClear analysed 623M code changes across 2023–2026. In AI-assisted codebases:

- **Block duplication +81%** (40.3 → 73.0 per million changed lines)
- **Copy/paste +41% year over year**
- **Refactoring collapsed to 3.8% of changed lines**, from 21% in 2022
- Developers are now ~5× more likely to copy/paste than to refactor

**The measured failure mode of coding agents at scale is duplication, not incorrectness.** They write code that works and doesn't reuse.

Applied to an 18-screen build, that means: **if you go screen-by-screen starting from screen 1, you will end up with 18 subtly different button implementations.** Not because the agent is bad at buttons — because nothing forced it to look for the one that already exists.

So the decomposition that matters is **ordering, not task size**:

```
1. Design tokens        → and make wrong tokens fail to compile
2. Component layer      → build ~12 components, freeze them, screenshot baselines
3. Screens in batches   → each batch forbidden from creating new components
```

There is, honestly, very little hard evidence about agent-sized task decomposition. The one credible study stratifies by task *type* (chores 84% PR acceptance, features 66%, tests 61.5%) with no UI breakdown at all. Treat "build 3 screens at a time" as a reasonable heuristic, not a finding. Treat the ordering above as the part with evidence behind it.

---

## 1. One-time setup (about 90 minutes, pays for itself immediately)

### 1.1 Tokens that can't be faked — the strongest single lever

In `app/assets/tailwind/application.css`:

```css
@import "tailwindcss";

@theme {
  /* Delete every default Tailwind color. This is the point. */
  --color-*: initial;

  --color-bg:          #FBF6EC;
  --color-surface:     #FFFDF8;
  --color-surface-2:   #F4EBDB;
  --color-border:      #E3D7C2;
  --color-ink:         #2A2723;
  --color-ink-strong:  #16304F;
  --color-ink-muted:   #6E655A;
  --color-accent:      #B5502E;
  --color-success:     #2F6D4F;
  --color-warning:     #8A5E10;
  --color-danger:      #A32C22;
  /* …dark-mode set, type scale, spacing — full list in ux-wireframes.html */

  --font-display: "Fraunces", Georgia, serif;
  --font-prose:   "Spectral", Georgia, serif;
}
```

`--color-*: initial` removes the entire stock palette. **`bg-slate-500` stops compiling.** The most common drift failure — the agent reaching for plausible-sounding Tailwind palette names — becomes a visibly broken page instead of silent inconsistency.

This is enforcement by compiler rather than by prompt, and prompts lose that argument every time.

Verify it actually landed (there's a documented failure where tokens silently don't emit and the page still renders):

```bash
curl -s localhost:3000/assets/tailwind.css | grep -E -- '--color-accent|\.bg-accent'
```

### 1.2 `bin/lint-tokens`, next to `bin/lint-rtl`

Same grep-based pattern you already trust, catching what the compiler can't:

```bash
#!/usr/bin/env bash
# Fails on raw hex colors and arbitrary pixel values in views.
if grep -rnE '#[0-9a-fA-F]{3,8}\b|\[[0-9]+(px|rem)\]' app/views app/components 2>/dev/null \
   | grep -v 'rtl-ok\|token-ok'; then
  echo "✗ Raw color or arbitrary size in a view. Use a design token."
  exit 1
fi
```

### 1.3 Hooks — run both linters after every edit

`.claude/settings.json`. This is the highest-value Claude Code feature for your project, because you already have the scripts:

```json
{
  "permissions": {
    "allow": [
      "Bash(bin/rails test *)",
      "Bash(bin/rails db:*)",
      "Bash(bin/lint-rtl)",
      "Bash(bin/lint-tokens)",
      "Bash(git diff *)",
      "Bash(git status)"
    ],
    "deny": [
      "Read(config/credentials/**)",
      "Read(.env*)",
      "Bash(git push *)"
    ]
  },
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          { "type": "command", "command": "bin/lint-rtl",    "timeout": 15 },
          { "type": "command", "command": "bin/lint-tokens", "timeout": 15 }
        ]
      }
    ]
  }
}
```

A non-zero exit feeds the failure back to Claude, which fixes it without you saying anything. Your CLAUDE.md rule 3 stops being a request and becomes a constraint.

Allowlisting the test command matters more than it looks — it's what lets the agent run its own test loop without a permission prompt every iteration.

### 1.4 Visual rules in CLAUDE.md

Your CLAUDE.md is genuinely better than any Rails template I found, but **it has zero visual rules**. Add a short block:

```markdown
## View rules

- Design tokens only. No hex, no `bg-slate-*`, no `[14px]`. If a token is
  missing, stop and ask — do not invent one.
- Reuse before you create. Check `app/components/` and `app/views/shared/`
  first. Creating a new shared component needs explicit approval.
- `docs/ux-wireframes.html` is the source of truth for layout and states.
  Read the relevant screen section before writing a view; do not read the
  whole file.
- Every screen needs its empty, loading, and error state — see UX-SPEC §5.7.
- Teach mode is dark and chromeless. Browse mode is light with app nav.
  Never mix them.
```

### 1.5 Keep the 80KB wireframe out of startup context

Do **not** `@`-import `ux-wireframes.html` into CLAUDE.md — it would load on every session.

Instead, add a one-line index so the agent can seek precisely:

```markdown
`docs/ux-wireframes.html` — screens are `<section class="screen" id="…">`:
tokens · signin · home · track · search · lesson · empty · pair · boardwait
· boardlive · preflight · companion · degraded · print · adminlist
· adminform · notes · people
```

Then prompts say *"read the `lesson` section of ux-wireframes.html"* and the agent greps to it. Check `/context` occasionally; `/compact` when it drifts high.

### 1.6 Plugins and MCP worth having

```bash
# Closest thing to your exact stack: ERB partials + Tailwind 4, 15+ accessible
# components, Turbo Frame/Stream patterns. Notably partials, not ViewComponent.
/plugin marketplace add maquina-app/rails-claude-code
/plugin install maquina-ui-standards@rails-claude-code

# The measurement instrument (§3)
claude mcp add --scope project playwright npx @playwright/mcp@latest
```

Also worth installing `ruby-lsp` so the agent gets real symbol navigation instead of grep.

Skip Percy and Chromatic — team-CI SaaS aimed at component libraries; local screenshot diffs give the agent the same artifact for free. Skip BackstopJS, effectively legacy.

**A note on sourcing:** a large share of search results in this space (`mcpmarket.com`, `aidesigner.ai`, `vibecodingacademy.ai`) are SEO content farms recycling the same three paragraphs. The genuinely useful writeups are Steve Kinney's, Vadim's, and Justin Searls'. Everything below leans on those.

---

## 2. Model and effort

| Phase | Model | Effort | Why |
|---|---|---|---|
| Planning a milestone, arguing about structure | **Opus**, plan mode | `high` | You want disagreement here, not compliance |
| Component layer (§4 phase 2) | **Opus** | `high` | These get copied 18 times; a bad button propagates |
| Screen batches from a frozen component set | **Sonnet** | `medium` | Mostly transcription against fixed primitives |
| Bulk mechanical work (i18n extraction, renames) | **Haiku** or Sonnet | `low` | Cheap and fast |
| Adversarial review of a finished batch | **Opus** subagent | `high` | Different context, no authorship bias |
| The presenter (M4 — cable, wake lock, pairing) | **Opus** | `high` | Concurrency and security; the one place to spend |

`/model opus`, `/effort high`. Enter plan mode with **Shift+Tab**; Shift+Tab again to leave.

The pattern that saves the most money: **plan on Opus, implement on Sonnet.** Write the plan to a file so switching models doesn't lose it.

---

## 3. The verification loop — measurement, not eyeballing

Practitioners who've done this converge on one point: **screenshot-to-vision comparison plateaus fast.** Reported fidelity for AI-generated UI on its own is 65–80%; what closes the last 20% is extracting computed values and comparing numbers.

> "Use Playwright not for visual regression testing, but as a measurement instrument. The AI is the labor. Playwright is the quality gate." — Vadim

Three tools, three jobs:

- **Playwright MCP** — drive and verify. Reproducible, clean-room. *This is the one you want.*
- **Chrome DevTools MCP** — observe and diagnose (console, network, perf). No navigation workflows.
- **Claude in Chrome** — your real logged-in session. Not reproducible; wrong tool for a loop.

### The loop

```
1. Agent builds the view
2. Agent screenshots it via Playwright MCP against bin/dev
3. Agent reads BOTH the screenshot and the wireframe section
4. Agent extracts computed styles via page.evaluate() and compares to tokens
5. Agent fixes; repeat
```

Convergence folklore, worth knowing: 3–5 iterations per component. **Past 8 with deltas not shrinking, something is structurally wrong** — usually the oscillation loop (fix margin → break padding → fix padding → break margin). Stop and restructure rather than iterating.

Two hard rules:

- **Never let the agent regenerate a screenshot baseline to make a test pass.** That converts your only external oracle into a rubber stamp.
- Kill flake up front: disable animations, hide the caret, pin fonts, mask volatile regions.

### ⚠️ The project-specific trap: your two most important screens are unreachable

`/board` and the companion have **no user-driven navigation path** — they need a pairing code, a signed cookie, and a live cable subscription. An agent pointed at `localhost:3000/board` will burn iterations failing to get anywhere useful.

**Build a test helper that pairs a session before you start any visual work on M4:**

```ruby
# test/support/teach_session_helper.rb
def paired_board_url(lesson)
  session = TeachSession.create!(expires_at: 12.hours.from_now)
  session.update!(lesson:, teacher: users(:nour), pairing_code: nil,
                  paired_at: Time.current)
  "/board?debug_session=#{session.signed_id(purpose: :board_stream)}"
end
```

Gate the `debug_session` param on `Rails.env.local?`. Without this, M4's visual loop doesn't function.

### A second thing worth testing that nothing else will catch

Your `{page: N}` architecture means advancing a slide is a **CSS class toggle over preloaded DOM**. That's an unusually good visual-regression target — fully deterministic, no network — and an unusually easy thing for an agent to "fix" into a server render.

```ruby
test "advancing a slide fires zero network requests" do
  # assert the request count is identical before and after Next
end
```

That test defends the architecture, not just the pixels.

---

## 4. Build order and the actual prompts

### Phase 1 — Tokens (30 min, do it yourself, one prompt)

```
Read the `tokens` section of docs/ux-wireframes.html and the Design system
section of docs/UX-SPEC.md.

Write app/assets/tailwind/application.css with a Tailwind 4 @theme block
containing every token: colors (light AND dark), fonts, type scale, spacing,
radius, shadows.

Start the block with `--color-*: initial;` so stock Tailwind palette names
stop compiling — this is deliberate.

Then write bin/lint-tokens: fail on raw hex or arbitrary [Npx] values in
app/views and app/components, allowing an inline `token-ok` escape.

Finally, verify: boot the server, curl the compiled CSS, and confirm both
--color-accent and .bg-accent are present. Show me the grep output.
```

### Phase 2 — Component layer (a day, Opus, the phase that matters)

Do this in **plan mode first.**

```
[Shift+Tab to enter plan mode, /model opus, /effort high]

Read docs/UX-SPEC.md §6 and the `tokens` section of docs/ux-wireframes.html.

Propose the minimum set of shared components needed to build all 18 screens
without duplication. For each: name, the props it takes, which screens use it,
and every state it needs (default/hover/focus/disabled/loading/error).

Constraints:
- ViewComponent for shared components ONLY, because Previews give me a stable
  addressable URL per component — that's the screenshot target for the visual
  loop. The 18 screens stay plain ERB.
- Tokens only, no hex, no arbitrary values.
- Logical CSS properties only — ms-/me-/ps-/pe-/start-/end-. bin/lint-rtl runs
  on every edit.
- Every component needs a Preview covering all its states.

Argue with me if you think the set is wrong or if something should be a partial
instead of a component. Don't write code yet.
```

Then, after approving: build them, generate Previews, and **commit the screenshot baselines by hand**.

Expect roughly: Button, Chip, Card, ListRow, Breadcrumb, Field, Banner, EmptyState, ConnectionIndicator, Thumb, PrimeBlock, AppBar. Around a dozen.

### Phase 3 — Screens, three at a time (Sonnet)

```
[/model sonnet, /effort medium]

Build the library home, track page, and search results (UX-SPEC §2.2, views 7–9).

Read the `home`, `track`, and `search` sections of docs/ux-wireframes.html —
those sections only, not the whole file.

Rules:
- Use ONLY the components in app/components/. If you need something that
  doesn't exist, STOP and tell me — do not create a new shared component.
- Routes and controllers per plans/M2-library.md.
- Every user-visible string goes in config/locales/en.yml. Zero hardcoded
  English.
- Each screen needs its empty state (UX-SPEC §5.7).
- policy_scope on every lesson query — drafts must be invisible to teachers.

When done: run bin/rails test, bin/lint-rtl, bin/lint-tokens, then screenshot
each of the three pages with Playwright at 1440px and compare to the wireframe
sections. Report differences before fixing them.
```

The **"STOP and tell me"** clause is doing the real work. It's your defence against the duplication finding in §0, and it's the sentence to keep in every screen prompt.

### Phase 4 — M4, the presenter (Opus, high effort, plan mode)

This one is different in kind: concurrency, security, and two devices. Plan it, and lean on the plan file you already have.

```
[/model opus, /effort high, plan mode]

Read plans/M4-presenter.md, UX-SPEC.md §4.2–4.4 and §5.1–5.3, and the
`pair`, `boardwait`, `boardlive`, `preflight`, `companion`, `degraded`
sections of docs/ux-wireframes.html.

Plan the implementation. Pay particular attention to:
- The cable payload is exactly { page: N }. Never notes, never content.
  The board is an unauthenticated subscriber.
- Screen Wake Lock on the companion, re-requested on visibilitychange
  (UX-SPEC §5.1). This is missing from the M4 plan — include it.
- The board holding state between pairing and slide 1 (UX-SPEC §5.3).
  Also missing from the plan.
- A test helper that produces a pre-paired board URL, so /board is reachable
  without going through pairing. Build this FIRST — the visual loop needs it.

Flag anything in the plan you think is wrong before writing code.
```

### Phase 5 — Adversarial review per batch

Don't let the author grade its own work. `.claude/agents/view-reviewer.md`:

```markdown
---
name: view-reviewer
description: Reviews generated Rails views against the UX spec and design system
model: opus
tools: [Read, Grep, Bash]
---

Review the views in the current diff. Report only defects, ranked by severity.

Check, in order:
1. Duplication — is there a near-copy of an existing component or partial?
   This is the most common failure; look hardest here.
2. Token drift — raw hex, arbitrary values, or invented token names.
3. RTL — any physical direction utility, in ERB *or* print CSS. Print
   stylesheets are where this discipline usually lapses.
4. Hardcoded English not in config/locales/en.yml.
5. Missing states — empty, loading, error.
6. Accessibility — focus-visible present, real <button> not <div>, tap
   targets ≥44px, colour never the only signal.
7. Authorization — every lesson query through policy_scope.

Do not praise. Do not fix. Report only.
```

Invoke it after each batch with a fresh context.

---

## 5. Testing

**Capybara is still the path — but swap the driver.** Justin Searls' migration from `selenium-webdriver` to `capybara-playwright-driver` is the reference writeup: flake went from ~30% failure to under 5%, and "the Capybara DSL remains unchanged — this is a driver swap, not an API overhaul." The native Playwright driver PR in Rails core (#48950) is still unmerged; don't wait for it.

Add **`capybara-screenshot-diff`** (repo `snap-diff/snap_diff-capybara`) for baselines — VIPS backend, `perceptual_threshold`, `disable_animations`, `fail_if_new: true` in CI. It fits your no-build-step constraint better than a separate Node `@playwright/test` suite. Note that `toHaveScreenshot` is a `@playwright/test` feature and the Capybara driver does **not** give it to you.

### Getting non-tautological tests out of an agent

Nobody has published a good prompt-based method, and I don't think one exists. `assert_selector ".btn"` written right after the agent typed `class="btn"` is worthless no matter how you ask for it. The answer is **structural — give the agent an oracle it can't trivially satisfy:**

| Oracle | Why it can't be faked |
|---|---|
| Screenshot baselines you approve by hand | The agent is forbidden from regenerating them |
| Computed-style assertions against token values | Compares rendered output to a separate source of truth |
| **RTL parity** — render each screen at `dir=rtl`, diff against the mirrored LTR baseline | `bin/lint-rtl` catches forbidden *utility names*; this catches layout that's wrong for other reasons. Given your rule 3, **the highest-value UI test you can write** |
| axe-core assertions | A genuinely external accessibility oracle |
| "Advancing fires zero network requests" | Defends the architecture, not the appearance |

On accessibility specifically: there is peer-reviewed work (W4A '25, *"When LLM-Generated Code Perpetuates User Interface Accessibility Barriers"*) establishing that LLM-generated UI reliably reproduces a11y barriers. It's the one failure mode with academic backing. Wire axe in early rather than auditing at the end.

---

## 6. Failure modes, ranked by how well the mitigation works

| # | Failure | Mitigation | Evidence |
|---|---|---|---|
| 1 | **Duplication** — 18 slightly different buttons | Build and freeze components first; "STOP and tell me" in every screen prompt | **Strong** — GitClear, 623M changes |
| 2 | **Token fabrication** — invents `--color-primary-500` | `--color-*: initial` makes it fail to compile | **Strong** — documented Tailwind behaviour |
| 3 | **Accessibility regressions** | axe-core in system tests | **Strong** — W4A '25 |
| 4 | **RTL lapses**, especially in print CSS | `bin/lint-rtl` as a PostToolUse hook + RTL parity screenshots | Your own rule, now enforced |
| 5 | **Within-session drift** — same component, different spacing across uses | Frozen component layer + `bin/lint-tokens` | Blog-grade only |
| 6 | **Between-session amnesia** — Monday's tokens ≠ Wednesday's | Tokens in a file, read every session | Blog-grade only |
| 7 | Visual mismatch | Screenshot loop | Weakest — good at "looks wrong", poor at "is correct" |

Note the ranking: **the screenshot loop everyone talks about is the *least* reliable item on this list.** It's worth having, but the compiler-level and lint-level constraints do more work for less effort. Spend your setup time there first.

---

## 7. If you only do four things

1. **`--color-*: initial`** in the `@theme` block. Fabricated tokens stop compiling.
2. **`bin/lint-rtl` + `bin/lint-tokens` as PostToolUse hooks.** Your rules become constraints instead of requests.
3. **Build the ~12 components before any screen**, with `"STOP and tell me"` in every screen prompt afterwards.
4. **Write the pre-paired-board test helper before starting M4.** Without it the two most important screens in the product are unreachable to any automated loop.
