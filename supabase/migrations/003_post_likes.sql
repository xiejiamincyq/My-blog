create table if not exists public.post_likes (
  id uuid primary key default gen_random_uuid(),
  post_slug text not null,
  user_id uuid references auth.users(id) on delete cascade,
  anonymous_id text,
  created_at timestamptz not null default now(),
  constraint post_likes_identity_check check (
    (user_id is not null and anonymous_id is null)
    or (user_id is null and anonymous_id is not null)
  ),
  constraint post_likes_anonymous_format_check check (
    anonymous_id is null or anonymous_id ~ '^[a-f0-9]{64}$'
  )
);

create index if not exists post_likes_post_slug_idx on public.post_likes (post_slug);
create unique index if not exists post_likes_user_once_idx
on public.post_likes (post_slug, user_id)
where user_id is not null;
create unique index if not exists post_likes_anonymous_once_idx
on public.post_likes (post_slug, anonymous_id)
where anonymous_id is not null;

alter table public.post_likes enable row level security;

drop policy if exists "Admins can read post likes" on public.post_likes;
create policy "Admins can read post likes"
on public.post_likes for select
using (public.is_admin());

create or replace view public.post_like_counts as
select
  post_slug,
  count(*)::bigint as total_likes,
  max(created_at) as last_liked_at
from public.post_likes
group by post_slug;

create or replace function public.get_post_like_state(
  target_post_slug text,
  target_anonymous_id text default null
)
returns table(total_likes bigint, liked boolean)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  current_user_id uuid := auth.uid();
  normalized_slug text := trim(coalesce(target_post_slug, ''));
  normalized_anonymous_id text := lower(nullif(trim(coalesce(target_anonymous_id, '')), ''));
begin
  if normalized_slug = '' then
    raise exception 'post_slug is required';
  end if;

  if current_user_id is null and normalized_anonymous_id is null then
    raise exception 'anonymous_id is required';
  end if;

  if normalized_anonymous_id is not null and normalized_anonymous_id !~ '^[a-f0-9]{64}$' then
    raise exception 'anonymous_id is invalid';
  end if;

  return query
  select
    count(*)::bigint as total_likes,
    exists (
      select 1
      from public.post_likes
      where post_slug = normalized_slug
        and (
          (current_user_id is not null and user_id = current_user_id)
          or (normalized_anonymous_id is not null and anonymous_id = normalized_anonymous_id)
        )
    ) as liked
  from public.post_likes
  where post_slug = normalized_slug;
end;
$$;

create or replace function public.like_post(
  target_post_slug text,
  target_anonymous_id text default null
)
returns table(total_likes bigint, liked boolean)
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid := auth.uid();
  normalized_slug text := trim(coalesce(target_post_slug, ''));
  normalized_anonymous_id text := lower(nullif(trim(coalesce(target_anonymous_id, '')), ''));
begin
  if normalized_slug = '' then
    raise exception 'post_slug is required';
  end if;

  if current_user_id is null and normalized_anonymous_id is null then
    raise exception 'anonymous_id is required';
  end if;

  if normalized_anonymous_id is not null and normalized_anonymous_id !~ '^[a-f0-9]{64}$' then
    raise exception 'anonymous_id is invalid';
  end if;

  if current_user_id is not null and normalized_anonymous_id is not null then
    update public.post_likes
    set user_id = current_user_id,
        anonymous_id = null
    where post_slug = normalized_slug
      and anonymous_id = normalized_anonymous_id
      and not exists (
        select 1
        from public.post_likes
        where post_slug = normalized_slug
          and user_id = current_user_id
      );

    if found then
      return query
      select *
      from public.get_post_like_state(normalized_slug, normalized_anonymous_id);
      return;
    end if;
  end if;

  begin
    insert into public.post_likes (post_slug, user_id, anonymous_id)
    values (
      normalized_slug,
      current_user_id,
      case when current_user_id is null then normalized_anonymous_id else null end
    );
  exception
    when unique_violation then
      null;
  end;

  return query
  select *
  from public.get_post_like_state(normalized_slug, normalized_anonymous_id);
end;
$$;

grant select on public.post_like_counts to anon, authenticated;
grant select on public.post_likes to authenticated;
grant execute on function public.get_post_like_state(text, text) to anon, authenticated;
grant execute on function public.like_post(text, text) to anon, authenticated;
