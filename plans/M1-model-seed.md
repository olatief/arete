# M1 — Model + seed (1 day)

**Goal:** the five content tables with all constraints, plus a seed of the real
Arête K12 tree and the complete Kindness · Grade 6 lesson as the canonical fixture.
That lesson gets used everywhere from here on — tests, screenshots, presenter demos —
because a complete worked specimen catches modeling mistakes the abstract schema hides.

## 1. Migrations

Create in this order (FK dependencies):

```ruby
create_table :tracks do |t|
  t.string  :slug, null: false            # mizan | arete | ihsan
  t.string  :name, null: false
  t.integer :position, null: false
  t.timestamps
  t.index :slug, unique: true
end

create_table :units do |t|
  t.references :track, null: false, foreign_key: true
  t.integer :grade, null: false           # K = 0
  t.string  :title, null: false
  t.integer :position, null: false
  t.timestamps
end

create_table :lessons do |t|
  t.references :unit, null: false, foreign_key: true
  t.integer  :position, null: false
  t.string   :code, null: false
  t.string   :locale, null: false, default: "en"   # en | ar
  t.string   :title, null: false
  t.text     :prime                        # read-before-you-teach brief
  t.text     :close_prompt                 # exit question
  t.integer  :estimated_minutes
  t.text     :tags, array: true, default: [], null: false
  t.datetime :published_at                 # nil = draft
  t.timestamps
  t.index [:code, :locale], unique: true
  t.index :tags, using: :gin
end

create_table :slides do |t|
  t.references :lesson, null: false, foreign_key: true
  t.integer :page_number, null: false      # 1-based; IS the ordering
  t.text    :notes                         # private teacher script
  t.timestamps
  t.index [:lesson_id, :page_number], unique: true
end

create_table :teach_sessions do |t|
  t.references :lesson,  null: true, foreign_key: true   # null until paired
  t.references :teacher, null: true, foreign_key: { to_table: :users }
  t.string   :pairing_code                 # nulled on pair — single use
  t.integer  :current_page, null: false, default: 1
  t.datetime :paired_at
  t.datetime :expires_at, null: false
  t.datetime :last_seen_at
  t.timestamps
  t.index :pairing_code, unique: true, where: "pairing_code IS NOT NULL"
end
```

No `position` column on slides, no status enum on lessons, no Material model —
these are deliberate (CLAUDE.md invariants).

## 2. Models

- `Track` / `Unit` / `Lesson` / `Slide` associations; `Slide` default scope or
  explicit `order(:page_number)` association on `Lesson` (`has_many :slides, -> { order(:page_number) }`).
- `Lesson`: `has_one_attached :deck`, `has_many_attached :materials`,
  `scope :published, -> { where.not(published_at: nil) }`,
  validations mirroring the DB constraints, locale inclusion in `%w[en ar]`.
- `Slide`: `has_one_attached :image`.
- `TeachSession`: `generate_pairing_code` using Crockford base32 (6 chars,
  `SecureRandom`, alphabet excluding `0 O 1 I L U`), `paired?`, `expired?`,
  `scope :claimable, -> { where(lesson_id: nil).where("expires_at > now()").where.not(pairing_code: nil) }`.
  (Full pairing behavior lands in M4; the model API is defined now so seeds and
  tests can exercise it.)
- Full-text search scaffold on `Lesson` (used in M2):
  `scope :search, ->(q) { where("to_tsvector('english', coalesce(title,'') || ' ' || coalesce(prime,'')) @@ websearch_to_tsquery('english', ?)", q) }`.

## 3. Seeds — from the real curriculum

Sources are in `docs/`:

- **`docs/arete-k12-curriculum.pdf`** → the `Track → Unit → Lesson` tree. Read the
  PDF and generate `db/seeds/arete_tree.rb` with the real track/unit/grade/lesson
  titles and codes. Titles only — `prime`/`close_prompt`/slides stay empty for most
  rows at this stage. Mark them all drafts (`published_at: nil`) except the fixture
  lesson below.
- **`docs/mizan-kindness-lesson-en.pdf`** (*One Lesson, End to End*, Kindness ·
  Grade 6) → one **fully populated** lesson: real `prime`, `close_prompt`,
  `estimated_minutes`, `tags`, and a `Slide` row per page with the real teacher
  notes transcribed. Publish it. If the source deck PDF is available attach it as
  `deck`; otherwise generate a placeholder 16:9 PDF with the right page count so
  M3's ingest job has something real to chew on, and attach placeholder page
  images to each slide so M2/M4 can render before M3 exists.
- Keep the M0 super_admin seed; add one `School` and one `teacher` user for
  development sign-in.

Structure seeds idempotently (`find_or_create_by!` on natural keys) so `db:seed`
is re-runnable.

## 4. Fixtures/tests

- Model tests for: `UNIQUE (code, locale)`, `UNIQUE (lesson_id, page_number)`,
  published scope, tag array default, pairing-code uniqueness partial index,
  Crockford alphabet (no ambiguous glyphs), claimable scope.
- Make the Kindness lesson the canonical fixture used by later system tests
  (extract to fixtures or a `test/support/kindness_lesson.rb` builder that mirrors
  the seed).

## Acceptance checks

- [ ] `bin/rails db:reset` builds the full tree; re-running `db:seed` is a no-op.
- [ ] Kindness · Grade 6 exists with all pages, notes, and attached images, and is
      the only published lesson.
- [ ] All uniqueness constraints proven by tests at the DB level (not just AR
      validations).
- [ ] `Lesson.search("kindness")` returns the fixture lesson.
