alter table public.categorias add column if not exists en_ritmo boolean not null default true;
comment on column public.categorias.en_ritmo is 'Si el gasto es del día a día y cuenta en la gráfica de ritmo de la quincena (false para facturas que se pagan de una vez, como servicios).';
