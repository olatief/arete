# Arête LMS — A Guide for Adding Lessons

> **⚠️ Partially superseded.** The app this guide describes (the React
> prototype's Instructor builder) is retired — the MVP authoring flow is
> defined in `STACK-DECISION.md` §3. Sections **4–5** (the Arête lesson-writing
> pedagogy and quiz-writing craft) remain current and are the reason this file
> is kept.

For anyone who wants to build lessons in Arête without touching code. If you can use a Google Doc, you can use this.

---

## 1. The two doors

When the app opens, look at the top of the screen. You will see two buttons: **Student** and **Instructor**.

- **Student** is what a learner sees. Video, slides, quiz, downloads. Locked until the previous lesson's quiz is passed.
- **Instructor** is where you build and edit. This guide lives here.

Click **Instructor** at the top. The Builder opens.

---

## 2. How the course is put together

Think of it like a bookshelf.

```
The course        (the whole shelf)
   └── Modules   (individual books)
         └── Lessons   (chapters in each book)
                 ├── Video          (one YouTube video)
                 ├── Slides         (as many as you need)
                 ├── Quiz           (questions the student must answer)
                 └── Materials      (downloadable links — PDFs, decks, etc.)
```

You always work from the left side to build the structure, and the right side to fill in the content.

---

## 3. Your first ten minutes — build one lesson

### Step 1 — Name the course

Top of the left sidebar you'll see two text boxes: the course title and subtitle. Click them and type. It saves as you type.

### Step 2 — Add a module

Scroll to the bottom of the sidebar. Click **+ Add module**. A "New Module" appears. Click on its title in the sidebar and rename it to whatever you want (e.g. "Module I — The Self and Its Agency").

### Step 3 — Add a lesson

Under the module you just made, click **+ Add lesson**. A "New Lesson" appears in the sidebar. Click it — the editor on the right opens.

### Step 4 — Fill in the basics

At the top of the editor:

- **Title** — the lesson name (e.g. *The Question of Agency*).
- **Grade / band** — e.g. *Grade 10*.
- **Central question** — the one Socratic question the lesson turns around. Write it as a real question the student would live with.
- **Summary** — 2–4 sentences shown to the student under the video.

### Step 5 — Add the video

Scroll to the **Video** section. Paste a YouTube link — any of these formats work:

- `https://www.youtube.com/watch?v=…`
- `https://youtu.be/…`
- Just the video ID (the string of letters/numbers)

When the app recognizes it, you'll see a small green line: *"Detected video ID: …"*. If it stays red, the link isn't a YouTube URL — try again.

### Step 6 — Add slides

Scroll to **Slides**. Click **+ Add slide**. Fill in a title and a body. Repeat.

Slides render one at a time to the student — big title, clean body text. Keep bodies short: 3–5 sentences at most. If you need more, use another slide.

### Step 7 — Build the quiz

Scroll to **Quiz**. Set the **Pass at …%** at the top (default 70). Students who don't reach that can't unlock the next lesson.

Click **+ Add question**. Type the question. Fill in the answer options.

**To mark the correct answer**: each option has a small circle on its left. Click the circle for the correct one — it turns green with a checkmark.

Add an **Explanation** underneath — this shows the student *after* they submit, whether they got it right or wrong. Explanations are where the teaching happens.

### Step 8 — Add downloadable materials

Scroll to **Downloadable materials**. Click **+ Add**. Give it a label (e.g. "Reading — Frankfurt excerpt") and paste a link to a Google Drive file, a PDF, or wherever it lives.

### Step 9 — Preview it

Go to the top of the screen and click **Student**. You're now seeing exactly what a learner sees. Play through the lesson yourself. Come back to **Instructor** to fix anything that doesn't feel right.

---

## 4. What makes a lesson feel Arête (writing slides that work)

The Arête pattern for a lesson is five moves. Not every lesson needs all five, but this order tends to work.

**1. Phenomenology (open here).** Before you name anything, invite the student into a lived experience. "Think of a moment when…" "Bring to mind…" "Which of these two mornings felt more like you?" Two or three slides. No concepts yet. Just feeling.

**2. Naming.** Now name what they just felt. Give the felt thing a word. ("You just felt the difference between two ways of being alive…")

**3. Distinction.** What the thing is *not*. This is where students most often collapse the concept into a familiar one — head this off early.

**4. Depth.** Bring in the classical sources and philosophers. Ibn Sīnā, al-Ghazālī, Frankfurt, Frankl, Aristotle — whoever fits. Never as name-dropping. Only as: *here is someone else who saw what you just felt.*

**5. Return.** Close with a question the student must now carry. Ideally, some version of the curriculum's central question: *who are you becoming — and is that who you were meant to be?*

**Rule of thumb**: never start with a definition. If the first slide is "Agency is…", you've already lost the phenomenological ground. Start with two mornings, or a moment, or an image. Then name.

---

## 5. Writing quizzes that actually test understanding

Bad questions ask what the slide said. Good questions ask what the student now understands.

**Bad** — *"Who wrote the Book of Salvation?"*
**Good** — *"According to the lesson, which of these is closest to agency?"*

**Bad** — *"How many false sovereigns did we discuss?"*
**Good** — *"Which of these is the lesson's example of the Market choosing for you?"*

Aim for questions that a student who *only memorized* couldn't answer — but a student who *actually understood* could.

Use the Explanation field to teach a little more, even when the student got it right. That's often the highest-leverage sentence in the whole lesson.

---

## 6. Reordering things

In the sidebar, next to each lesson, you'll see small **↑** and **↓** arrows. They move the lesson up and down inside its module. That's how you set the sequence.

The order in the sidebar is the order students walk through. Lesson 1 unlocks Lesson 2, which unlocks Lesson 3, and so on.

---

## 7. The Teaching Assistant (the ✦ button)

Bottom-right of the Instructor view, a small dark button says **✦ Teaching Assistant**. Click it. A panel slides in from the right.

At the top of the panel are three quick actions:

- **Generate quiz for this lesson** — reads the lesson you're currently editing, drafts three quiz questions in the Arête voice.
- **Draft slides** — drafts four teaching slides for the lesson.
- **Discussion questions** — proposes Socratic questions for a live seminar.

After it generates something, you'll see a small **＋ Insert into lesson** button under its reply. Click it — the slides or quiz questions are added to the lesson you're editing. You can then edit them like anything else.

You can also just talk to it. Ask things like:

- *"What's a good phenomenological opening for a Grade 8 lesson on envy?"*
- *"Rewrite this slide to feel less didactic."*
- *"What would al-Ghazālī say about this?"*

The assistant is trained on the Arête pedagogy — Socratic, phenomenological, feeling-first, non-moralizing. It won't sound like a corporate training deck.

**Important**: always read what it drafts before inserting. Sometimes it's exactly right. Sometimes it needs your voice on top of its scaffolding. Treat it like a junior collaborator, not an oracle.

---

## 8. Saving your work — read this

- **Inside the Claude app**: everything saves automatically. You'll see a small green dot at the top saying *Saved automatically*.
- **Anywhere else (a website your programmer set up)**: the top will say *Preview · export to save*. That means auto-save is off. **You must Export.**

### How to Export (the backup button)

Bottom-left of the sidebar are two small buttons: **⬆ Export** and **⬇ Import**.

**⬆ Export** downloads your entire course as a single `.json` file. Save it. Rename it with the date (e.g. `arete-2026-07-16.json`). Do this often.

**⬇ Import** loads a `.json` file back in. This is how you restore a backup, move between machines, or share a course with someone else.

**Rule**: export before any big edit. Export at the end of every work session. If auto-save is off and you close the tab without exporting, your work is gone.

---

## 9. Deleting things

- **Delete a lesson** — open the lesson in the editor. At the bottom is a red "Delete lesson" button.
- **Delete a module** — in the sidebar, there's a small ✕ next to the module title.
- **Delete a slide, quiz question, or resource** — each block in the editor has its own "Remove" button.

The app will ask you to confirm. There is no undo. When in doubt, Export first.

---

## 10. A few practical tips

- **Write slides in a doc first.** It's easier to draft prose in Google Docs and paste it in than to write directly in the app.
- **Keep slide bodies short.** If a slide's body is more than 5 sentences, split it into two slides.
- **The Central Question is the whole lesson.** If you get this one line right, the rest of the lesson tends to fall into place. Spend more time on it than on anything else.
- **Use the Explanation field as a teaching moment.** It's the last thing the student sees in the quiz — treat it as the closing of the lesson, not a footnote.
- **Test as a student, always.** Before you release a lesson, switch to Student view and walk through it. Feel the pacing.

---

## 11. If something goes wrong

- **The app won't load** — refresh the page. If that fails, ask your programmer to check the browser console.
- **The video is blank** — the YouTube link probably isn't valid. Copy it fresh from YouTube and paste again. Watch for the green *Detected video ID* line.
- **A quiz won't save** — make sure every question has a correct answer marked (green circle) and at least two options filled in.
- **The Teaching Assistant says it can't reach the model** — this happens outside the Claude app when your programmer hasn't wired the API. Ask them to set up the AI proxy (§7 of the Developer Guide).
- **I closed the tab without exporting and lost my work** — if you're inside the Claude app, everything is still there. Otherwise, unfortunately, it's gone. This is why we export.

---

Any working teacher can run this. The app is the vessel. The lesson is you.
