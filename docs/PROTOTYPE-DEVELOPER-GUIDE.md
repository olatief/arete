# Arête LMS — Developer Guide

> **⚠️ Superseded.** This documents the retired single-file React prototype
> (`arete-lms.jsx`), not the current platform. The MVP is a Rails monolith —
> see `STACK-DECISION.md` and the root `CLAUDE.md`. Kept for historical
> reference only; do not follow its React/localStorage/Anthropic-proxy advice.

Everything a programmer needs to run, deploy, and extend `arete-lms.jsx`.

Audience: someone comfortable with React, Node, and basic web deployment. If you're the content person, use `CONTENT_GUIDE.md` instead.

---

## 1. What this is

A single-file React learning-management app. One component, three surfaces:

- **Student view** — sequential course player: YouTube video, slide carousel, gated quiz, downloadable resources.
- **Instructor view** — full course builder: modules, lessons, videos, slides, quizzes, resources, reorder, export/import JSON.
- **AI Teaching Assistant** — a docked chat on the instructor side. Generates quizzes and slides for the currently-edited lesson and inserts them with one click.

No backend required. All state lives in the browser (`window.storage` when available, in-memory otherwise), plus JSON export/import for portability.

---

## 2. Tech stack

- **React 18+** (function components, hooks — no external state library)
- **No build-time CSS framework** — a single CSS string is injected inline (`Fraunces` + `Spectral` from Google Fonts)
- **Optional AI backend** — the assistant calls `POST https://api.anthropic.com/v1/messages` directly. When run inside the Claude app / artifact, auth is handled automatically. When self-hosted, you either wire your own key or turn the assistant off.
- **Persistence** — `window.storage` (Claude runtime API). If absent, the app falls back to in-memory state and shows a banner asking the user to export.

Only true runtime dependency: **React**. Everything else is native browser APIs.

---

## 3. Fastest path to running it locally

```bash
npm create vite@latest arete-lms -- --template react
cd arete-lms
npm install
# replace src/App.jsx with the contents of arete-lms.jsx
# ensure export default remains named App (it is)
npm run dev
```

That's it. The Google Fonts imports work over the internet; no other setup.

Note: `window.storage` won't exist in a plain Vite dev server — the app will run in **preview mode** (in-memory) and show the yellow "Preview · export to save" banner. That's expected. See §6 for making persistence real.

---

## 4. File anatomy

`arete-lms.jsx` — single file, three logical zones:

| Lines | Zone | What lives there |
|---|---|---|
| Top | `CSS` template string | All styling, injected via `<style>{CSS}</style>` |
| Middle | `SEED` object + helpers (`uid`, `slide`, `qq`, `ytId`, `flat`, `sGet`, `sSet`) | Default course + shared utilities |
| Bottom | Components | `App` → `StudentView` → `VideoTab / SlidesTab / QuizTab / ResTab`, `InstructorView`, `AIDock` |

The seed course is what shows the first time a user opens the app. Once the instructor edits and saves, `window.storage` overrides the seed.

---

## 5. Data model

The whole course is one JSON object. This is the schema — if you change it, migrate carefully.

```ts
type Course = {
  title: string;
  subtitle: string;
  modules: Module[];
};

type Module = {
  id: string;           // uid() — 7-char random
  title: string;
  level?: number;       // 1..5 in the Arête spiral; optional
  lessons: Lesson[];
};

type Lesson = {
  id: string;
  title: string;
  grade: string;        // e.g. "Grade 10"
  level: number;        // 1..5
  question: string;     // the lesson's central question
  summary: string;      // shown under the video
  youtube: string;      // full URL, shortlink, or bare ID — parsed by ytId()
  slides: Slide[];
  resources: Resource[];
  quiz: Quiz;
};

type Slide    = { id: string; title: string; body: string };
type Resource = { id: string; label: string; url: string };
type Quiz     = { passScore: number; questions: Question[] };
type Question = {
  id: string;
  q: string;
  options: string[];    // 2..6 options
  answer: number;       // index of the correct option
  explanation: string;  // shown after grading
};
```

**Progress** is a separate object, keyed by lesson id, stored per-user:

```ts
type Progress = Record<LessonId, { complete: boolean; score?: number }>;
```

---

## 6. Persistence

Two keys, two scopes:

| Key | Scope | Purpose |
|---|---|---|
| `arete:course` | shared (visible to all users) | The course itself |
| `arete:progress` | personal (per user) | This user's completed lessons |

The `sGet` / `sSet` helpers wrap `window.storage.get / set` with JSON serialization and error swallowing.

### Replacing `window.storage` with something real

For a self-hosted deployment you'll want a real backend. Two easy swaps:

**Option A — `localStorage` (single-device, no accounts)**

```js
async function sGet(key) {
  const v = localStorage.getItem(key);
  return v ? JSON.parse(v) : null;
}
async function sSet(key, val) {
  localStorage.setItem(key, JSON.stringify(val));
  return true;
}
```

Then also set `const hasStorage = true` in `App()` so the banner hides.

**Option B — API-backed (multi-user, real product)**

Replace `sGet` / `sSet` with `fetch('/api/course')` / `fetch('/api/progress')` calls to your own server (Postgres / Supabase / Firestore — anything). Add auth in front. The keys stay the same; only the transport changes.

---

## 7. The AI Teaching Assistant

Lives in the `AIDock` component. Uses this call pattern:

```js
fetch("https://api.anthropic.com/v1/messages", {
  method: "POST",
  headers: { "Content-Type": "application/json" },
  body: JSON.stringify({
    model: "claude-sonnet-4-20250514",
    max_tokens: 1000,
    system: SYS,          // the Arête pedagogy system prompt
    messages: [...]
  })
});
```

Two important behaviors:

1. **In the Claude app / artifact runtime** — auth is transparent. No key required.
2. **Self-hosted** — you must proxy this call through your own server that adds an `x-api-key` header. **Never ship an API key in client-side code.** A minimal Node proxy:

```js
// server.js
app.post("/api/ai", async (req, res) => {
  const r = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-api-key": process.env.ANTHROPIC_API_KEY,
      "anthropic-version": "2023-06-01"
    },
    body: JSON.stringify(req.body)
  });
  res.json(await r.json());
});
```

Then change the fetch URL inside `AIDock` from the Anthropic endpoint to `/api/ai`.

The system prompt is intentionally short and pedagogy-specific (`Socratic, phenomenological, feeling-first`). Edit `SYS` in `AIDock` to tune the assistant's voice.

The quick actions (`Generate quiz`, `Draft slides`) ask the model for JSON only, then `JSON.parse` and insert. If the model wraps the JSON in Markdown fences, the code strips them before parsing.

---

## 8. YouTube handling

`ytId()` accepts any of these and returns a video ID (or `""`):

- `https://www.youtube.com/watch?v=ABC123xyz_-`
- `https://youtu.be/ABC123xyz_-`
- `https://www.youtube.com/embed/ABC123xyz_-`
- `https://www.youtube.com/shorts/ABC123xyz_-`
- `ABC123xyz_-` (raw ID)

The Instructor view shows a green confirmation when a valid ID is detected, red when not.

---

## 9. Sequential unlock logic

`currentIdx = firstIncomplete` in the flat lesson list. Lessons with index > `currentIdx` show as locked (🔒) and can't be clicked. A lesson unlocks the next when its quiz is passed (`score >= passScore`). If a lesson has no quiz, an explicit "Mark lesson complete" button unlocks progression.

---

## 10. Extending

- **New tab in the student view** — add a case to the `{tab === "..."}` conditionals in `StudentView`, add a button to the `.tabs` row.
- **Custom question types** — extend the `Question` schema (add `type: "single" | "multi" | "short"`), then branch in `QuizTab`.
- **Certificates / badges** — check `pct === 100` in the sidebar footer and render a component that reads student name from `window.storage`.
- **Analytics** — instrument `saveProgress` to POST to your analytics endpoint.
- **Real user auth** — wrap `App` in a login gate; use the authenticated user id as a namespace prefix on the storage keys.

---

## 11. Known limitations

- **No offline mode.** Slides and quizzes live in memory once loaded, but YouTube requires the network.
- **`window.storage` size caps at 5 MB per key.** A 130-lesson course with heavy content will approach that; if you get close, split into `arete:course:module-1`, `arete:course:module-2`, etc.
- **The AI assistant is optional.** If the API is unreachable it fails gracefully with a message; the rest of the app keeps working.
- **No collaborative editing.** Last write wins on the shared `arete:course` key. If two instructors edit simultaneously, one's changes will be overwritten. For multi-instructor work, put a real DB in front.

---

## 12. Deployment options

- **Vercel / Netlify** — drop the Vite build's `dist/` folder in. Works out of the box for the app itself; add a serverless function for the AI proxy (§7).
- **Static hosting (S3, GitHub Pages, Cloudflare Pages)** — same, but you'll need to point the AI proxy elsewhere (a small Cloudflare Worker works well).
- **Inside an existing site** — the component is self-contained and self-styles. Import `App` and mount it inside a router; it will not leak styles because every rule is scoped under `.lms`.
