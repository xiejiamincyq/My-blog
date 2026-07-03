drop policy if exists "Users can read own post likes" on public.post_likes;
create policy "Users can read own post likes"
on public.post_likes for select
using (user_id = auth.uid());
