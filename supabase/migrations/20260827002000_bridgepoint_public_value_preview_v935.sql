-- BridgePoint Intelligence V935
-- Public value-before-signup preview: territory matches first, then clearly
-- labeled statewide CT fallback examples to fill the five-card promise.

create or replace function public.bridgepoint_public_territory_preview_v935(
  p_state_code text default 'CT',
  p_territory text default 'Connecticut',
  p_vertical text default 'ROOFING'
)
returns jsonb
language plpgsql
stable
security definer
set search_path to 'pg_catalog','core','opportunity_engine'
set statement_timeout to '5s'
as $$
declare
  v_state text := upper(left(trim(coalesce(p_state_code,'CT')),2));
  v_territory text := trim(regexp_replace(coalesce(p_territory,''),'\s+',' ','g'));
  v_vertical text := upper(trim(coalesce(p_vertical,'ROOFING')));
  v_vertical_key text;
  v_items jsonb := '[]'::jsonb;
  v_count integer := 0;
  v_exact_count integer := 0;
  v_fallback_count integer := 0;
  v_scope text := 'TERRITORY_MATCH';
begin
  if v_state <> 'CT' then
    return jsonb_build_object(
      'complete',true,'version',935,'available',false,'state_code',v_state,
      'market_status','BUILDING',
      'message','The instant opportunity preview is currently deepest in Connecticut. You can still request expansion for another state.'
    );
  end if;

  if char_length(v_territory) < 2 or char_length(v_territory) > 120 then
    return jsonb_build_object('complete',false,'version',935,'available',false,'reason','INVALID_TERRITORY');
  end if;

  v_vertical_key := case v_vertical
    when 'ROOFING' then 'roofing'
    when 'EXTERIOR' then 'roofing'
    when 'RESTORATION' then 'restoration'
    when 'ADJUSTER' then 'public_adjusting'
    when 'PUBLIC_ADJUSTER' then 'public_adjusting'
    when 'CONTRACTOR' then 'general_contracting'
    when 'INVESTOR' then 'property_investment'
    else 'roofing' end;

  with exact_chosen as (
    select distinct on (o.property_id)
      o.property_id,o.opportunity_name,o.quality_score,o.quality_tier,o.strict_tier,o.property_priority_tier,
      o.intelligence_stage,o.direct_signal_count,o.direct_source_count,o.latest_direct_evidence_at,o.direct_evidence,
      p.municipality,p.county,p.postal_code
    from opportunity_engine.verified_ranked_opportunities_v83 o
    join core.properties p on p.property_id=o.property_id
    where p.active
      and trim(p.state_code::text)=v_state
      and o.vertical_key=v_vertical_key
      and o.quality_score>=70
      and (
        lower(coalesce(p.municipality,'')) like '%'||lower(v_territory)||'%'
        or lower(coalesce(p.county,'')) like '%'||lower(v_territory)||'%'
        or coalesce(p.postal_code,'') like v_territory||'%'
        or lower(v_territory) in ('ct','connecticut','statewide','all connecticut')
      )
    order by o.property_id,o.quality_score desc,o.latest_direct_evidence_at desc nulls last
  ), exact_ranked as (
    select * from exact_chosen
    order by quality_score desc,direct_signal_count desc,latest_direct_evidence_at desc nulls last
    limit 5
  ), statewide_chosen as (
    select distinct on (o.property_id)
      o.property_id,o.opportunity_name,o.quality_score,o.quality_tier,o.strict_tier,o.property_priority_tier,
      o.intelligence_stage,o.direct_signal_count,o.direct_source_count,o.latest_direct_evidence_at,o.direct_evidence,
      p.municipality,p.county,p.postal_code
    from opportunity_engine.verified_ranked_opportunities_v83 o
    join core.properties p on p.property_id=o.property_id
    where p.active
      and trim(p.state_code::text)=v_state
      and o.vertical_key=v_vertical_key
      and o.quality_score>=70
      and not exists(select 1 from exact_ranked e where e.property_id=o.property_id)
    order by o.property_id,o.quality_score desc,o.latest_direct_evidence_at desc nulls last
  ), statewide_ranked as (
    select * from statewide_chosen
    order by quality_score desc,direct_signal_count desc,latest_direct_evidence_at desc nulls last
    limit 5
  ), combined as (
    select 1 as scope_rank,true as territory_match,* from exact_ranked
    union all
    select 2,false,* from statewide_ranked
  ), final_rows as (
    select * from combined
    order by scope_rank,quality_score desc,direct_signal_count desc,latest_direct_evidence_at desc nulls last
    limit 5
  )
  select
    coalesce(jsonb_agg(jsonb_build_object(
      'area',concat_ws(', ',nullif(municipality,''),nullif(county,'')),
      'postal_code',postal_code,
      'opportunity',opportunity_name,
      'priority',coalesce(quality_tier,strict_tier,property_priority_tier),
      'quality_score',round(quality_score::numeric,1),
      'stage',intelligence_stage,
      'direct_signal_count',coalesce(direct_signal_count,0),
      'direct_source_count',coalesce(direct_source_count,0),
      'latest_evidence_at',latest_direct_evidence_at,
      'evidence_headline',coalesce(direct_evidence->0->>'title','Property-linked intelligence'),
      'why',format('%s direct property-linked signal%s across %s source%s; latest evidence %s.',
        coalesce(direct_signal_count,0),case when coalesce(direct_signal_count,0)=1 then '' else 's' end,
        coalesce(direct_source_count,0),case when coalesce(direct_source_count,0)=1 then '' else 's' end,
        coalesce(to_char(latest_direct_evidence_at at time zone 'America/New_York','Mon DD, YYYY'),'not dated')),
      'territory_match',territory_match,
      'scope_label',case when territory_match then 'Your territory' else 'Connecticut fallback' end
    ) order by scope_rank,quality_score desc),'[]'::jsonb),
    count(*),
    count(*) filter(where territory_match),
    count(*) filter(where not territory_match)
  into v_items,v_count,v_exact_count,v_fallback_count
  from final_rows;

  v_scope := case
    when v_count=0 then 'NO_VERIFIED_PREVIEW'
    when v_exact_count>=v_count then 'TERRITORY_MATCH'
    when v_exact_count>0 then 'TERRITORY_PLUS_STATEWIDE'
    else 'STATEWIDE_FALLBACK' end;

  return jsonb_build_object(
    'complete',true,'version',935,'available',v_count>0,
    'state_code',v_state,'territory',v_territory,'vertical',v_vertical,
    'match_scope',v_scope,'preview_count',v_count,
    'matched_count',v_exact_count,'fallback_count',v_fallback_count,
    'opportunities',v_items,'detail_locked',true,
    'disclosure','Territory matches are shown first. If fewer than five verified matches exist, BridgePoint fills the preview with clearly labeled statewide Connecticut examples. Rankings are decision-support intelligence, not findings of physical damage, coverage, claim validity, customer intent, or guaranteed work.'
  );
end
$$;

revoke all on function public.bridgepoint_public_territory_preview_v935(text,text,text) from public,anon,authenticated;
grant execute on function public.bridgepoint_public_territory_preview_v935(text,text,text) to service_role;

create or replace function public.bridgepoint_public_territory_preview_v674(
  p_state_code text default 'CT',
  p_territory text default 'Connecticut',
  p_vertical text default 'ROOFING'
)
returns jsonb
language sql
stable
security definer
set search_path to 'pg_catalog','public'
set statement_timeout to '5s'
as $$
  select public.bridgepoint_public_territory_preview_v935(p_state_code,p_territory,p_vertical)
$$;

revoke all on function public.bridgepoint_public_territory_preview_v674(text,text,text) from public,anon,authenticated;
grant execute on function public.bridgepoint_public_territory_preview_v674(text,text,text) to service_role;
