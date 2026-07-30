# M0 — Skeleton (½ day)

**Goal:** a deployed hello-world on Render Frankfurt with auth, roles, correct cable
configuration, and the RTL lint in place. Everything risky about configuration is
settled here so later milestones are pure feature work.

## 0. Repo layout — already done

The repo is initialized and organized: reference material lives in `docs/`,
`CLAUDE.md` and `plans/` at the root, and a minimal `.gitignore` (`.DS_Store`)
exists. One consequence for step 1: `rails new .` will ask before overwriting
`.gitignore` — accept the overwrite, then re-append `.DS_Store` to the generated
file.

## 1. Generate the app (in place)

```bash
rails new . --database=postgresql --css=tailwind --skip-kamal --skip-solid
```

- Pin in `Gemfile` / `.ruby-version`: **Ruby 3.4.10**, **Rails ~> 8.1.3** (do not
  accept Ruby 4.x even if installed).
- `--skip-solid` then install Solid Queue + Solid Cache explicitly (next section) so
  Solid Cable is never added.
- Importmap + Propshaft are the defaults — verify no `vite`/`node` artifacts exist.
- Add gems: `pundit` (~> 2.5), `image_processing` (~> 2.0), `ruby-vips`.

## 2. Solid Queue + Solid Cache (no Redis, no Solid Cable)

- `bin/rails solid_queue:install solid_cache:install`, run the installers'
  migrations (they may target a separate schema file — keep everything in the one
  primary database per the stack decision).
- Run Solid Queue **inside Puma**: in `config/puma.rb` add
  `plugin :solid_queue` (guarded by `ENV["SOLID_QUEUE_IN_PUMA"]` if preferred);
  `config.active_job.queue_adapter = :solid_queue` in application config.
- Cache store: `config.cache_store = :solid_cache_store` in **development and
  production**. This is load-bearing — `rate_limit` in M4 needs a store with atomic
  increment, and the generated `:memory_store` in development is per-process and
  silently wrong.

## 3. `config/cable.yml` — the one file that must not be left as generated

```yml
development: { adapter: postgresql }
test:        { adapter: test }
production:  { adapter: postgresql }
```

`rails new` writes `async` for development; `async` is per-process, so with 2+ Puma
workers the phone and board land in different processes and sync silently breaks.
Set `postgresql` in development too, or the bug is invisible until deploy.

## 4. Auth + roles

1. `bin/rails generate authentication` (Rails 8 built-in: `User`, `Session`,
   password reset, and an ActionCable `connection.rb` that works out of the box).
2. Migration on `users`: add `school_id` (nullable FK — super_admins belong to no
   school), `role` (string, null: false, default `"teacher"`), `ui_locale`
   (string, default `"en"`). Create the `School` model now too:
   `name, country, timezone` (real Unit/Lesson tables wait for M1).
3. `enum :role, { teacher: "teacher", school_admin: "school_admin", super_admin: "super_admin" }`
   backed by the string column.
4. Install Pundit: `ApplicationPolicy`, include in `ApplicationController`,
   `after_action :verify_authorized` where appropriate. One smoke policy is enough
   for M0; real policies come with their resources.
5. Seed one super_admin from ENV credentials.

## 5. Layout + i18n scaffolding (rule 3 & 4 from CLAUDE.md)

- Application layout opens with
  `<html lang="<%= I18n.locale %>" dir="<%= I18n.locale.to_s == "ar" ? "rtl" : "ltr" %>">`
  (extract a `rtl?` helper).
- Create `config/locales/en.yml` structure and put the first strings (app name,
  sign-in labels) there. No hardcoded English in any view, starting now.

## 6. `bin/lint-rtl` + CI

Executable script that greps `app/` for forbidden directional utilities and fails
non-zero on any hit not annotated `rtl-ok` on the same line:

```
\b-?[mp][lr]-
\b(left|right)-
\btext-(left|right)\b
\b(border|rounded|float|divide|space|inset)-(x-|[lr]\b|t[lr]\b|b[lr]\b)
```

Add a GitHub Actions workflow (`.github/workflows/ci.yml`) that runs
`bin/lint-rtl`, `bin/rails test`, and `bin/rails test:system` on push.

## 7. Deploy to Render Frankfurt

- `render.yaml`: one web service (Starter, Frankfurt), one Postgres (Basic-1GB,
  Frankfurt). Health check path `/up`.
- **Do not enable Render's connection pooler** — connect on 5432. `LISTEN/NOTIFY`
  (the cable adapter) breaks under PgBouncer transaction mode.
- `RAILS_MASTER_KEY`, `DATABASE_URL` env wiring; migrations in the pre-deploy or
  release phase.
- Verify after deploy: sign-in works, `/up` returns 200, and — important — open a
  `rails console` on the deployed box and confirm
  `ActionCable.server.config.cable[:adapter] == "postgresql"`.

## Acceptance checks

- [ ] `bin/dev` boots locally; sign in as seeded super_admin works.
- [ ] `config/cable.yml` says `postgresql` for development **and** production.
- [ ] `Rails.cache.increment("x")` works in development console (Solid Cache).
- [ ] A background job (`SELECT 1` test job) executes with only `bin/dev` running
      (Solid Queue is in-process — no separate worker needed).
- [ ] `bin/lint-rtl` passes, and fails when a scratch view containing `ml-4` is added.
- [ ] App is live on Render Frankfurt; `/up` is green; deploy is repeatable.
