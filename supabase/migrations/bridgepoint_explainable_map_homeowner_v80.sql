-- BridgePoint V80: explainable live map, NOAA radar source, and homeowner offer.

insert into product.packages (
  package_key, package_name, description, package_type,
  monthly_price, yearly_price, trial_days, active, featured,
  display_order, configuration
) values (
  'homeowner',
  'BridgePoint Homeowner',
  'Personal intelligence for one home: live risk context, property and claim timeline, weather alerts, saved evidence, and plain-language next steps.',
  'standard',
  19, 190, 7, true, true, 5,
  jsonb_build_object(
    'audience','homeowner',
    'monitored_property_limit',1,
    'plain_language_mode',true,
    'includes',jsonb_build_array(
      'one monitored home','live radar and weather context','property timeline',
      'claim and maintenance reminders','saved notes and notifications'
    ),
    'version',80
  )
)
on conflict (package_key) do update set
  package_name=excluded.package_name,
  description=excluded.description,
  package_type=excluded.package_type,
  monthly_price=excluded.monthly_price,
  yearly_price=excluded.yearly_price,
  trial_days=excluded.trial_days,
  active=true,
  featured=true,
  display_order=excluded.display_order,
  configuration=product.packages.configuration || excluded.configuration,
  updated_at=now();

insert into product.package_models(package_id,model_id,enabled,included)
select p.package_id,m.model_id,true,true
from product.packages p
join scoring.models m on m.model_key in ('bridgepoint_home','roofing_opportunity')
where p.package_key='homeowner'
on conflict (package_id,model_id) do update set enabled=true,included=true;

insert into product.stripe_catalog_v64(
  package_key,stripe_product_id,stripe_monthly_price_id,
  stripe_annual_price_id,environment,active
) values (
  'homeowner','prod_V4lSnBTAKoc2nG','price_1U4bvbHzFzwDC13zIHoIJM22',
  'price_1U4bvgHzFzwDC13zjBIEC33F','sandbox',true
)
on conflict(package_key) do update set
  stripe_product_id=excluded.stripe_product_id,
  stripe_monthly_price_id=excluded.stripe_monthly_price_id,
  stripe_annual_price_id=excluded.stripe_annual_price_id,
  environment=excluded.environment,active=true,updated_at=now();

insert into automation.source_registry (
  source_code,source_name,provider,source_category,geographic_scope,
  state_code,source_url,access_method,refresh_frequency,
  refresh_interval_minutes,enabled,priority,default_confidence,
  health_status,last_checked_at,last_successful_import_at,configuration,metadata
) values (
  'NOAA_NWS_LIVE_RADAR_V80',
  'NOAA / NWS Live MRMS Radar',
  'National Oceanic and Atmospheric Administration / National Weather Service',
  'LIVE_WEATHER_RADAR','NATIONAL',null,
  'https://opengeo.ncep.noaa.gov/geoserver/conus/conus_bref_qcd/ows',
  'OGC_WMS','PERIODIC',5,true,100,0.98,
  'HEALTHY',now(),now(),
  jsonb_build_object(
    'delivery_mode','CLIENT_WMS_OVERLAY','layer','conus_bref_qcd',
    'product','BREF.QCD','automatic',true,'version',80
  ),
  jsonb_build_object(
    'family','LIVE_RADAR','property_specific',false,
    'description','Official NOAA/NWS Multi-Radar Multi-Sensor base reflectivity overlay.',
    'flutter_icon','radar','records_are_tiles',true
  )
)
on conflict(source_code) do update set
  source_name=excluded.source_name,provider=excluded.provider,
  source_category=excluded.source_category,source_url=excluded.source_url,
  access_method=excluded.access_method,refresh_frequency=excluded.refresh_frequency,
  refresh_interval_minutes=excluded.refresh_interval_minutes,enabled=true,
  priority=excluded.priority,default_confidence=excluded.default_confidence,
  health_status='HEALTHY',last_checked_at=now(),last_successful_import_at=now(),
  configuration=automation.source_registry.configuration || excluded.configuration,
  metadata=automation.source_registry.metadata || excluded.metadata,updated_at=now();

create or replace function public.bridgepoint_flutter_signal_map_v80(
  p_min_lat double precision default null,
  p_max_lat double precision default null,
  p_min_lng double precision default null,
  p_max_lng double precision default null,
  p_limit integer default 300
) returns jsonb
language plpgsql stable security definer
set search_path='pg_catalog','public','api','intelligence','core'
set statement_timeout='25s'
as $$
declare
  uid uuid;
  v_limit integer:=least(greatest(coalesce(p_limit,300),1),500);
  rows_json jsonb;
begin
  uid:=api.require_user();

  with active_types as materialized (
    select st.signal_type_id,st.signal_key,st.signal_name,st.signal_family,st.description,st.direction
    from intelligence.signal_types st
    where coalesce(st.is_active,true)
  ), balanced as materialized (
    select
      s.signal_id,s.entity_id property_id,s.detected_at,s.effective_at,s.expires_at,
      s.strength,s.confidence,s.severity,s.status,s.title,s.description,
      s.detector_key,s.evidence_summary,
      st.signal_key,st.signal_name,st.signal_family,st.direction,
      p.latitude,p.longitude,p.municipality,p.county,p.property_type,
      a.full_address
    from active_types st
    cross join lateral (
      select recent.*
      from (
        select x.*
        from intelligence.signals x
        where x.signal_type_id=st.signal_type_id
          and x.entity_type='property'
          and lower(coalesce(x.status,'active'))='active'
        order by x.detected_at desc nulls last
        limit 36
      ) recent
      join core.properties px on px.property_id=recent.entity_id
      where px.latitude is not null and px.longitude is not null
        and (p_min_lat is null or px.latitude>=p_min_lat)
        and (p_max_lat is null or px.latitude<=p_max_lat)
        and (p_min_lng is null or px.longitude>=p_min_lng)
        and (p_max_lng is null or px.longitude<=p_max_lng)
      order by coalesce(recent.severity,0) desc,coalesce(recent.confidence,0) desc,
               recent.detected_at desc nulls last
      limit 12
    ) s
    join core.properties p on p.property_id=s.entity_id
    left join core.addresses a on a.address_id=p.primary_address_id
  ), ranked as (
    select b.*,
      row_number() over(order by coalesce(b.severity,0) desc,
        coalesce(b.confidence,0) desc,b.detected_at desc nulls last,b.signal_id) map_rank
    from balanced b
  )
  select coalesce(jsonb_agg(to_jsonb(r)-'map_rank' order by r.map_rank),'[]'::jsonb)
  into rows_json
  from (select * from ranked order by map_rank limit v_limit) r;

  return jsonb_build_object(
    'complete',true,'generated_at',now(),'map_version',80,
    'selection_mode','BALANCED_BY_SIGNAL_TYPE','limit',v_limit,
    'returned_points',jsonb_array_length(rows_json),
    'signal_type_count',(select count(distinct item.value->>'signal_key') from jsonb_array_elements(rows_json) as item(value)),
    'signals',rows_json
  );
end $$;

revoke execute on function public.bridgepoint_flutter_signal_map_v80(
  double precision,double precision,double precision,double precision,integer
) from public,anon;
grant execute on function public.bridgepoint_flutter_signal_map_v80(
  double precision,double precision,double precision,double precision,integer
) to authenticated,service_role;

create or replace function public.bridgepoint_complete_onboarding_v70(
  p_industry text,p_role_name text,p_primary_goal text,p_territory text,p_experience_level text)
returns jsonb language plpgsql security definer
set search_path='pg_catalog','public','api','customer_workspace' as $$
declare uid uuid; recommended text; industry text:=lower(btrim(coalesce(p_industry,'')));
begin
  uid:=api.require_user();
  if btrim(coalesce(p_role_name,''))='' or btrim(coalesce(p_primary_goal,''))=''
     or btrim(coalesce(p_territory,''))='' or btrim(coalesce(p_experience_level,''))='' or industry='' then
    raise exception 'All onboarding answers are required';
  end if;
  recommended:=case
    when industry in ('homeowner','property owner') then 'homeowner'
    when industry in ('roofing','exterior contractor') then 'roofing_opportunity'
    when industry in ('commercial real estate','commercial services') then 'bridgepoint_commercial'
    when industry in ('property investing','real estate investing') then 'property_investor'
    when industry in ('solar','energy') then 'solar_opportunity'
    when industry in ('development','construction development') then 'development_opportunity'
    when industry in ('home services','restoration','public adjusting') then 'bridgepoint_home'
    else 'all' end;
  insert into customer_workspace.profiles_v70(user_id,industry,role_name,primary_goal,territory,experience_level,recommended_package_key)
  values(uid,btrim(p_industry),btrim(p_role_name),btrim(p_primary_goal),btrim(p_territory),btrim(p_experience_level),recommended)
  on conflict(user_id) do update set industry=excluded.industry,role_name=excluded.role_name,
    primary_goal=excluded.primary_goal,territory=excluded.territory,
    experience_level=excluded.experience_level,recommended_package_key=excluded.recommended_package_key,
    onboarding_complete=true,updated_at=now();
  return jsonb_build_object('complete',true,'recommended_package_key',recommended,
    'reason',case recommended
      when 'homeowner' then 'BridgePoint Homeowner watches one home, explains changing risk, preserves a property timeline, and helps organize maintenance or claim follow-up.'
      when 'roofing_opportunity' then 'Roofing Opportunity emphasizes storm, roof-age and exterior-condition evidence.'
      when 'bridgepoint_commercial' then 'BridgePoint Commercial emphasizes business, development and commercial-property evidence.'
      when 'property_investor' then 'Property Investor emphasizes transitions, distress and redevelopment evidence.'
      when 'solar_opportunity' then 'Solar Opportunity emphasizes roof, energy and solar-program evidence.'
      when 'development_opportunity' then 'Development Opportunity emphasizes construction, land-use and change evidence.'
      when 'bridgepoint_home' then 'BridgePoint Home combines the strongest residential service opportunities.'
      else 'All Intelligence is the best starting point because your answers span multiple opportunity types.' end);
end $$;

revoke execute on function public.bridgepoint_complete_onboarding_v70(text,text,text,text,text) from public,anon;
grant execute on function public.bridgepoint_complete_onboarding_v70(text,text,text,text,text) to authenticated,service_role;

create table if not exists customer_workspace.display_preferences_v80(
  user_id uuid primary key references auth.users(id) on delete cascade,
  large_text boolean not null default false,
  high_contrast boolean not null default false,
  reduced_motion boolean not null default false,
  simplified_views boolean not null default false,
  updated_at timestamptz not null default now()
);
alter table customer_workspace.display_preferences_v80 enable row level security;
revoke all on customer_workspace.display_preferences_v80 from public,anon,authenticated;

create or replace function public.bridgepoint_display_preferences_v80()
returns jsonb language plpgsql stable security definer
set search_path='pg_catalog','public','api','customer_workspace' as $$
declare uid uuid; prefs customer_workspace.display_preferences_v80%rowtype;
begin
  uid:=api.require_user();
  select * into prefs from customer_workspace.display_preferences_v80 where user_id=uid;
  return jsonb_build_object(
    'complete',true,
    'large_text',coalesce(prefs.large_text,false),
    'high_contrast',coalesce(prefs.high_contrast,false),
    'reduced_motion',coalesce(prefs.reduced_motion,false),
    'simplified_views',coalesce(prefs.simplified_views,false)
  );
end $$;

create or replace function public.bridgepoint_update_display_preferences_v80(
  p_large_text boolean,p_high_contrast boolean,p_reduced_motion boolean,p_simplified_views boolean
) returns jsonb language plpgsql security definer
set search_path='pg_catalog','public','api','customer_workspace' as $$
declare uid uuid;
begin
  uid:=api.require_user();
  insert into customer_workspace.display_preferences_v80(
    user_id,large_text,high_contrast,reduced_motion,simplified_views
  ) values (
    uid,coalesce(p_large_text,false),coalesce(p_high_contrast,false),
    coalesce(p_reduced_motion,false),coalesce(p_simplified_views,false)
  ) on conflict(user_id) do update set
    large_text=excluded.large_text,high_contrast=excluded.high_contrast,
    reduced_motion=excluded.reduced_motion,simplified_views=excluded.simplified_views,
    updated_at=now();
  return public.bridgepoint_display_preferences_v80();
end $$;

revoke execute on function public.bridgepoint_display_preferences_v80() from public,anon;
revoke execute on function public.bridgepoint_update_display_preferences_v80(boolean,boolean,boolean,boolean) from public,anon;
grant execute on function public.bridgepoint_display_preferences_v80() to authenticated,service_role;
grant execute on function public.bridgepoint_update_display_preferences_v80(boolean,boolean,boolean,boolean) to authenticated,service_role;

comment on function public.bridgepoint_flutter_signal_map_v80(double precision,double precision,double precision,double precision,integer)
is 'Authenticated, balanced property-signal map feed. Direct table access remains revoked.';
