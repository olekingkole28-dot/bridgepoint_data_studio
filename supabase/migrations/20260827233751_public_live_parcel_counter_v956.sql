create table if not exists product.public_parcel_counter_v956 (
  state_code text primary key,
  parcel_count bigint not null default 0,
  updated_at timestamptz not null default now()
);

insert into product.public_parcel_counter_v956(state_code, parcel_count, updated_at)
select state_code, count(*)::bigint, now()
from core.properties
where state_code is not null
group by state_code
on conflict (state_code) do update
set parcel_count = excluded.parcel_count,
    updated_at = excluded.updated_at;

create or replace function automation.sync_public_parcel_counter_insert_v956()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  insert into product.public_parcel_counter_v956(state_code, parcel_count, updated_at)
  select state_code, count(*)::bigint, now()
  from new_rows
  where state_code is not null
  group by state_code
  on conflict (state_code) do update
  set parcel_count = product.public_parcel_counter_v956.parcel_count + excluded.parcel_count,
      updated_at = excluded.updated_at;
  return null;
end;
$$;

create or replace function automation.sync_public_parcel_counter_delete_v956()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  update product.public_parcel_counter_v956 c
  set parcel_count = greatest(0, c.parcel_count - d.removed),
      updated_at = now()
  from (
    select state_code, count(*)::bigint as removed
    from old_rows
    where state_code is not null
    group by state_code
  ) d
  where c.state_code = d.state_code;
  return null;
end;
$$;

create or replace function automation.sync_public_parcel_counter_update_v956()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  with delta as (
    select state_code, sum(delta)::bigint as delta
    from (
      select state_code, count(*)::bigint as delta
      from new_rows
      where state_code is not null
      group by state_code
      union all
      select state_code, -count(*)::bigint as delta
      from old_rows
      where state_code is not null
      group by state_code
    ) x
    group by state_code
    having sum(delta) <> 0
  )
  insert into product.public_parcel_counter_v956(state_code, parcel_count, updated_at)
  select state_code, greatest(0, delta), now() from delta
  on conflict (state_code) do update
  set parcel_count = greatest(0, product.public_parcel_counter_v956.parcel_count + excluded.parcel_count),
      updated_at = excluded.updated_at;
  return null;
end;
$$;

drop trigger if exists trg_public_parcel_counter_insert_v956 on core.properties;
create trigger trg_public_parcel_counter_insert_v956
after insert on core.properties
referencing new table as new_rows
for each statement execute function automation.sync_public_parcel_counter_insert_v956();

drop trigger if exists trg_public_parcel_counter_delete_v956 on core.properties;
create trigger trg_public_parcel_counter_delete_v956
after delete on core.properties
referencing old table as old_rows
for each statement execute function automation.sync_public_parcel_counter_delete_v956();

drop trigger if exists trg_public_parcel_counter_update_v956 on core.properties;
create trigger trg_public_parcel_counter_update_v956
after update on core.properties
referencing old table as old_rows new table as new_rows
for each statement execute function automation.sync_public_parcel_counter_update_v956();

create or replace function public.bridgepoint_public_parcel_progress_v956()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'available', true,
    'total_parcels', coalesce(sum(parcel_count),0),
    'states_present', count(*) filter (where parcel_count > 0),
    'updated_at', max(updated_at),
    'states', coalesce(
      jsonb_agg(
        jsonb_build_object(
          'state_code', state_code,
          'parcel_count', parcel_count,
          'updated_at', updated_at
        ) order by parcel_count desc, state_code
      ) filter (where parcel_count > 0),
      '[]'::jsonb
    )
  )
  from product.public_parcel_counter_v956;
$$;

revoke all on function public.bridgepoint_public_parcel_progress_v956() from public;
grant execute on function public.bridgepoint_public_parcel_progress_v956() to anon, authenticated;
