alter table public.perfiles
  add column if not exists avatar_path  text check (char_length(avatar_path) <= 200),
  add column if not exists frase        text not null default '' check (char_length(frase) <= 120),
  add column if not exists color_acento text not null default 'azul' check (color_acento in ('azul','verde','morado','coral','turquesa','rosa')),
  add column if not exists tema         text not null default 'auto' check (tema in ('auto','claro','oscuro'));

-- Fotos de perfil: espacio privado, máx. 2 MB, solo imágenes
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('avatares', 'avatares', false, 2097152, array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set public = false, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

-- Cada usuario solo maneja los archivos de su propia carpeta: avatares/<su id>/...
drop policy if exists "avatar: ver el propio" on storage.objects;
create policy "avatar: ver el propio" on storage.objects for select to authenticated
  using (bucket_id = 'avatares' and (storage.foldername(name))[1] = (select auth.uid())::text);
drop policy if exists "avatar: subir el propio" on storage.objects;
create policy "avatar: subir el propio" on storage.objects for insert to authenticated
  with check (bucket_id = 'avatares' and (storage.foldername(name))[1] = (select auth.uid())::text);
drop policy if exists "avatar: cambiar el propio" on storage.objects;
create policy "avatar: cambiar el propio" on storage.objects for update to authenticated
  using (bucket_id = 'avatares' and (storage.foldername(name))[1] = (select auth.uid())::text)
  with check (bucket_id = 'avatares' and (storage.foldername(name))[1] = (select auth.uid())::text);
drop policy if exists "avatar: quitar el propio" on storage.objects;
create policy "avatar: quitar el propio" on storage.objects for delete to authenticated
  using (bucket_id = 'avatares' and (storage.foldername(name))[1] = (select auth.uid())::text);
