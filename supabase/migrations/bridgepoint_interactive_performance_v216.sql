-- BridgePoint v216 interactive-performance production fix.
-- Keeps customer-facing dashboard/timeline reads responsive while background expansion and pattern work continue.

create index if not exists verified_opportunities_first_detected_v216_idx
  on opportunity_engine.verified_ranked_opportunities_v83(first_detected_at desc)
  where global_property_choice=1;

create index if not exists verified_opportunities_property_time_v216_idx
  on opportunity_engine.verified_ranked_opportunities_v83(property_id,latest_direct_evidence_at desc);

create index if not exists patterns_active_property_time_v216_idx
  on pattern_engine.patterns_v36(entity_type,entity_id,latest_signal_at desc)
  where pattern_status='ACTIVE';

create or replace function public.bridgepoint_flutter_dashboard_v57(
  p_model_key text default 'all',
  p_limit integer default 10
) returns jsonb
language plpgsql
stable security definer
set search_path='pg_catalog','public','api','automation','core','pattern_engine','scoring_engine','opportunity_engine','infrastructure','intelligence','learning_engine','product'
set statement_timeout='8s'
as $$
declare
 uid uuid:=api.require_user();
 v_is_owner boolean:=product.has_platform_override(uid);
 v_allowed text[]:='{}'::text[];
 v_limit int:=least(greatest(coalesce(p_limit,10),1),25);
 v_property_count bigint:=0; v_patterns bigint:=0; v_scores bigint:=0; v_raw_opps bigint:=0; v_active bigint:=0;
 v_new_24h bigint:=0; v_latest timestamptz; v_top_new jsonb:='[]'::jsonb; v_ranked jsonb:='[]'::jsonb; v_workers jsonb; v_sources jsonb; v_grid bigint:=0;
begin
 select coalesce(array_agg(model_key order by model_key),'{}'::text[])
 into v_allowed from product.user_allowed_model_keys_v204(uid);

 select greatest(coalesce(c.reltuples,0),0)::bigint into v_property_count
 from pg_class c join pg_namespace n on n.oid=c.relnamespace
 where n.nspname='core' and c.relname='properties';
 select greatest(coalesce(c.reltuples,0),0)::bigint into v_patterns
 from pg_class c join pg_namespace n on n.oid=c.relnamespace
 where n.nspname='pattern_engine' and c.relname='patterns_v36';
 select greatest(coalesce(c.reltuples,0),0)::bigint into v_scores
 from pg_class c join pg_namespace n on n.oid=c.relnamespace
 where n.nspname='scoring_engine' and c.relname='property_scores_v37';
 select greatest(coalesce(c.reltuples,0),0)::bigint into v_raw_opps
 from pg_class c join pg_namespace n on n.oid=c.relnamespace
 where n.nspname='opportunity_engine' and c.relname='opportunities_v38';

 if v_is_owner then
   select count(*) into v_active
   from opportunity_engine.verified_ranked_opportunities_v83 where global_property_choice=1;
 else
   select coalesce(max(nullif(p.configuration->>'verified_opportunity_count','')::bigint),0)
   into v_active
   from product.subscriptions s join product.packages p on p.package_id=s.package_id
   where s.user_id=uid and s.status in('trialing','active');
 end if;

 select count(*),max(first_detected_at) into v_new_24h,v_latest
 from opportunity_engine.verified_ranked_opportunities_v83
 where global_property_choice=1 and first_detected_at>=now()-interval '24 hours';

 select coalesce(jsonb_agg(to_jsonb(x) order by x.quality_score desc,x.first_detected_at desc),'[]'::jsonb)
 into v_top_new from (
   select opportunity_id,property_id,opportunity_name,quality_score,confidence_score,urgency_score,full_address,recommended_action,first_detected_at
   from opportunity_engine.verified_ranked_opportunities_v83
   where global_property_choice=1 and first_detected_at>=now()-interval '24 hours'
     and (v_is_owner or exists(
       select 1 from unnest(v_allowed) k
       where public.bridgepoint_flutter_v38_matches(k,vertical_key,opportunity_key,opportunity_family)
     ))
   order by quality_score desc nulls last,first_detected_at desc limit 10
 ) x;

 select coalesce(jsonb_agg(to_jsonb(x) order by x.score desc,x.latest_evidence_at desc),'[]'::jsonb)
 into v_ranked from (
   select o.opportunity_id,o.property_id,o.vertical_key model_key,o.opportunity_name model_name,
     coalesce(a.full_address,concat_ws(', ',p.municipality,p.postal_code,p.state_code)) full_address,
     p.parcel_number,p.municipality,p.county,p.postal_code,p.state_code,p.latitude,p.longitude,
     p.property_type,p.property_subtype,p.land_use_description,p.year_built,p.assessed_total_value,
     o.quality_score score,o.quality_tier priority,round(o.direct_confidence*100,2) confidence_score,
     o.signal_count event_count,o.direct_signal_count distinct_signal_count,
     coalesce(o.direct_evidence->0->>'title',o.opportunity_name) top_signal_type,
     o.opportunity_name title,o.recommended_action,o.intelligence_stage stage,
     o.first_detected_at detected_at,o.updated_at last_detected_at,
     o.latest_direct_evidence_at latest_evidence_at,o.direct_source_count,
     o.direct_signal_count matched_signal_count,o.matched_pattern_count,o.negative_score,o.direct_evidence
   from opportunity_engine.verified_ranked_opportunities_v83 o
   join core.properties p on p.property_id=o.property_id
   left join core.addresses a on a.address_id=p.primary_address_id
   where o.global_property_choice=1
     and (v_is_owner or exists(
       select 1 from unnest(v_allowed) k
       where public.bridgepoint_flutter_v38_matches(k,o.vertical_key,o.opportunity_key,o.opportunity_family)
     ))
     and (lower(btrim(coalesce(p_model_key,'all')))='all'
       or public.bridgepoint_flutter_v38_matches(lower(btrim(p_model_key)),o.vertical_key,o.opportunity_key,o.opportunity_family))
   order by o.quality_score desc,o.latest_direct_evidence_at desc,o.opportunity_id
   limit v_limit
 ) x;

 select jsonb_build_object(
   'total',count(*),
   'enabled',count(*) filter(where coalesce((to_jsonb(w)->>'enabled')::boolean,true)),
   'recent_heartbeat',count(*) filter(where coalesce(nullif(to_jsonb(w)->>'last_heartbeat_at','')::timestamptz,nullif(to_jsonb(w)->>'updated_at','')::timestamptz)>=now()-interval '10 minutes')
 ) into v_workers from automation.workers w;

 select jsonb_build_object(
   'registered',count(*),'enabled',count(*) filter(where enabled),
   'healthy',count(*) filter(where lower(coalesce(health_status,'')) in('healthy','active','ok','online')),
   'records_tracked',coalesce(sum(total_records_ingested),0),
   'building_records_tracked',coalesce(sum(total_records_ingested) filter(where source_code ilike '%building%' or source_name ilike '%building%'),0)
 ) into v_sources from automation.source_registry where state_code='CT' or state_code is null;

 if to_regclass('grid.area_contexts') is not null then
   execute 'select count(*) from grid.area_contexts where active' into v_grid;
 end if;

 return jsonb_build_object(
   'complete',true,'generated_at',now(),'dashboard_refreshed_at',now(),'live_contract_version',216,
   'requested_model_key',p_model_key,'data_scope','ENTITLED_MARKETS',
   'property_count_estimate',v_property_count,'property_count_kind','CANONICAL_ACTIVE_PROPERTIES_ESTIMATE',
   'active_opportunities',v_active,
   'active_opportunities_kind',case when v_is_owner then 'VERIFIED_UNIQUE_GLOBAL' else 'PACKAGE_DELIVERY_COUNT' end,
   'new_opportunities_24h',v_new_24h,'latest_opportunity_detected_at',v_latest,
   'top_new_opportunities_24h',v_top_new,'ranked_opportunities',v_ranked,
   'opportunity_count_kind','VERIFIED_DIRECT_EVIDENCE_ENTITLEMENT_GATED','raw_engine_opportunities',v_raw_opps,
   'active_patterns',v_patterns,'property_scores',v_scores,'active_grid_contexts',v_grid,
   'workers',coalesce(v_workers,'{}'::jsonb),'source_health',coalesce(v_sources,'{}'::jsonb),
   'connected_source_families',(select count(*) from automation.source_registry),
   'active_property_packages',(select count(*) from product.packages where active and package_type<>'technology'),
   'new_intelligence',jsonb_build_object(
     'building_2d_available',to_regclass('analytics.ct_2023_building_2d_property_baseline_v50') is not null,
     'building_3d_available',to_regclass('analytics.ct_2023_building_3d_property_baseline_v50') is not null,
     'solar_available',to_regclass('infrastructure.solar_installations') is not null,
     'patterns_available',to_regclass('intelligence.pattern_matches') is not null,
     'relationships_available',to_regclass('core.entity_relationships') is not null,
     'outcome_learning_available',to_regclass('learning_engine.current_outcomes_v39') is not null
   ),
   'auto_refresh_supported',true,'raw_payloads_exposed',false,'private_metadata_exposed',false
 );
end $$;

create or replace function public.bridgepoint_property_timeline_v78(
  p_property_id uuid,
  p_limit integer default 120
) returns jsonb
language plpgsql
stable security definer
set search_path='pg_catalog','public','api','customer_workspace','intelligence','pattern_engine','opportunity_engine','core'
set statement_timeout='5s'
as $$
declare uid uuid:=api.require_user(); items jsonb; lim integer:=least(greatest(coalesce(p_limit,120),10),200);
begin
 if not exists(select 1 from core.properties where property_id=p_property_id and active) then
   raise exception 'Property not found';
 end if;

 with sig as materialized (
   select * from intelligence.signals s
   where s.entity_type='property' and s.entity_id=p_property_id
   order by coalesce(s.effective_at,s.detected_at,s.created_at) desc limit lim
 ), pat as materialized (
   select * from pattern_engine.patterns_v36 p
   where p.entity_type='property' and p.entity_id=p_property_id and p.pattern_status='ACTIVE'
   order by coalesce(p.latest_signal_at,p.detected_at,p.updated_at) desc limit lim
 ), opp as materialized (
   select * from opportunity_engine.verified_ranked_opportunities_v83 o
   where o.property_id=p_property_id
   order by o.latest_direct_evidence_at desc nulls last,o.quality_score desc limit least(lim,40)
 ), nts as materialized (
   select * from customer_workspace.notes_v70 n
   where n.user_id=uid and n.property_id=p_property_id
   order by n.created_at desc limit lim
 ), clm as materialized (
   select * from customer_workspace.claim_events_v78 e
   where e.user_id=uid and e.property_id=p_property_id
   order by e.event_at desc limit lim
 ), all_items as (
   select coalesce(s.effective_at,s.detected_at,s.created_at) timeline_at,
     jsonb_build_object(
       'timeline_type','SIGNAL','timeline_at',coalesce(s.effective_at,s.detected_at,s.created_at),
       'title',s.title,
       'description',coalesce(s.description,case when coalesce(s.evidence_summary->>'matching_precision','') ilike 'AREA%'
         then 'This is area-level context associated with the property location; it is not a property-specific claim or verified condition.'
         else 'BridgePoint linked this source observation to the property record.' end),
       'signal_key',coalesce(s.metadata->>'signal_key',''),'detector_key',s.detector_key,
       'source_label',coalesce(s.evidence_summary->>'provider',s.evidence_summary->>'source',s.detector_key),
       'provider',coalesce(s.evidence_summary->>'provider',s.evidence_summary->>'source',s.detector_key),
       'confidence',s.confidence,'severity',s.severity,'item_id',s.signal_id,
       'support_level',case
         when coalesce(s.evidence_summary->>'matching_precision','') ilike 'AREA%'
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
       'evidence_summary',s.evidence_summary
     ) item
   from sig s

   union all
   select coalesce(p.latest_signal_at,p.detected_at,p.updated_at),jsonb_build_object(
     'timeline_type','PATTERN','timeline_at',coalesce(p.latest_signal_at,p.detected_at,p.updated_at),
     'title',p.pattern_name,
     'description',format('%s property observations across %s source families formed a corroborating sequence. A pattern adds context; it is not direct proof by itself.',p.signal_count,p.distinct_sources),
     'source_label',p.pattern_family,'confidence',p.pattern_confidence,'severity',null,
     'stage',p.intelligence_stage,'item_id',p.detected_pattern_id,'support_level','CORROBORATING_PATTERN',
     'why_it_matters','Patterns show how separate observations relate over time and can strengthen a directly evidenced opportunity.',
     'limitations','A pattern cannot replace a qualifying direct signal or independent verification.'
   ) from pat p

   union all
   select o.latest_direct_evidence_at,jsonb_build_object(
     'timeline_type','OPPORTUNITY','timeline_at',o.latest_direct_evidence_at,'title',o.opportunity_name,
     'description',format('%s verified direct signals from %s direct source%s plus %s corroborating patterns produced a final evidence score of %s after %s negative points.',o.direct_signal_count,o.direct_source_count,case when o.direct_source_count=1 then '' else 's' end,o.matched_pattern_count,o.quality_score,o.negative_score),
     'source_label',o.vertical_key,'confidence',o.direct_confidence,'severity',o.quality_score,
     'stage',o.intelligence_stage,'item_id',o.opportunity_id,'support_level','VERIFIED_OPPORTUNITY',
     'direct_evidence',o.direct_evidence,
     'why_it_matters','This is a ranked review candidate backed by the named direct signals, not a guaranteed project or sale.',
     'limitations','Verify every material fact and inspect the property before making a customer-facing claim.'
   ) from opp o

   union all
   select n.created_at,jsonb_build_object(
     'timeline_type','NOTE','timeline_at',n.created_at,
     'title',initcap(replace(n.preset_key,'_',' '))||' note','description',n.note_text,
     'source_label','Your workspace','stage',n.status,'item_id',n.note_id,'support_level','CUSTOMER_NOTE'
   ) from nts n

   union all
   select e.event_at,jsonb_build_object(
     'timeline_type','CLAIM','timeline_at',e.event_at,'title',e.title,'description',e.description,
     'source_label',case e.source_kind when 'AUTHORIZED_INTEGRATION' then 'Authorized integration'
       when 'AUTOMATION' then 'BridgePoint workflow' else 'Your claims workspace' end,
     'stage',e.claim_stage,'item_id',e.claim_event_id,'support_level','PRIVATE_CLAIM_WORKFLOW'
   ) from clm e
 )
 select coalesce(jsonb_agg(item order by timeline_at desc),'[]'::jsonb)
 into items from (select timeline_at,item from all_items order by timeline_at desc limit lim) z;

 return jsonb_build_object(
   'complete',true,'version',216,'property_id',p_property_id,'generated_at',now(),
   'item_count',jsonb_array_length(items),'timeline',items,
   'explanation','A chronological property story that names each signal, source, date, matching scope, confidence, limitation, direct-model use, pattern, verified opportunity, note, and authorized claim event.'
 );
end $$;

create or replace function automation.expansion_property_materializer_tick_v203()
returns jsonb
language plpgsql security definer
set search_path='pg_catalog','automation','public'
as $$
declare r record; out_items jsonb:='[]'::jsonb; one jsonb; processed int:=0;
begin
 for r in
   select run_id,state_code from automation.geographic_expansion_runs_v86
   where run_status='INGESTION' and current_phase='PROPERTY_FOUNDATION'
     and not exists(
       select 1 from automation.geographic_expansion_approvals_v90 a
       where a.run_id=geographic_expansion_runs_v86.run_id and a.approval_status='PENDING'
     )
   order by updated_at limit 1
 loop
   begin
     one:=public.bridgepoint_expansion_worker_materialize_properties_v90(r.run_id,600);
     out_items:=out_items||jsonb_build_array(jsonb_build_object('run_id',r.run_id,'state_code',r.state_code,'result',one));
     processed:=processed+1;
   exception when others then
     out_items:=out_items||jsonb_build_array(jsonb_build_object('run_id',r.run_id,'state_code',r.state_code,'error',sqlerrm));
   end;
 end loop;
 return jsonb_build_object('complete',true,'runs_processed',processed,'runs',out_items,'batch_size',600);
end $$;

select cron.unschedule('bridgepoint-expansion-property-materializer-v203');
select cron.schedule('bridgepoint-expansion-property-materializer-v203','* * * * *','select automation.expansion_property_materializer_tick_v203();');
select cron.unschedule('bridgepoint-pattern-v36-1');
select cron.unschedule('bridgepoint-pattern-v36-2');
select cron.unschedule('bridgepoint-pattern-v36-backfill');
select cron.schedule('bridgepoint-pattern-v36-1','*/2 * * * *',$$select pattern_engine.worker_v36(350,'AUTO-PATTERN-1');$$);
select cron.schedule('bridgepoint-pattern-v36-2','1-59/2 * * * *',$$select pattern_engine.worker_v36(350,'AUTO-PATTERN-2');$$);
select cron.schedule('bridgepoint-pattern-v36-backfill','*/30 * * * *','select pattern_engine.backfill_queue_v36(1500);');
