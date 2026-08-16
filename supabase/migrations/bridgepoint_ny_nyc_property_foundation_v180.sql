-- BridgePoint NY expansion: require NYC PLUTO alongside the statewide NY property foundation.
-- This closes the explicit New York City coverage gap in the NYS assessment source.

create or replace function automation.ensure_ny_nyc_property_foundation_v179(p_run_id uuid)
returns uuid
language plpgsql
security definer
set search_path = pg_catalog, public, automation
as $$
declare
  v_state text;
  v_candidate uuid;
begin
  select state_code into v_state
  from automation.geographic_expansion_runs_v86
  where run_id = p_run_id;

  if v_state is distinct from 'NY' then
    return null;
  end if;

  insert into automation.geographic_source_candidates_v86(
    run_id,state_code,source_category,candidate_name,provider,source_url,
    access_method,discovery_method,authority_score,coverage_score,
    freshness_score,decision_status,reviewed_at,metadata
  ) values (
    p_run_id,'NY','PROPERTY_PARCEL','NYC Primary Land Use Tax Lot Output (PLUTO)',
    'data.cityofnewyork.us','https://data.cityofnewyork.us/d/64uk-42ks',
    'SOCRATA','BRIDGEPOINT_NY_REQUIRED_SUPPLEMENT_V179',98,100,95,
    'ACCEPTED',now(),
    jsonb_build_object(
      'domain','data.cityofnewyork.us',
      'portal','Socrata',
      'resource_id','64uk-42ks',
      'official',true,
      'agency','NYC Department of City Planning',
      'source_role','SUPPLEMENTAL_PROPERTY_FOUNDATION',
      'supplemental_property_foundation',true,
      'required_for_statewide_coverage',true,
      'coverage_scope','NEW_YORK_CITY',
      'coverage_reason','New York State assessment foundation explicitly excludes New York City',
      'canonical_key','BBL',
      'normalizer_version',179,
      'auto_injected_by','automation.ensure_ny_nyc_property_foundation_v179'
    )
  )
  on conflict (run_id,source_category,candidate_name) do update
  set provider=excluded.provider,
      source_url=excluded.source_url,
      access_method=excluded.access_method,
      decision_status='ACCEPTED',
      reviewed_at=now(),
      authority_score=greatest(automation.geographic_source_candidates_v86.authority_score,excluded.authority_score),
      coverage_score=greatest(automation.geographic_source_candidates_v86.coverage_score,excluded.coverage_score),
      freshness_score=greatest(automation.geographic_source_candidates_v86.freshness_score,excluded.freshness_score),
      metadata=coalesce(automation.geographic_source_candidates_v86.metadata,'{}'::jsonb)||excluded.metadata
  returning candidate_id into v_candidate;

  return v_candidate;
end
$$;

revoke all on function automation.ensure_ny_nyc_property_foundation_v179(uuid) from public, anon, authenticated;
grant execute on function automation.ensure_ny_nyc_property_foundation_v179(uuid) to service_role;

create or replace function automation.expansion_inject_ny_required_foundation_v179()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public, automation
as $$
begin
  if new.state_code='NY'
     and new.step_key='BUILD_ADAPTERS'
     and new.step_status in ('QUEUED','RUNNING') then
    perform automation.ensure_ny_nyc_property_foundation_v179(new.run_id);
  end if;
  return new;
end
$$;

revoke all on function automation.expansion_inject_ny_required_foundation_v179() from public, anon, authenticated;

drop trigger if exists trg_expansion_inject_ny_required_foundation_v179 on automation.geographic_expansion_steps_v90;
create trigger trg_expansion_inject_ny_required_foundation_v179
after insert or update of step_status on automation.geographic_expansion_steps_v90
for each row execute function automation.expansion_inject_ny_required_foundation_v179();

create or replace function automation.expansion_protect_required_foundation_v179()
returns trigger
language plpgsql
set search_path = pg_catalog, automation
as $$
begin
  if old.state_code='NY'
     and old.source_category='PROPERTY_PARCEL'
     and coalesce((old.metadata->>'required_for_statewide_coverage')::boolean,false)
     and new.decision_status='REJECTED'
     and coalesce(new.metadata,'{}'::jsonb) ? 'superseded_property_foundation' then
    new.decision_status := 'ACCEPTED';
    new.metadata := (coalesce(new.metadata,'{}'::jsonb) - 'superseded_property_foundation' - 'rejected_at')
      || jsonb_build_object('protected_required_foundation',true,'protected_at',now());
  end if;
  return new;
end
$$;

revoke all on function automation.expansion_protect_required_foundation_v179() from public, anon, authenticated;

drop trigger if exists trg_expansion_protect_required_foundation_v179 on automation.geographic_source_candidates_v86;
create trigger trg_expansion_protect_required_foundation_v179
before update of decision_status on automation.geographic_source_candidates_v86
for each row execute function automation.expansion_protect_required_foundation_v179();

create or replace function staging.normalize_nyc_pluto_expansion_payload_v179()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, automation, staging
as $$
declare
  v_meta jsonb;
  v_boro text;
  v_county text;
  v_payload jsonb;
begin
  select metadata into v_meta
  from automation.geographic_source_candidates_v86
  where candidate_id=new.candidate_id;

  if coalesce(v_meta->>'resource_id','') <> '64uk-42ks'
     or not coalesce((v_meta->>'supplemental_property_foundation')::boolean,false) then
    return new;
  end if;

  v_payload := coalesce(new.payload,'{}'::jsonb);
  v_boro := upper(coalesce(v_payload->>'borough',v_payload->>'boro',''));
  v_county := case v_boro
    when 'MN' then 'New York County' when '1' then 'New York County'
    when 'BX' then 'Bronx County' when '2' then 'Bronx County'
    when 'BK' then 'Kings County' when '3' then 'Kings County'
    when 'QN' then 'Queens County' when '4' then 'Queens County'
    when 'SI' then 'Richmond County' when '5' then 'Richmond County'
    else null
  end;

  new.payload := v_payload || jsonb_strip_nulls(jsonb_build_object(
    'parcel_id',nullif(coalesce(v_payload->>'bbl',v_payload->>'parcel_id'),''),
    'property_address',nullif(coalesce(v_payload->>'address',v_payload->>'property_address'),''),
    'municipality','New York City',
    'county_name',v_county,
    'zip_code',nullif(coalesce(v_payload->>'zipcode',v_payload->>'zip_code'),''),
    'property_class',nullif(coalesce(v_payload->>'bldgclass',v_payload->>'property_class'),''),
    'land_use_code',nullif(coalesce(v_payload->>'landuse',v_payload->>'land_use_code'),''),
    'year_built',nullif(coalesce(v_payload->>'yearbuilt',v_payload->>'year_built'),''),
    'land_area_sqft',nullif(coalesce(v_payload->>'lotarea',v_payload->>'land_area_sqft'),''),
    'assessed_land_value',nullif(coalesce(v_payload->>'assessland',v_payload->>'assessed_land_value'),''),
    'assessed_total_value',nullif(coalesce(v_payload->>'assesstot',v_payload->>'assessed_total_value'),''),
    'latitude',nullif(v_payload->>'latitude',''),
    'longitude',nullif(v_payload->>'longitude',''),
    '_bridgepoint_foundation_scope','NEW_YORK_CITY',
    '_bridgepoint_normalizer_version',179
  ));

  return new;
end
$$;

revoke all on function staging.normalize_nyc_pluto_expansion_payload_v179() from public, anon, authenticated;

drop trigger if exists trg_normalize_nyc_pluto_expansion_payload_v179 on staging.geographic_source_records_v90;
create trigger trg_normalize_nyc_pluto_expansion_payload_v179
before insert or update of payload,candidate_id on staging.geographic_source_records_v90
for each row execute function staging.normalize_nyc_pluto_expansion_payload_v179();
