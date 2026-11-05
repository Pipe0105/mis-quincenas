-- Estructura completa: tablas por usuario, papelera (borrado_en), historial, validaciones,
-- seguridad por usuario (RLS) y cálculos en la base.
drop table if exists public.movimientos cascade;
drop table if exists public.perfiles cascade;

create or replace function public.tocar_actualizado() returns trigger
language plpgsql set search_path = '' as $$
begin new.actualizado_en := now(); return new; end $$;

create or replace function public.quincena_de(d date) returns text
language sql immutable set search_path = '' as $$
  select to_char(d, 'YYYY-MM') || '-' || case when extract(day from d) <= 15 then '1' else '2' end
$$;

create table public.perfiles (
  user_id                uuid primary key default auth.uid() references auth.users(id) on delete cascade,
  nombre                 text not null default '' check (char_length(nombre) <= 80),
  salario_mensual        bigint not null default 0 check (salario_mensual >= 0),
  pct_seguridad_social   numeric(5,2) not null default 8 check (pct_seguridad_social between 0 and 100),
  otros_ingresos_mensual bigint not null default 0 check (otros_ingresos_mensual >= 0),
  configurado            boolean not null default false,
  creado_en              timestamptz not null default now(),
  actualizado_en         timestamptz not null default now()
);

create table public.metas (
  id               uuid primary key default gen_random_uuid(),
  user_id          uuid not null default auth.uid() references auth.users(id) on delete cascade,
  nombre           text not null check (char_length(nombre) between 1 and 80),
  tipo             text not null default 'otra' check (tipo in ('fondo_emergencia','compra','retiro','otra')),
  monto_objetivo   bigint not null default 0 check (monto_objetivo >= 0),
  ahorrado_inicial bigint not null default 0 check (ahorrado_inicial >= 0),
  fecha_objetivo   date,
  borrado_en       timestamptz,
  creado_en        timestamptz not null default now(),
  actualizado_en   timestamptz not null default now(),
  unique (id, user_id)
);
create unique index metas_un_fondo_por_usuario on public.metas (user_id) where tipo = 'fondo_emergencia' and borrado_en is null;

create table public.deudas (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null default auth.uid() references auth.users(id) on delete cascade,
  nombre         text not null check (char_length(nombre) between 1 and 80),
  acreedor       text not null default '' check (char_length(acreedor) <= 80),
  monto_total    bigint not null default 0 check (monto_total >= 0),
  pagado_inicial bigint not null default 0 check (pagado_inicial >= 0),
  tasa_ea        numeric(7,3) not null default 0 check (tasa_ea >= 0),
  moneda         text not null default 'COP' check (moneda in ('COP','USD')),
  nota           text not null default '' check (char_length(nota) <= 300),
  borrado_en     timestamptz,
  creado_en      timestamptz not null default now(),
  actualizado_en timestamptz not null default now(),
  unique (id, user_id)
);

create table public.cuentas (
  id                  uuid primary key default gen_random_uuid(),
  user_id             uuid not null default auth.uid() references auth.users(id) on delete cascade,
  nombre              text not null check (char_length(nombre) between 1 and 80),
  tipo                text not null default 'ahorro' check (tipo in ('ahorro','corriente','billetera','inversion','efectivo','otra')),
  entidad             text not null default '' check (char_length(entidad) <= 80),
  tasa_ea             numeric(7,3) not null default 0 check (tasa_ea >= 0),
  moneda              text not null default 'COP' check (moneda in ('COP','USD')),
  saldo_inicial       bigint not null default 0,
  fecha_saldo_inicial date not null default current_date,
  borrado_en          timestamptz,
  creado_en           timestamptz not null default now(),
  actualizado_en      timestamptz not null default now(),
  unique (id, user_id)
);

create table public.categorias (
  id                  uuid primary key default gen_random_uuid(),
  user_id             uuid not null default auth.uid() references auth.users(id) on delete cascade,
  nombre              text not null check (char_length(nombre) between 1 and 60),
  tipo                text not null check (tipo in ('gasto','ingreso','ahorro')),
  clave               text check (clave in ('salario')),
  presupuesto_mensual bigint not null default 0 check (presupuesto_mensual >= 0),
  cuando              text not null default 'ambas' check (cuando in ('ambas','q1','q2')),
  fijo                boolean not null default false,
  deuda_id            uuid,
  meta_id             uuid,
  orden               int not null default 0,
  borrado_en          timestamptz,
  creado_en           timestamptz not null default now(),
  actualizado_en      timestamptz not null default now(),
  unique (id, user_id),
  foreign key (deuda_id, user_id) references public.deudas (id, user_id),
  foreign key (meta_id, user_id)  references public.metas (id, user_id),
  check (deuda_id is null or tipo = 'gasto'),
  check (meta_id is null or tipo = 'ahorro')
);
create unique index categorias_clave_unica on public.categorias (user_id, clave) where clave is not null and borrado_en is null;
create index categorias_deuda on public.categorias (deuda_id) where deuda_id is not null;
create index categorias_meta on public.categorias (meta_id) where meta_id is not null;

create table public.movimientos (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null default auth.uid() references auth.users(id) on delete cascade,
  fecha          date not null check (fecha between '2000-01-01' and '2100-12-31'),
  tipo           text not null check (tipo in ('gasto','ingreso','ahorro')),
  categoria_id   uuid not null,
  cuenta_id      uuid,
  monto          bigint not null check (monto > 0 and monto < 1000000000000),
  nota           text not null default '' check (char_length(nota) <= 200),
  borrado_en     timestamptz,
  creado_en      timestamptz not null default now(),
  actualizado_en timestamptz not null default now(),
  foreign key (categoria_id, user_id) references public.categorias (id, user_id),
  foreign key (cuenta_id, user_id)    references public.cuentas (id, user_id)
);
create index movimientos_usuario_fecha on public.movimientos (user_id, fecha desc) where borrado_en is null;
create index movimientos_categoria on public.movimientos (categoria_id);
create index movimientos_cuenta on public.movimientos (cuenta_id) where cuenta_id is not null;

create or replace function public.validar_movimiento() returns trigger
language plpgsql set search_path = '' as $$
declare t text;
begin
  select tipo into t from public.categorias where id = new.categoria_id and user_id = new.user_id;
  if t is null then raise exception 'La categoría no existe'; end if;
  if t <> new.tipo then raise exception 'El movimiento es de tipo % pero la categoría es de tipo %', new.tipo, t; end if;
  return new;
end $$;

create table public.inversiones (
  id                    uuid primary key default gen_random_uuid(),
  user_id               uuid not null default auth.uid() references auth.users(id) on delete cascade,
  cuenta_id             uuid,
  nombre                text not null check (char_length(nombre) between 1 and 80),
  simbolo               text not null default '' check (char_length(simbolo) <= 20),
  tipo_activo           text not null default 'etf' check (tipo_activo in ('accion','etf','fic','bono','cripto','otro')),
  moneda                text not null default 'COP' check (moneda in ('COP','USD')),
  precio_actual         numeric(20,6) not null default 0 check (precio_actual >= 0),
  precio_actualizado_en timestamptz,
  nota                  text not null default '' check (char_length(nota) <= 300),
  borrado_en            timestamptz,
  creado_en             timestamptz not null default now(),
  actualizado_en        timestamptz not null default now(),
  unique (id, user_id),
  foreign key (cuenta_id, user_id) references public.cuentas (id, user_id)
);
create index inversiones_cuenta on public.inversiones (cuenta_id) where cuenta_id is not null;

create table public.operaciones_inversion (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null default auth.uid() references auth.users(id) on delete cascade,
  inversion_id   uuid not null,
  fecha          date not null,
  tipo           text not null check (tipo in ('compra','venta','dividendo','comision')),
  cantidad       numeric(24,8) not null default 0 check (cantidad >= 0),
  precio         numeric(20,6) not null default 0 check (precio >= 0),
  monto_cop      bigint not null default 0 check (monto_cop >= 0),
  nota           text not null default '' check (char_length(nota) <= 200),
  borrado_en     timestamptz,
  creado_en      timestamptz not null default now(),
  actualizado_en timestamptz not null default now(),
  foreign key (inversion_id, user_id) references public.inversiones (id, user_id)
);
create index operaciones_inversion_idx on public.operaciones_inversion (inversion_id);

create table public.historial (
  id          bigint generated always as identity primary key,
  user_id     uuid not null references auth.users(id) on delete cascade,
  tabla       text not null,
  registro_id uuid,
  accion      text not null,
  antes       jsonb,
  despues     jsonb,
  en          timestamptz not null default now()
);
create index historial_usuario_fecha on public.historial (user_id, en desc);

create or replace function public.registrar_historial() returns trigger
language plpgsql security definer set search_path = '' as $$
declare a jsonb; d jsonb; acc text;
begin
  if tg_op <> 'INSERT' then a := to_jsonb(old); end if;
  if tg_op <> 'DELETE' then d := to_jsonb(new); end if;
  if tg_op = 'UPDATE' and (a - 'actualizado_en') = (d - 'actualizado_en') then return null; end if;
  acc := case
    when tg_op = 'INSERT' then 'crear'
    when tg_op = 'DELETE' then 'eliminar'
    when (a->>'borrado_en') is null and (d->>'borrado_en') is not null then 'borrar'
    when (a->>'borrado_en') is not null and (d->>'borrado_en') is null then 'recuperar'
    else 'editar' end;
  insert into public.historial (user_id, tabla, registro_id, accion, antes, despues)
  values (coalesce(d->>'user_id', a->>'user_id')::uuid, tg_table_name,
          coalesce(d->>'id', a->>'id', d->>'user_id', a->>'user_id')::uuid, acc, a, d);
  return null;
end $$;

do $$
declare t text;
begin
  foreach t in array array['perfiles','metas','deudas','cuentas','categorias','movimientos','inversiones','operaciones_inversion'] loop
    execute format('create trigger tocar_actualizado before update on public.%I for each row execute function public.tocar_actualizado()', t);
    execute format('create trigger historial after insert or update or delete on public.%I for each row execute function public.registrar_historial()', t);
  end loop;
end $$;
create trigger validar before insert or update of tipo, categoria_id on public.movimientos
  for each row execute function public.validar_movimiento();

create or replace function public.crear_perfil_nuevo() returns trigger
language plpgsql security definer set search_path = '' as $$
begin insert into public.perfiles (user_id) values (new.id) on conflict do nothing; return new; end $$;
drop trigger if exists al_crear_usuario on auth.users;
create trigger al_crear_usuario after insert on auth.users for each row execute function public.crear_perfil_nuevo();

revoke execute on function public.registrar_historial() from public, anon, authenticated;
revoke execute on function public.crear_perfil_nuevo() from public, anon, authenticated;

do $$
declare t text;
begin
  foreach t in array array['perfiles','metas','deudas','cuentas','categorias','movimientos','inversiones','operaciones_inversion'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('create policy "ver lo propio" on public.%I for select to authenticated using ((select auth.uid()) = user_id)', t);
    execute format('create policy "crear lo propio" on public.%I for insert to authenticated with check ((select auth.uid()) = user_id)', t);
    execute format('create policy "editar lo propio" on public.%I for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id)', t);
  end loop;
end $$;
alter table public.historial enable row level security;
create policy "ver mi historial" on public.historial for select to authenticated using ((select auth.uid()) = user_id);

create view public.v_resumen_quincena with (security_invoker = true) as
select user_id, public.quincena_de(fecha) as quincena,
  coalesce(sum(monto) filter (where tipo = 'ingreso'), 0) as ingresos,
  coalesce(sum(monto) filter (where tipo = 'gasto'), 0)   as gastos,
  coalesce(sum(monto) filter (where tipo = 'ahorro'), 0)  as ahorros,
  coalesce(sum(case when tipo = 'ingreso' then monto else -monto end), 0) as neto,
  count(*) as movimientos
from public.movimientos where borrado_en is null
group by 1, 2;

create view public.v_deudas_estado with (security_invoker = true) as
select d.id, d.user_id, d.nombre, d.monto_total,
  d.pagado_inicial + coalesce(p.pagado, 0) as pagado,
  greatest(d.monto_total - d.pagado_inicial - coalesce(p.pagado, 0), 0) as restante,
  coalesce(c.pago_mensual, 0) as pago_mensual_plan,
  case when coalesce(c.pago_mensual, 0) > 0
       then ceil(greatest(d.monto_total - d.pagado_inicial - coalesce(p.pagado, 0), 0)::numeric / c.pago_mensual)::int end as meses_restantes
from public.deudas d
left join lateral (
  select sum(m.monto) as pagado from public.movimientos m join public.categorias k on k.id = m.categoria_id
  where k.deuda_id = d.id and m.borrado_en is null and m.tipo = 'gasto') p on true
left join lateral (
  select sum(presupuesto_mensual) as pago_mensual from public.categorias where deuda_id = d.id and borrado_en is null) c on true
where d.borrado_en is null;

create view public.v_metas_estado with (security_invoker = true) as
select g.id, g.user_id, g.nombre, g.tipo, g.monto_objetivo,
  g.ahorrado_inicial + coalesce(s.ahorrado, 0) as ahorrado,
  case when g.monto_objetivo > 0 then least(round((g.ahorrado_inicial + coalesce(s.ahorrado, 0)) * 100.0 / g.monto_objetivo, 1), 100) else 0 end as porcentaje,
  coalesce(c.aporte_mensual, 0) as aporte_mensual_plan,
  case when coalesce(c.aporte_mensual, 0) > 0 and g.monto_objetivo > g.ahorrado_inicial + coalesce(s.ahorrado, 0)
       then ceil((g.monto_objetivo - g.ahorrado_inicial - coalesce(s.ahorrado, 0))::numeric / c.aporte_mensual)::int end as meses_restantes
from public.metas g
left join lateral (
  select sum(m.monto) as ahorrado from public.movimientos m join public.categorias k on k.id = m.categoria_id
  where k.meta_id = g.id and m.borrado_en is null and m.tipo = 'ahorro') s on true
left join lateral (
  select sum(presupuesto_mensual) as aporte_mensual from public.categorias where meta_id = g.id and borrado_en is null) c on true
where g.borrado_en is null;

create view public.v_cuentas_saldo with (security_invoker = true) as
select a.id, a.user_id, a.nombre, a.tipo, a.entidad, a.moneda,
  a.saldo_inicial + coalesce(sum(case when m.tipo = 'gasto' then -m.monto else m.monto end), 0) as saldo
from public.cuentas a
left join public.movimientos m on m.cuenta_id = a.id and m.borrado_en is null and m.fecha >= a.fecha_saldo_inicial
where a.borrado_en is null
group by a.id;

create view public.v_inversiones_posicion with (security_invoker = true) as
select i.id, i.user_id, i.nombre, i.simbolo, i.tipo_activo, i.moneda, i.precio_actual,
  coalesce(sum(o.cantidad) filter (where o.tipo = 'compra'), 0) - coalesce(sum(o.cantidad) filter (where o.tipo = 'venta'), 0) as cantidad,
  coalesce(sum(o.monto_cop) filter (where o.tipo in ('compra','comision')), 0) - coalesce(sum(o.monto_cop) filter (where o.tipo = 'venta'), 0) as invertido_cop,
  coalesce(sum(o.monto_cop) filter (where o.tipo = 'dividendo'), 0) as dividendos_cop,
  (coalesce(sum(o.cantidad) filter (where o.tipo = 'compra'), 0) - coalesce(sum(o.cantidad) filter (where o.tipo = 'venta'), 0)) * i.precio_actual as valor_actual
from public.inversiones i
left join public.operaciones_inversion o on o.inversion_id = i.id and o.borrado_en is null
where i.borrado_en is null
group by i.id;

create or replace function public.presupuesto_quincena(q text)
returns table (categoria_id uuid, nombre text, tipo text, presupuesto numeric, gastado bigint)
language sql stable set search_path = '' as $$
  select k.id, k.nombre, k.tipo,
    case k.cuando
      when 'q1' then case when right(q, 1) = '1' then k.presupuesto_mensual else 0 end
      when 'q2' then case when right(q, 1) = '2' then k.presupuesto_mensual else 0 end
      else k.presupuesto_mensual / 2.0 end,
    coalesce((select sum(m.monto) from public.movimientos m
              where m.categoria_id = k.id and m.borrado_en is null and public.quincena_de(m.fecha) = q), 0)::bigint
  from public.categorias k
  where k.borrado_en is null and k.user_id = (select auth.uid())
  order by k.orden
$$;
revoke execute on function public.presupuesto_quincena(text) from anon;

do $$
declare t text;
begin
  foreach t in array array['perfiles','metas','deudas','cuentas','categorias','movimientos','inversiones','operaciones_inversion'] loop
    begin execute format('alter publication supabase_realtime add table public.%I', t);
    exception when duplicate_object then null; end;
  end loop;
end $$;
