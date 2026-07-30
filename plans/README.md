# Build plans — Arête / Mīzān MVP

One file per milestone from `docs/STACK-DECISION.md` §5. Each plan is written to be
handed to Claude Code as a self-contained work order: goal, tasks in order, and
acceptance checks to verify before calling the milestone done.

## Recommended execution order

**M0 → M1 → M2 → M4 → M3 → M5**

M4 (board + companion sync) runs *before* M3 (authoring) on purpose: it is the only
genuinely novel piece and the only one a laptop on your own network can't fully
validate. M1 hand-seeds one complete lesson's slides, which is enough to prove
two-device sync on real classroom hardware before investing in the authoring tools.

| File | Milestone | Estimate |
|---|---|---|
| `M0-skeleton.md` | Rails app, auth, roles, cable config, deploy | ½ day |
| `M1-model-seed.md` | Five tables + real curriculum seed | 1 day |
| `M2-library.md` | Library tree, search/filters, lesson page | 2–3 days |
| `M3-ingest-notes.md` | PDF ingest job, notes editor, `lessons:import` | 2 days |
| `M4-presenter.md` ⭐ | Pairing, channel, board + companion views | 4–5 days |
| `M5-polish.md` | Print styles, invitations, R2, system tests | 2 days |

Before starting any milestone, read `CLAUDE.md` (repo root). It carries the five
non-negotiable rules; every plan below assumes them.
