-- BridgePoint V83
-- Verified direct-evidence opportunity queue, request-level deduplication,
-- and a plain-language property timeline that explains every signal.

create or replace function opportunity_engine.signal_verticals_v83(p_signal_key text)
returns text[] language sql immutable
set search_path='pg_catalog' as $$
  select case lower(coalesce(p_signal_key,''))
    when 'hail_exposure' then array['roofing','restoration','public_adjusting']::text[]
    when 'severe_wind_exposure' then array['roofing','restoration','public_adjusting']::text[]
    when 'reported_fire_loss' then array['roofing','restoration','public_adjusting']::text[]
    when 'structure_fire' then array['roofing','restoration','public_adjusting','general_contracting']::text[]
    when 'repeat_fire_history' then array['roofing','restoration','public_adjusting']::text[]
    when 'fire_casualty_reported' then array['restoration','public_adjusting']::text[]
    when 'sewage_or_wastewater_release' then array['restoration']::text[]
    when 'documented_property_change' then array['general_contracting','development']::text[]
    when 'documented_property_improvement' then array['general_contracting','development']::text[]
    when 'commercial_or_development_transfer' then array['general_contracting','development']::text[]
    when 'ct_react_active_cleanup' then array['general_contracting','property_investment','development','commercial_services']::text[]
    when 'ct_react_use_restriction' then array['general_contracting','property_investment','development']::text[]
    when 'ct_react_engineered_control' then array['general_contracting']::text[]
    when 'ust_active_remediation' then array['general_contracting']::text[]
    when 'foreclosure_related_transfer' then array['property_investment']::text[]
    when 'distressed_property_transfer' then array['property_investment']::text[]
    when 'below_market_transfer' then array['property_investment']::text[]
    when 'estate_or_probate_transfer' then array['property_investment']::text[]
    when 'court_or_government_transfer' then array['property_investment']::text[]
    when 'recent_property_transfer' then array['property_investment']::text[]
    when 'ct_business_recent_registration' then array['commercial_services']::text[]
    when 'ct_business_status_risk' then array['commercial_services']::text[]
    else array[]::text[]
  end
$$;
revoke all on function opportunity_engine.signal_verticals_v83(text) from public,anon,authenticated;

drop materialized view if exists opportunity_engine.verified_ranked_opportunities_v83;
create materialized view opportunity_engine.verified_ranked_opportunities_v83 as
with signal_base as materialized (
  select s.signal_id,s.entity_id property_id,s.detector_key,
    coalesce(s.metadata->>'signal_key','') signal_key,s.title,s.description,
    s.severity,s.confidence,coalesce(s.effective_at,s.detected_at,s.created_at) evidence_at,
    s.evidence_summary,
    opportunity_engine.signal_verticals_v83(coalesce(s.metadata->>'signal_key','')) verticals
  from intelligence.signals s
  where lower(s.entity_type)='property' and s.status='active'
    and coalesce(s.confidence,0)>=.75 and coalesce(s.severity,0)>=45
    and coalesce(s.effective_at,s.detected_at,s.created_at)>=now()-interval '730 days'
    and coalesce(s.evidence_summary->>'matching_precision','') not ilike 'AREA%'
    and coalesce(s.evidence_summary->>'storage_mode','') not ilike '%area_context%'
), mapped as (
  select b.*,v.vertical_key
  from signal_base b cross join lateral unnest(b.verticals) v(vertical_key)
), direct_evidence as (
  select m.property_id,m.vertical_key,count(*)::integer direct_signal_count,
    count(distinct m.detector_key)::integer direct_source_count,
    avg(m.confidence)::numeric direct_confidence,avg(m.severity)::numeric direct_severity,
    max(m.evidence_at) latest_direct_evidence_at,
    jsonb_agg(jsonb_build_object(
      'signal_id',m.signal_id,'signal_key',m.signal_key,'title',m.title,
      'description',m.description,'detector_key',m.detector_key,
      'severity',round(m.severity::numeric,1),'confidence_percent',round(m.confidence::numeric*100,1),
      'evidence_at',m.evidence_at,'scope','PROPERTY_LINKED','evidence_summary',m.evidence_summary
    ) order by m.evidence_at desc,m.severity desc,m.signal_id) direct_evidence
  from mapped m group by m.property_id,m.vertical_key
), scored as (
  select o.*,d.direct_signal_count,d.direct_source_count,
    round(d.direct_confidence,4) direct_confidence,round(d.direct_severity,2) direct_severity,
    d.latest_direct_evidence_at,d.direct_evidence,
    round(least(100,32
      + least(d.direct_signal_count,4)*5
      + least(d.direct_source_count,3)*5
      + d.direct_confidence*10
      + least(d.direct_severity,100)*.1
      + case when d.latest_direct_evidence_at>=now()-interval '30 days' then 10
             when d.latest_direct_evidence_at>=now()-interval '90 days' then 8
             when d.latest_direct_evidence_at>=now()-interval '365 days' then 5 else 2 end
      + least(o.matched_pattern_count,3)*2
      + least(o.source_count,5)),2) positive_quality_score,
    round((case when d.direct_signal_count=1 then 2 else 0 end
      + case when d.direct_source_count=1 then 2 else 0 end
      + case when d.latest_direct_evidence_at<now()-interval '365 days' then 5
             when d.latest_direct_evidence_at<now()-interval '180 days' then 3 else 0 end
      + case when d.direct_confidence<.80 then 2 else 0 end)::numeric,2) negative_score
  from opportunity_engine.strict_ranked_opportunities_v76 o
  join direct_evidence d on d.property_id=o.property_id and d.vertical_key=o.vertical_key
  where o.confidence_score>=.85 and o.source_count>=3 and o.matched_pattern_count>=1
), qualified as (
  select s.*,round(greatest(0,s.positive_quality_score-s.negative_score),2) quality_score,
    coalesce(nullif(lower(btrim(p.municipality)),'')||'|parcel|'||nullif(lower(btrim(p.parcel_number)),''),
      'address|'||nullif(lower(btrim(a.full_address)),''),p.property_id::text) property_identity_key,
    p.municipality,p.parcel_number,a.full_address
  from scored s join core.properties p on p.property_id=s.property_id
  left join core.addresses a on a.address_id=p.primary_address_id
  where p.active
), vertical_dedup as (
  select q.*,row_number() over(partition by q.vertical_key,q.property_identity_key
    order by q.quality_score desc,q.latest_direct_evidence_at desc,q.opportunity_id) vertical_property_choice
  from qualified q where q.quality_score>=75
), one_per_vertical as (
  select v.* from vertical_dedup v where v.vertical_property_choice=1
), ranked as (
  select v.*,
    row_number() over(partition by v.vertical_key order by v.quality_score desc,v.latest_direct_evidence_at desc,v.opportunity_id) vertical_rank_v83,
    row_number() over(partition by v.property_identity_key order by v.quality_score desc,v.latest_direct_evidence_at desc,v.opportunity_id) global_property_choice,
    row_number() over(order by v.quality_score desc,v.latest_direct_evidence_at desc,v.opportunity_id) global_rank_v83
  from one_per_vertical v
)
select r.*,
  case when r.quality_score>=88 then 'elite' when r.quality_score>=82 then 'high' else 'qualified' end quality_tier,
  jsonb_build_object(
    'single_direct_signal',case when r.direct_signal_count=1 then 2 else 0 end,
    'single_direct_source',case when r.direct_source_count=1 then 2 else 0 end,
    'older_direct_evidence',case when r.latest_direct_evidence_at<now()-interval '365 days' then 5
      when r.latest_direct_evidence_at<now()-interval '180 days' then 3 else 0 end,
    'lower_direct_confidence',case when r.direct_confidence<.80 then 2 else 0 end
  ) negative_breakdown
from ranked r where r.vertical_rank_v83<=500;

create unique index verified_ranked_opportunities_v83_id_idx
  on opportunity_engine.verified_ranked_opportunities_v83(opportunity_id);
create index verified_ranked_opportunities_v83_global_idx
  on opportunity_engine.verified_ranked_opportunities_v83(global_property_choice,quality_score desc);
create index verified_ranked_opportunities_v83_vertical_idx
  on opportunity_engine.verified_ranked_opportunities_v83(vertical_key,quality_score desc);
revoke all on opportunity_engine.verified_ranked_opportunities_v83 from public,anon,authenticated;

create or replace function automation.refresh_verified_rankings_v83()
returns jsonb language plpgsql security definer
set search_path='pg_catalog','opportunity_engine' as $$
begin
  refresh materialized view concurrently opportunity_engine.verified_ranked_opportunities_v83;
  return jsonb_build_object('complete',true,'engine_version',83,
    'ranking_mode','VERIFIED_DIRECT_EVIDENCE_DEDUPED','refreshed_at',now());
end $$;
revoke all on function automation.refresh_verified_rankings_v83() from public,anon,authenticated;

do $$ begin
  if exists(select 1 from cron.job where jobname='bridgepoint-verified-ranking-v83') then
    perform cron.unschedule('bridgepoint-verified-ranking-v83');
  end if;
  perform cron.schedule('bridgepoint-verified-ranking-v83','*/5 * * * *',
    'select automation.refresh_verified_rankings_v83();');
end $$;

create or replace function public.bridgepoint_flutter_opportunities_v57(
  p_model_key text default 'all',p_limit integer default 50,p_offset integer default 0,
  p_priority text default null,p_stage text default null)
returns jsonb language plpgsql stable security definer
set search_path='pg_catalog','public','api','opportunity_engine','core','customer_workspace','product'
set statement_timeout='25s' as $$
declare uid uuid:=api.require_user(); org uuid; v_model_key text:=lower(btrim(coalesce(p_model_key,'all')));
  v_limit integer:=least(greatest(coalesce(p_limit,50),1),500); v_offset integer:=greatest(coalesce(p_offset,0),0);
  v_priority text:=nullif(lower(btrim(coalesce(p_priority,''))),''); v_stage text:=nullif(lower(btrim(coalesce(p_stage,''))),'');
  v_total bigint:=0; v_rows jsonb:='[]'::jsonb;
begin
  select organization_id into org from product.organization_members_v80 where user_id=uid and active limit 1;
  with matched as materialized (
    select o.*,row_number() over(partition by o.property_identity_key order by o.quality_score desc,o.latest_direct_evidence_at desc,o.opportunity_id) request_choice
    from opportunity_engine.verified_ranked_opportunities_v83 o
    where public.bridgepoint_flutter_v38_matches(v_model_key,o.vertical_key,o.opportunity_key,o.opportunity_family)
      and (v_priority is null or o.quality_tier=v_priority)
      and (v_stage is null or lower(coalesce(o.intelligence_stage,''))=v_stage)
      and not exists(select 1 from customer_workspace.saved_opportunities_v70 s
        where s.opportunity_id=o.opportunity_id and s.lead_stage in('LOST','CLOSED_LOST')
          and ((org is null and s.user_id=uid) or (org is not null and s.organization_id=org)))
  ) select count(*) into v_total from matched where request_choice=1;

  with matched as materialized (
    select o.*,row_number() over(partition by o.property_identity_key order by o.quality_score desc,o.latest_direct_evidence_at desc,o.opportunity_id) request_choice
    from opportunity_engine.verified_ranked_opportunities_v83 o
    where public.bridgepoint_flutter_v38_matches(v_model_key,o.vertical_key,o.opportunity_key,o.opportunity_family)
      and (v_priority is null or o.quality_tier=v_priority)
      and (v_stage is null or lower(coalesce(o.intelligence_stage,''))=v_stage)
      and not exists(select 1 from customer_workspace.saved_opportunities_v70 s
        where s.opportunity_id=o.opportunity_id and s.lead_stage in('LOST','CLOSED_LOST')
          and ((org is null and s.user_id=uid) or (org is not null and s.organization_id=org)))
  )
  select coalesce(jsonb_agg(to_jsonb(x) order by x.score desc,x.rank_value),'[]'::jsonb) into v_rows from (
    select o.opportunity_id,o.property_id,o.vertical_key model_key,o.opportunity_name model_name,
      row_number() over(order by o.quality_score desc,o.latest_direct_evidence_at desc,o.opportunity_id) rank_value,
      coalesce(a.full_address,concat_ws(', ',p.municipality,p.postal_code,p.state_code)) full_address,
      p.parcel_number,p.municipality,p.county,p.postal_code,p.latitude,p.longitude,p.property_type,p.property_subtype,
      p.land_use_description,p.year_built,p.assessed_total_value,o.quality_score score,o.quality_tier priority,
      round(o.direct_confidence*100,2) confidence_score,o.signal_count event_count,o.direct_signal_count distinct_signal_count,
      coalesce(o.direct_evidence->0->>'title',o.opportunity_name) top_signal_type,o.opportunity_name title,
      format('%s ranks at %s/100 after %s negative points. Verified direct evidence: %s. It has %s direct property signals from %s direct source%s, plus %s corroborating patterns. Review the named signals and dates before outreach.',
        o.opportunity_name,o.quality_score,o.negative_score,
        coalesce((select string_agg(e->>'title',', ') from jsonb_array_elements(o.direct_evidence) with ordinality j(e,n) where n<=3),'not listed'),
        o.direct_signal_count,o.direct_source_count,case when o.direct_source_count=1 then '' else 's' end,o.matched_pattern_count) explanation,
      o.intelligence_stage stage,o.first_detected_at detected_at,o.updated_at last_detected_at,o.recommended_action,
      o.pattern_count,o.matched_pattern_count,o.direct_signal_count matched_signal_count,o.source_count,o.signal_count,
      o.opportunity_family,o.opportunity_key,o.vertical_key,o.urgency_score,o.relevance_score,o.property_intelligence_score,
      o.positive_quality_score raw_positive_score,o.negative_score,o.negative_breakdown,o.latest_direct_evidence_at latest_evidence_at,
      o.direct_source_count,o.direct_evidence,
      jsonb_build_object('positive_score',o.positive_quality_score,'negative_adjustment',o.negative_score,'final_score',o.quality_score,
        'direct_matches',o.direct_signal_count,'direct_sources',o.direct_source_count,'corroborating_patterns',o.matched_pattern_count,
        'all_property_signals',o.signal_count,'all_source_families',o.source_count,'freshness_at',o.latest_direct_evidence_at,
        'penalties',o.negative_breakdown,'named_direct_evidence',o.direct_evidence) score_components
    from matched o join core.properties p on p.property_id=o.property_id
    left join core.addresses a on a.address_id=p.primary_address_id
    where o.request_choice=1
    order by o.quality_score desc,o.latest_direct_evidence_at desc,o.opportunity_id
    limit v_limit offset v_offset
  ) x;
  return jsonb_build_object('complete',true,'generated_at',now(),'engine_version',83,
    'ranking_mode','VERIFIED_DIRECT_EVIDENCE_DEDUPED','minimum_score',75,
    'score_definition','Named property-linked evidence plus corroboration, recency and confidence, minus explicit quality penalties; one property per requested feed.',
    'requested_model_key',v_model_key,'total_results',v_total,'returned_results',jsonb_array_length(v_rows),
    'limit',v_limit,'offset',v_offset,'has_more',v_offset+jsonb_array_length(v_rows)<v_total,'opportunities',v_rows);
end $$;

create or replace function public.bridgepoint_flutter_intelligence_map_v57(
  p_model_key text default 'all',p_min_lat double precision default null,p_max_lat double precision default null,
  p_min_lng double precision default null,p_max_lng double precision default null,p_min_score numeric default null,p_limit integer default 500)
returns jsonb language plpgsql stable security definer
set search_path='pg_catalog','public','api','opportunity_engine','core','customer_workspace','product'
set statement_timeout='25s' as $$
declare uid uuid:=api.require_user(); org uuid; v_limit integer:=least(greatest(coalesce(p_limit,500),1),1000); v_rows jsonb:='[]'::jsonb;
begin
  select organization_id into org from product.organization_members_v80 where user_id=uid and active limit 1;
  with matched as materialized (
    select o.*,row_number() over(partition by o.property_identity_key order by o.quality_score desc,o.latest_direct_evidence_at desc,o.opportunity_id) request_choice
    from opportunity_engine.verified_ranked_opportunities_v83 o join core.properties p on p.property_id=o.property_id
    where o.quality_score>=greatest(coalesce(p_min_score,75),75)
      and p.latitude is not null and p.longitude is not null
      and public.bridgepoint_flutter_v38_matches(p_model_key,o.vertical_key,o.opportunity_key,o.opportunity_family)
      and (p_min_lat is null or p.latitude>=p_min_lat) and (p_max_lat is null or p.latitude<=p_max_lat)
      and (p_min_lng is null or p.longitude>=p_min_lng) and (p_max_lng is null or p.longitude<=p_max_lng)
      and not exists(select 1 from customer_workspace.saved_opportunities_v70 s
        where s.opportunity_id=o.opportunity_id and s.lead_stage in('LOST','CLOSED_LOST')
          and ((org is null and s.user_id=uid) or (org is not null and s.organization_id=org)))
  )
  select coalesce(jsonb_agg(to_jsonb(x) order by x.opportunity_score desc),'[]'::jsonb) into v_rows from (
    select 'VERIFIED_OPPORTUNITY_V83'::text intelligence_type,o.opportunity_id,o.property_id,o.opportunity_name title,
      format('%s/100 after %s negative points. Direct evidence: %s. %s direct signals, %s direct sources, %s corroborating patterns.',
        o.quality_score,o.negative_score,
        coalesce((select string_agg(e->>'title',', ') from jsonb_array_elements(o.direct_evidence) with ordinality j(e,n) where n<=3),'not listed'),
        o.direct_signal_count,o.direct_source_count,o.matched_pattern_count) explanation,
      o.intelligence_stage stage,o.quality_tier priority,o.quality_score opportunity_score,
      round(o.direct_confidence*100,2) opportunity_confidence_percent,o.first_detected_at detected_at,o.updated_at last_detected_at,
      o.vertical_key model_key,o.opportunity_name model_name,p.latitude,p.longitude,p.parcel_number,p.municipality,p.county,p.postal_code,
      p.property_type,p.property_subtype,p.land_use_description,p.year_built,p.assessed_total_value,a.full_address,
      o.quality_score final_score,o.property_intelligence_score overall_score,o.quality_score rank_value,o.quality_tier score_status,
      o.direct_confidence*100 confidence_score,o.signal_count event_count,o.direct_signal_count distinct_signal_count,
      o.source_count verified_event_count,o.source_count,o.pattern_count,o.matched_pattern_count,o.direct_signal_count matched_signal_count,
      coalesce(o.direct_evidence->0->>'title',o.opportunity_name) top_signal_type,o.recommended_action,
      o.positive_quality_score raw_positive_score,o.negative_score,o.negative_breakdown,o.latest_direct_evidence_at latest_evidence_at,
      o.direct_source_count,o.direct_evidence
    from matched o join core.properties p on p.property_id=o.property_id
    left join core.addresses a on a.address_id=p.primary_address_id
    where o.request_choice=1
    order by o.quality_score desc,o.latest_direct_evidence_at desc limit v_limit
  ) x;
  return jsonb_build_object('complete',true,'generated_at',now(),'engine_version',83,
    'ranking_mode','VERIFIED_DIRECT_EVIDENCE_DEDUPED','minimum_score',75,
    'requested_model_key',lower(coalesce(p_model_key,'all')),'limit',v_limit,
    'returned_points',jsonb_array_length(v_rows),'has_more',false,'point_type','VERIFIED_OPPORTUNITY_V83','points',v_rows);
end $$;

create or replace function public.bridgepoint_property_timeline_v78(p_property_id uuid,p_limit integer default 120)
returns jsonb language plpgsql stable security definer
set search_path='pg_catalog','public','api','customer_workspace','intelligence','pattern_engine','opportunity_engine','core' as $$
declare uid uuid:=api.require_user(); items jsonb; lim integer:=least(greatest(coalesce(p_limit,120),10),300);
begin
  if not exists(select 1 from core.properties where property_id=p_property_id and active) then raise exception 'Property not found'; end if;
  select coalesce(jsonb_agg(t.item order by t.timeline_at desc),'[]'::jsonb) into items from (
    select * from (
      select coalesce(s.effective_at,s.detected_at,s.created_at) timeline_at,
        jsonb_build_object(
          'timeline_type','SIGNAL','timeline_at',coalesce(s.effective_at,s.detected_at,s.created_at),
          'title',s.title,'description',coalesce(s.description,
            case when coalesce(s.evidence_summary->>'matching_precision','') ilike 'AREA%'
              then 'This is area-level context associated with the property location; it is not a property-specific claim or verified condition.'
              else 'BridgePoint linked this source observation to the property record.' end),
          'signal_key',coalesce(s.metadata->>'signal_key',''),'detector_key',s.detector_key,
          'source_label',coalesce(s.evidence_summary->>'provider',s.evidence_summary->>'source',s.detector_key),
          'provider',coalesce(s.evidence_summary->>'provider',s.evidence_summary->>'source',s.detector_key),
          'confidence',s.confidence,'severity',s.severity,'item_id',s.signal_id,
          'support_level',case when coalesce(s.evidence_summary->>'matching_precision','') ilike 'AREA%'
              or coalesce(s.evidence_summary->>'storage_mode','') ilike '%area_context%' then 'AREA_CONTEXT'
            when cardinality(opportunity_engine.signal_verticals_v83(coalesce(s.metadata->>'signal_key','')))>0 then 'DIRECT_MODEL_EVIDENCE'
            else 'SUPPORTING_CONTEXT' end,
          'is_direct_model_match',cardinality(opportunity_engine.signal_verticals_v83(coalesce(s.metadata->>'signal_key','')))>0,
          'model_uses',to_jsonb(opportunity_engine.signal_verticals_v83(coalesce(s.metadata->>'signal_key',''))),
          'match_method',coalesce(s.evidence_summary->>'matching_precision',s.evidence_summary->>'storage_mode','PROPERTY_RECORD_LINK'),
          'why_it_matters',case
            when s.detector_key='NOAA_PROPERTY_SIGNAL_V1' then 'Recent weather exposure can justify a timely inspection or customer check-in, but it does not prove damage.'
            when s.detector_key='CT_NFIRS_PROPERTY_SIGNAL_V1' then 'A reported fire record can support restoration or claims review after the source record and address match are verified.'
            when s.detector_key='CT_OPM_PROPERTY_TRANSITION_V1' then 'A recorded ownership or property transition can change timing, decision-maker, or improvement needs.'
            when s.detector_key in('CT_DEEP_REACT_V50','CT_DEEP_SPILL_RELEASE_V1','CT_DEEP_UST_RELEASE_V1') then 'Environmental activity can create remediation, redevelopment, inspection, or specialized contracting needs.'
            when coalesce(s.evidence_summary->>'matching_precision','') ilike 'AREA%' then 'This broad-area context may change risk or timing, but it must not be presented as a property-specific event.'
            else 'This observation adds dated property context and should be verified against the named source before action.' end,
          'limitations',case
            when coalesce(s.evidence_summary->>'matching_precision','') ilike 'AREA%' then 'Area context only; not a property claim, loss, inspection, or proof of condition.'
            when s.detector_key='NOAA_PROPERTY_SIGNAL_V1' then 'Weather exposure estimate; not verified property damage or a forensic hail report.'
            else 'Source-linked intelligence; verify identity, date, scope, and current status before relying on it.' end,
          'evidence_summary',s.evidence_summary) item
      from intelligence.signals s where lower(s.entity_type)='property' and s.entity_id=p_property_id
      union all
      select coalesce(p.latest_signal_at,p.detected_at,p.updated_at),jsonb_build_object(
        'timeline_type','PATTERN','timeline_at',coalesce(p.latest_signal_at,p.detected_at,p.updated_at),
        'title',p.pattern_name,'description',format('%s property observations across %s source families formed a corroborating sequence. A pattern adds context; it is not direct proof by itself.',p.signal_count,p.distinct_sources),
        'source_label',p.pattern_family,'confidence',p.pattern_confidence,'severity',null,
        'stage',p.intelligence_stage,'item_id',p.detected_pattern_id,'support_level','CORROBORATING_PATTERN',
        'why_it_matters','Patterns show how separate observations relate over time and can strengthen a directly evidenced opportunity.',
        'limitations','A pattern cannot replace a qualifying direct signal or independent verification.')
      from pattern_engine.patterns_v36 p where lower(p.entity_type)='property' and p.entity_id=p_property_id and p.pattern_status='ACTIVE'
      union all
      select o.latest_direct_evidence_at,jsonb_build_object(
        'timeline_type','OPPORTUNITY','timeline_at',o.latest_direct_evidence_at,'title',o.opportunity_name,
        'description',format('%s verified direct signals from %s direct source%s plus %s corroborating patterns produced a final evidence score of %s after %s negative points.',o.direct_signal_count,o.direct_source_count,case when o.direct_source_count=1 then '' else 's' end,o.matched_pattern_count,o.quality_score,o.negative_score),
        'source_label',o.vertical_key,'confidence',o.direct_confidence,'severity',o.quality_score,
        'stage',o.intelligence_stage,'item_id',o.opportunity_id,'support_level','VERIFIED_OPPORTUNITY',
        'direct_evidence',o.direct_evidence,'why_it_matters','This is a ranked review candidate backed by the named direct signals, not a guaranteed project or sale.',
        'limitations','Verify every material fact and inspect the property before making a customer-facing claim.')
      from opportunity_engine.verified_ranked_opportunities_v83 o where o.property_id=p_property_id
      union all
      select n.created_at,jsonb_build_object('timeline_type','NOTE','timeline_at',n.created_at,
        'title',initcap(replace(n.preset_key,'_',' '))||' note','description',n.note_text,'source_label','Your workspace',
        'stage',n.status,'item_id',n.note_id,'support_level','CUSTOMER_NOTE')
      from customer_workspace.notes_v70 n where n.user_id=uid and n.property_id=p_property_id
      union all
      select e.event_at,jsonb_build_object('timeline_type','CLAIM','timeline_at',e.event_at,'title',e.title,
        'description',e.description,'source_label',case e.source_kind when 'AUTHORIZED_INTEGRATION' then 'Authorized integration'
          when 'AUTOMATION' then 'BridgePoint workflow' else 'Your claims workspace' end,
        'stage',e.claim_stage,'item_id',e.claim_event_id,'support_level','PRIVATE_CLAIM_WORKFLOW')
      from customer_workspace.claim_events_v78 e where e.user_id=uid and e.property_id=p_property_id
    ) all_items order by timeline_at desc limit lim
  ) t;
  return jsonb_build_object('complete',true,'version',83,'property_id',p_property_id,'generated_at',now(),
    'item_count',jsonb_array_length(items),'timeline',items,
    'explanation','A chronological property story that names each signal, source, date, matching scope, confidence, limitation, direct-model use, pattern, verified opportunity, note, and authorized claim event.');
end $$;

create or replace function public.bridgepoint_daily_brief_v74()
returns jsonb language plpgsql security definer
set search_path='pg_catalog','public','api','accounts','auth','customer_workspace','opportunity_engine','core','automation','intelligence','product' as $$
declare uid uuid:=api.require_user(); org uuid; display text; new_signals bigint:=0; refreshed_sources bigint:=0;
  verified_changes bigint:=0; due_count bigint:=0; top_rows jsonb:='[]'::jsonb; unread bigint:=0;
begin
  select organization_id into org from product.organization_members_v80 where user_id=uid and active limit 1;
  select coalesce(nullif(btrim(p.display_name),''),nullif(btrim(u.raw_user_meta_data->>'display_name'),''),initcap(split_part(u.email,'@',1)),'there')
    into display from auth.users u left join customer_workspace.profiles_v70 p on p.user_id=u.id where u.id=uid;
  select count(*) into new_signals from intelligence.signals where created_at>=now()-interval '24 hours';
  select count(*) into refreshed_sources from automation.source_registry where last_successful_import_at>=now()-interval '24 hours';
  select count(*) into verified_changes from opportunity_engine.verified_ranked_opportunities_v83
    where global_property_choice=1 and updated_at>=now()-interval '24 hours';
  select count(*) into due_count from customer_workspace.saved_opportunities_v70 s
    where ((org is null and s.user_id=uid) or (org is not null and s.organization_id=org))
      and s.lead_stage not in('WON','LOST','CLOSED_LOST') and s.next_action_at is not null and s.next_action_at<=now()+interval '24 hours';
  select coalesce(jsonb_agg(to_jsonb(x) order by x.score desc),'[]'::jsonb) into top_rows from (
    select o.opportunity_id,o.property_id,o.opportunity_name title,o.quality_score score,
      round(o.direct_confidence*100,0) confidence,o.quality_tier priority,
      format('%s direct property signals (%s) from %s direct source%s, plus %s corroborating patterns; %s negative points applied.',
        o.direct_signal_count,coalesce((select string_agg(e->>'title',', ') from jsonb_array_elements(o.direct_evidence) with ordinality j(e,n) where n<=3),'not listed'),
        o.direct_source_count,case when o.direct_source_count=1 then '' else 's' end,o.matched_pattern_count,o.negative_score) reason,
      o.recommended_action,o.vertical_key,coalesce(a.full_address,concat_ws(', ',p.municipality,p.state_code)) full_address
    from opportunity_engine.verified_ranked_opportunities_v83 o join core.properties p on p.property_id=o.property_id
    left join core.addresses a on a.address_id=p.primary_address_id
    where o.global_property_choice=1 and not exists(select 1 from customer_workspace.saved_opportunities_v70 s
      where s.opportunity_id=o.opportunity_id and s.lead_stage in('LOST','CLOSED_LOST')
        and ((org is null and s.user_id=uid) or (org is not null and s.organization_id=org)))
    order by o.quality_score desc,o.latest_direct_evidence_at desc limit 5
  ) x;
  perform customer_workspace.refresh_notifications_v74(uid);
  select count(*) into unread from customer_workspace.notifications_v74 where user_id=uid and read_at is null;
  return jsonb_build_object('complete',true,'engine_version',83,'generated_at',now(),'display_name',display,
    'is_owner',accounts.is_platform_admin(),'overnight',jsonb_build_object('new_signals',new_signals,
      'refreshed_sources',refreshed_sources,'strict_opportunity_updates',verified_changes,'follow_ups_due',due_count),
    'top_opportunities',top_rows,'unread_notifications',unread,
    'summary',format('%s new evidence signals and %s deduplicated, direct-evidence opportunity updates were processed in the last 24 hours.',new_signals,verified_changes));
end $$;

create or replace function public.bridgepoint_flutter_dashboard_v57(p_model_key text default 'all',p_limit integer default 10)
returns jsonb language plpgsql stable security definer
set search_path='pg_catalog','public','pattern_engine','scoring_engine','opportunity_engine','core'
set statement_timeout='25s' as $$
declare v_base jsonb; v_feed jsonb; v_pattern jsonb; v_score jsonb; v_opportunity jsonb;
  v_property_count bigint; v_verified_count bigint;
begin
  v_base:=public.bridgepoint_flutter_live_status_v56(p_model_key,p_limit);
  select count(*) into v_property_count from core.properties where active and state_code='CT';
  select count(*) into v_verified_count from opportunity_engine.verified_ranked_opportunities_v83 where global_property_choice=1;
  v_feed:=public.bridgepoint_flutter_opportunities_v57(p_model_key,least(greatest(coalesce(p_limit,10),1),50),0,null,null);
  v_pattern:=pattern_engine.readiness_v36(); v_score:=scoring_engine.readiness_v37(); v_opportunity:=opportunity_engine.readiness_v38();
  return v_base||jsonb_build_object('live_contract_version',83,'property_count_estimate',v_property_count,
    'property_count_kind','CANONICAL_ACTIVE_CT_PROPERTIES','active_opportunities',v_verified_count,
    'raw_engine_opportunities',coalesce((v_opportunity->>'active_opportunities')::bigint,0),
    'opportunity_count_kind','DEDUPED_VERIFIED_DIRECT_EVIDENCE_PROPERTIES','active_patterns',coalesce((v_pattern->>'active_patterns')::bigint,0),
    'property_scores',coalesce((v_score->>'property_scores')::bigint,0),'ranked_opportunities',coalesce(v_feed->'opportunities','[]'::jsonb));
end $$;

revoke all on function public.bridgepoint_flutter_opportunities_v57(text,integer,integer,text,text) from public,anon;
revoke all on function public.bridgepoint_flutter_intelligence_map_v57(text,double precision,double precision,double precision,double precision,numeric,integer) from public,anon;
revoke all on function public.bridgepoint_property_timeline_v78(uuid,integer) from public,anon;
revoke all on function public.bridgepoint_daily_brief_v74() from public,anon;
revoke all on function public.bridgepoint_flutter_dashboard_v57(text,integer) from public,anon;
grant execute on function public.bridgepoint_flutter_opportunities_v57(text,integer,integer,text,text) to authenticated,service_role;
grant execute on function public.bridgepoint_flutter_intelligence_map_v57(text,double precision,double precision,double precision,double precision,numeric,integer) to authenticated,service_role;
grant execute on function public.bridgepoint_property_timeline_v78(uuid,integer) to authenticated,service_role;
grant execute on function public.bridgepoint_daily_brief_v74() to authenticated,service_role;
grant execute on function public.bridgepoint_flutter_dashboard_v57(text,integer) to authenticated,service_role;

comment on materialized view opportunity_engine.verified_ranked_opportunities_v83 is
  'V83 customer queue: requires named non-area direct evidence, deduplicates property identity per vertical, and supports request-level deduplication.';
