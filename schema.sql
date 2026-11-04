-- Mis Quincenas: tablas y reglas de seguridad.
-- Pégalo completo en Supabase → SQL Editor → New query → Run.

create table if not exists public.perfiles (
  user_id    uuid primary key references auth.users(id) on delete cascade,
  config     jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

create table if not exists public.movimientos (
  id      uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  fecha   date not null,
  tipo    text not null check (tipo in ('gasto','ingreso','ahorro')),
  cat     text not null,
  monto   bigint not null check (monto > 0),
  nota    text not null default '',
  creado  timestamptz not null default now()
);
create index if not exists movimientos_user_fecha on public.movimientos (user_id, fecha desc);

-- Cada persona solo puede ver y cambiar sus propios datos.
alter table public.perfiles    enable row level security;
alter table public.movimientos enable row level security;

drop policy if exists "perfil propio" on public.perfiles;
create policy "perfil propio" on public.perfiles
  for all to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "movimientos propios" on public.movimientos;
create policy "movimientos propios" on public.movimientos
  for all to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Sincronización en vivo entre dispositivos.
do $$ begin
  alter publication supabase_realtime add table public.perfiles, public.movimientos;
exception when duplicate_object then null; end $$;
