create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  display_name text,
  avatar_url text,
  role text not null default 'user' check (role in ('user', 'admin')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.comments (
  id uuid primary key default gen_random_uuid(),
  post_slug text not null,
  user_id uuid not null references auth.users(id) on delete cascade,
  author_name text not null,
  author_avatar text,
  content text not null check (char_length(content) between 1 and 2000),
  status text not null default 'visible' check (status in ('visible', 'hidden', 'deleted', 'pending')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.post_views (
  id uuid primary key default gen_random_uuid(),
  post_slug text not null,
  visitor_hash text not null,
  viewed_at timestamptz not null default now()
);

create table if not exists public.site_profile (
  id boolean primary key default true,
  display_name text not null default '虾米',
  bio text not null default '记录想法、阅读、技术与生活的个人空间。',
  about_markdown text not null default '这里是虾米的博客。',
  email text,
  social_links jsonb not null default '[]'::jsonb,
  updated_at timestamptz not null default now(),
  constraint site_profile_singleton check (id)
);

create table if not exists public.site_theme (
  id boolean primary key default true,
  light_background_url text,
  dark_background_url text,
  use_image_background boolean not null default false,
  overlay_strength numeric not null default 0.5 check (overlay_strength >= 0 and overlay_strength <= 1),
  updated_at timestamptz not null default now(),
  constraint site_theme_singleton check (id)
);

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles
    where id = auth.uid()
      and role = 'admin'
  );
$$;

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email, display_name, avatar_url)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data->>'user_name', new.raw_user_meta_data->>'name', split_part(new.email, '@', 1)),
    new.raw_user_meta_data->>'avatar_url'
  )
  on conflict (id) do update
    set email = excluded.email,
        display_name = coalesce(excluded.display_name, public.profiles.display_name),
        avatar_url = coalesce(excluded.avatar_url, public.profiles.avatar_url),
        updated_at = now();

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert or update on auth.users
for each row execute function public.handle_new_user();

drop trigger if exists profiles_touch_updated_at on public.profiles;
create trigger profiles_touch_updated_at
before update on public.profiles
for each row execute function public.touch_updated_at();

drop trigger if exists comments_touch_updated_at on public.comments;
create trigger comments_touch_updated_at
before update on public.comments
for each row execute function public.touch_updated_at();

drop trigger if exists site_profile_touch_updated_at on public.site_profile;
create trigger site_profile_touch_updated_at
before update on public.site_profile
for each row execute function public.touch_updated_at();

drop trigger if exists site_theme_touch_updated_at on public.site_theme;
create trigger site_theme_touch_updated_at
before update on public.site_theme
for each row execute function public.touch_updated_at();

insert into public.site_profile (id)
values (true)
on conflict (id) do nothing;

insert into public.site_theme (id)
values (true)
on conflict (id) do nothing;

insert into storage.buckets (id, name, public)
values ('site-assets', 'site-assets', true)
on conflict (id) do update set public = true;

create index if not exists comments_post_slug_created_at_idx on public.comments (post_slug, created_at desc);
create index if not exists comments_status_idx on public.comments (status);
create index if not exists post_views_post_slug_viewed_at_idx on public.post_views (post_slug, viewed_at desc);

alter table public.profiles enable row level security;
alter table public.comments enable row level security;
alter table public.post_views enable row level security;
alter table public.site_profile enable row level security;
alter table public.site_theme enable row level security;

drop policy if exists "Profiles are visible to self and admins" on public.profiles;
create policy "Profiles are visible to self and admins"
on public.profiles for select
using (id = auth.uid() or public.is_admin());

drop policy if exists "Users can update their profile" on public.profiles;
create policy "Users can update their profile"
on public.profiles for update
using (id = auth.uid())
with check (id = auth.uid() and role = (select role from public.profiles where id = auth.uid()));

drop policy if exists "Admins can update profiles" on public.profiles;
create policy "Admins can update profiles"
on public.profiles for update
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "Visible comments are public" on public.comments;
create policy "Visible comments are public"
on public.comments for select
using (status = 'visible' or user_id = auth.uid() or public.is_admin());

drop policy if exists "Logged in users can comment" on public.comments;
create policy "Logged in users can comment"
on public.comments for insert
with check (auth.uid() = user_id and status in ('visible', 'pending'));

drop policy if exists "Users can soft delete own comments" on public.comments;
create policy "Users can soft delete own comments"
on public.comments for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id and status in ('visible', 'deleted'));

drop policy if exists "Admins can manage comments" on public.comments;
create policy "Admins can manage comments"
on public.comments for all
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "Anyone can insert views" on public.post_views;
create policy "Anyone can insert views"
on public.post_views for insert
with check (true);

drop policy if exists "View counts are readable" on public.post_views;
create policy "View counts are readable"
on public.post_views for select
using (true);

drop policy if exists "Site profile is public" on public.site_profile;
create policy "Site profile is public"
on public.site_profile for select
using (true);

drop policy if exists "Admins can edit site profile" on public.site_profile;
create policy "Admins can edit site profile"
on public.site_profile for update
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "Site theme is public" on public.site_theme;
create policy "Site theme is public"
on public.site_theme for select
using (true);

drop policy if exists "Admins can edit site theme" on public.site_theme;
create policy "Admins can edit site theme"
on public.site_theme for update
using (public.is_admin())
with check (public.is_admin());

create or replace view public.post_view_counts
with (security_invoker = true) as
select
  post_slug,
  count(*)::bigint as total_views,
  count(*) filter (where viewed_at >= now() - interval '7 days')::bigint as views_7d,
  count(*) filter (where viewed_at >= now() - interval '30 days')::bigint as views_30d,
  max(viewed_at) as last_viewed_at
from public.post_views
group by post_slug;

grant usage on schema public to anon, authenticated;
grant select on public.comments, public.post_views, public.post_view_counts, public.site_profile, public.site_theme to anon, authenticated;
grant insert on public.post_views to anon, authenticated;
grant insert, update on public.comments to authenticated;
grant select, update on public.profiles, public.site_profile, public.site_theme to authenticated;

drop policy if exists "Site assets are public" on storage.objects;
create policy "Site assets are public"
on storage.objects for select
using (bucket_id = 'site-assets');

drop policy if exists "Admins can upload site assets" on storage.objects;
create policy "Admins can upload site assets"
on storage.objects for insert
with check (bucket_id = 'site-assets' and public.is_admin());

drop policy if exists "Admins can update site assets" on storage.objects;
create policy "Admins can update site assets"
on storage.objects for update
using (bucket_id = 'site-assets' and public.is_admin())
with check (bucket_id = 'site-assets' and public.is_admin());

drop policy if exists "Admins can delete site assets" on storage.objects;
create policy "Admins can delete site assets"
on storage.objects for delete
using (bucket_id = 'site-assets' and public.is_admin());
