alter table public.perfiles add column if not exists modo_quincena text not null default 'calendario'
  check (modo_quincena in ('calendario','pago_15_30'));
comment on column public.perfiles.modo_quincena is 'calendario: 1-15 y 16-fin de mes. pago_15_30: de pago a pago (15 al 29, y 30 al 14 del mes siguiente; en febrero el segundo pago es el último día).';

create or replace function public.quincena_de(d date, modo text) returns text
language sql immutable set search_path = '' as $$
  select case
    when modo = 'pago_15_30' then
      case
        when extract(day from d) < 15 then to_char(d - interval '1 month', 'YYYY-MM') || '-2'
        when extract(day from d) >= least(30, extract(day from (date_trunc('month', d) + interval '1 month - 1 day'))) then to_char(d, 'YYYY-MM') || '-2'
        else to_char(d, 'YYYY-MM') || '-1'
      end
    else to_char(d, 'YYYY-MM') || '-' || case when extract(day from d) <= 15 then '1' else '2' end
  end
$$;

create or replace view public.v_resumen_quincena with (security_invoker = true) as
select m.user_id, public.quincena_de(m.fecha, coalesce(p.modo_quincena, 'calendario')) as quincena,
  coalesce(sum(m.monto) filter (where m.tipo = 'ingreso'), 0) as ingresos,
  coalesce(sum(m.monto) filter (where m.tipo = 'gasto'), 0)   as gastos,
  coalesce(sum(m.monto) filter (where m.tipo = 'ahorro'), 0)  as ahorros,
  coalesce(sum(case when m.tipo = 'ingreso' then m.monto else -m.monto end), 0) as neto,
  count(*) as movimientos
from public.movimientos m
left join public.perfiles p on p.user_id = m.user_id
where m.borrado_en is null
group by 1, 2;

create or replace function public.presupuesto_quincena(q text)
returns table (categoria_id uuid, nombre text, tipo text, presupuesto numeric, gastado bigint)
language sql stable set search_path = '' as $$
  select k.id, k.nombre, k.tipo,
    case k.cuando
      when 'q1' then case when right(q, 1) = '1' then k.presupuesto_mensual else 0 end
      when 'q2' then case when right(q, 1) = '2' then k.presupuesto_mensual else 0 end
      else k.presupuesto_mensual / 2.0 end,
    coalesce((select sum(m.monto) from public.movimientos m
              where m.categoria_id = k.id and m.borrado_en is null
                and public.quincena_de(m.fecha, (select coalesce(p.modo_quincena,'calendario') from public.perfiles p where p.user_id = k.user_id)) = q), 0)::bigint
  from public.categorias k
  where k.borrado_en is null and k.user_id = (select auth.uid())
  order by k.orden
$$;
revoke execute on function public.presupuesto_quincena(text) from anon;
