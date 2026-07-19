-- Sunday League profile-picture upload repair
-- Run once in Supabase Dashboard -> SQL Editor.

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'avatars',
  'avatars',
  false,
  5242880,
  array[
    'image/jpeg',
    'image/png',
    'image/webp'
  ]
)
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- Remove every older avatar-policy variant used by previous project versions.
drop policy if exists "Friends view football images" on storage.objects;
drop policy if exists "Users upload own football images" on storage.objects;
drop policy if exists "Users update own football images" on storage.objects;
drop policy if exists "Users delete own football images" on storage.objects;
drop policy if exists "Friends view avatar images" on storage.objects;
drop policy if exists "Users upload own avatar images" on storage.objects;
drop policy if exists "Users update own avatar images" on storage.objects;
drop policy if exists "Users delete own avatar images" on storage.objects;

create policy "Friends view avatar images"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'avatars'
);

create policy "Users upload own avatar images"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] =
    (select auth.uid()::text)
);

create policy "Users update own avatar images"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] =
    (select auth.uid()::text)
)
with check (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] =
    (select auth.uid()::text)
);

create policy "Users delete own avatar images"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] =
    (select auth.uid()::text)
);
