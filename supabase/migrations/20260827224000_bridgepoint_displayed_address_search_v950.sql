-- BridgePoint customer property search reliability v950.
-- Keeps the public RPC contract stable while staging lookup work so broad
-- municipality searches and canonical street-address searches do not force
-- opportunity ranking or unrelated national scans before returning identity.

create or replace function public.bridgepoint_property_suggestions_v192(p_query text, p_limit integer default 8)
returns jsonb
language plpgsql
stable security definer
set search_path to 'pg_catalog','public','api','accounts','product','core','automation'
set statement_timeout to '6s'
as $function$
declare
  uid uuid:=api.require_user();
  q text:=lower(btrim(coalesce(p_query,'')));
  q_norm text:=automation.normalize_address(p_query);
  lim integer:=least(greatest(coalesce(p_limit,8),1),20);
  owner_mode boolean:=accounts.is_platform_admin();
  allowed text[];
  rows jsonb:='[]'::jsonb;
  exact_municipality boolean:=false;
  exact_parcel boolean:=false;
begin
  if length(q)<2 then
    return jsonb_build_object('complete',true,'query',q,'suggestions','[]'::jsonb,'search_mode','DISPLAY_ADDRESS_SEARCH_V950');
  end if;

  select array_agg(m.state_code) into allowed
  from product.geographic_markets_v77 m
  where case when owner_mode then true else product.user_has_state_access_v77(uid,m.state_code) end;

  if allowed is null then
    return jsonb_build_object('complete',true,'query',q,'suggestions','[]'::jsonb,'search_mode','DISPLAY_ADDRESS_SEARCH_V950');
  end if;

  select exists(
    select 1 from core.properties p
    where p.active and p.state_code=any(allowed)
      and p.parcel_number is not null
      and lower(p.parcel_number)=q
    limit 1
  ) into exact_parcel;

  if exact_parcel then
    select coalesce(jsonb_agg(to_jsonb(x) order by x.state_code,x.full_address),'[]'::jsonb)
    into rows
    from (
      select p.property_id,p.state_code,p.municipality,p.county,p.postal_code,p.parcel_number,p.property_type,p.year_built,p.assessed_total_value,p.latitude,p.longitude,
        coalesce(a.full_address,p.search_text) full_address,
        coalesce(p.current_owner_name,case when nullif(btrim(p.metadata->>'owner_raw'),'') is not null and lower(btrim(p.metadata->>'owner_raw')) not in ('current owner','owner','unknown','unknown owner','n/a','na','not available','withheld','confidential') then btrim(p.metadata->>'owner_raw') end) current_owner_name,
        1 match_rank,'PARCEL_EXACT'::text match_reason,null::text top_opportunity,null::numeric top_score
      from core.properties p
      left join core.addresses a on a.address_id=p.primary_address_id
      where p.active and p.state_code=any(allowed)
        and p.parcel_number is not null and lower(p.parcel_number)=q
      limit lim
    ) x;
  else
    if q !~ '[0-9]' then
      select exists(
        select 1 from core.properties p
        where p.active and p.state_code=any(allowed)
          and p.municipality is not null and lower(p.municipality)=q
        limit 1
      ) into exact_municipality;
    end if;

    if exact_municipality then
      select coalesce(jsonb_agg(to_jsonb(x) order by x.state_code,x.full_address),'[]'::jsonb)
      into rows
      from (
        select p.property_id,p.state_code,p.municipality,p.county,p.postal_code,p.parcel_number,p.property_type,p.year_built,p.assessed_total_value,p.latitude,p.longitude,
          coalesce(a.full_address,p.search_text) full_address,
          coalesce(p.current_owner_name,case when nullif(btrim(p.metadata->>'owner_raw'),'') is not null and lower(btrim(p.metadata->>'owner_raw')) not in ('current owner','owner','unknown','unknown owner','n/a','na','not available','withheld','confidential') then btrim(p.metadata->>'owner_raw') end) current_owner_name,
          2 match_rank,'MUNICIPALITY_EXACT'::text match_reason,null::text top_opportunity,null::numeric top_score
        from core.properties p
        left join core.addresses a on a.address_id=p.primary_address_id
        where p.active and p.state_code=any(allowed)
          and p.municipality is not null and lower(p.municipality)=q
        order by p.state_code,p.property_id
        limit lim
      ) x;
    elsif q ~ '[0-9]' and length(coalesce(q_norm,''))>=4 then
      select coalesce(jsonb_agg(to_jsonb(x) order by x.match_rank,x.state_code,x.full_address),'[]'::jsonb)
      into rows
      from (
        select p.property_id,p.state_code,p.municipality,p.county,p.postal_code,p.parcel_number,p.property_type,p.year_built,p.assessed_total_value,p.latitude,p.longitude,
          a.full_address,
          coalesce(p.current_owner_name,case when nullif(btrim(p.metadata->>'owner_raw'),'') is not null and lower(btrim(p.metadata->>'owner_raw')) not in ('current owner','owner','unknown','unknown owner','n/a','na','not available','withheld','confidential') then btrim(p.metadata->>'owner_raw') end) current_owner_name,
          case when a.normalized_address=q_norm then 3 when a.normalized_address like q_norm||'%' then 4 else 5 end match_rank,
          'CANONICAL_ADDRESS'::text match_reason,null::text top_opportunity,null::numeric top_score
        from core.addresses a
        join core.properties p on p.primary_address_id=a.address_id
        where p.active and p.state_code=any(allowed)
          and a.normalized_address ilike '%'||q_norm||'%'
        limit lim
      ) x;

      if jsonb_array_length(rows)=0 then
        select coalesce(jsonb_agg(to_jsonb(x) order by x.match_rank,x.state_code,x.full_address),'[]'::jsonb)
        into rows
        from (
          select p.property_id,p.state_code,p.municipality,p.county,p.postal_code,p.parcel_number,p.property_type,p.year_built,p.assessed_total_value,p.latitude,p.longitude,
            coalesce(a.full_address,p.search_text) full_address,
            coalesce(p.current_owner_name,case when nullif(btrim(p.metadata->>'owner_raw'),'') is not null and lower(btrim(p.metadata->>'owner_raw')) not in ('current owner','owner','unknown','unknown owner','n/a','na','not available','withheld','confidential') then btrim(p.metadata->>'owner_raw') end) current_owner_name,
            6 match_rank,'PROPERTY_TEXT'::text match_reason,null::text top_opportunity,null::numeric top_score
          from core.properties p
          left join core.addresses a on a.address_id=p.primary_address_id
          where p.active and p.state_code=any(allowed)
            and p.search_text ilike '%'||q||'%'
          limit lim
        ) x;
      end if;
    elsif length(q)>=4 then
      select coalesce(jsonb_agg(to_jsonb(x) order by x.match_rank,x.state_code,x.full_address),'[]'::jsonb)
      into rows
      from (
        select p.property_id,p.state_code,p.municipality,p.county,p.postal_code,p.parcel_number,p.property_type,p.year_built,p.assessed_total_value,p.latitude,p.longitude,
          coalesce(a.full_address,p.search_text) full_address,
          coalesce(p.current_owner_name,case when nullif(btrim(p.metadata->>'owner_raw'),'') is not null and lower(btrim(p.metadata->>'owner_raw')) not in ('current owner','owner','unknown','unknown owner','n/a','na','not available','withheld','confidential') then btrim(p.metadata->>'owner_raw') end) current_owner_name,
          5 match_rank,'PROPERTY_TEXT'::text match_reason,null::text top_opportunity,null::numeric top_score
        from core.properties p
        left join core.addresses a on a.address_id=p.primary_address_id
        where p.active and p.state_code=any(allowed)
          and p.search_text ilike '%'||q||'%'
        limit lim
      ) x;
    end if;
  end if;

  return jsonb_build_object('complete',true,'query',q,'owner_mode',owner_mode,'state_codes',to_jsonb(allowed),'returned_results',jsonb_array_length(rows),'suggestions',rows,'search_mode','DISPLAY_ADDRESS_SEARCH_V950');
end
$function$;

grant execute on function public.bridgepoint_property_suggestions_v192(text,integer) to authenticated;
