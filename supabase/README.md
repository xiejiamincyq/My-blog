# Supabase setup

This folder contains the database migration and Edge Function source for the blog admin system.

## Required environment variables

Frontend:

```text
PUBLIC_SUPABASE_URL=
PUBLIC_SUPABASE_ANON_KEY=
PUBLIC_SUPABASE_ADMIN_FUNCTION_URL=
```

Supabase Edge Function secrets:

```text
SUPABASE_URL=
SUPABASE_SECRET_KEY=
GITHUB_TOKEN=
GITHUB_OWNER=xiejiamincyq
GITHUB_REPO=My-blog
```

`SUPABASE_SECRET_KEY` should be a new Supabase secret key (`sb_secret_...`). The function also
supports Supabase's default `SUPABASE_SECRET_KEYS` JSON value and falls back to the legacy
`SUPABASE_SERVICE_ROLE_KEY` only for older projects.

## Setup order

1. Create a Supabase project.
2. Run the SQL files in `supabase/migrations/` in order.
3. Enable GitHub auth in Supabase Auth providers.
4. Sign in once on the blog, then set your own profile row to `role = 'admin'`:
   ```sql
   update public.profiles
   set role = 'admin'
   where email = 'your-email@example.com';
   ```
5. Create a public Storage bucket for background images if you want uploads.
6. Deploy the `admin-github` Edge Function with JWT verification enabled.
7. Add the public Supabase environment variables to GitHub Pages build settings or local `.env`.

The blog remains fully public. Only commenting and `/admin` require login. Post likes are public
and can be added by logged-in users or by one anonymous browser identity per post.
