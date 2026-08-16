-- BridgePoint expansion runtime ambiguity + state-scope hotfix v178
-- Persists production fixes for approval generation, approval continuation,
-- and protection against authoritative-but-off-state discovery results.

do $fix$
declare ddl text;
begin
  select pg_get_functiondef(p.oid) into ddl
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='bridgepoint_expansion_worker_discovery_v90';

  if ddl is null then raise exception 'bridgepoint_expansion_worker_discovery_v90 missing'; end if;
  ddl := replace(ddl,'approval_id uuid;','v_approval_id uuid;');
  ddl := replace(ddl,'returning approval_id into approval_id;','returning approval_id into v_approval_id;');
  ddl := replace(ddl,'''approval_id'',approval_id','''approval_id'',v_approval_id');
  execute ddl;
end
$fix$;

do $fix$
declare ddl text;
begin
  select pg_get_functiondef(p.oid) into ddl
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='bridgepoint_expansion_approval_v90';

  if ddl is null then raise exception 'bridgepoint_expansion_approval_v90 missing'; end if;
  ddl := replace(ddl,' step_key text; next_key text;',' v_step_key text; v_next_key text;');
  ddl := replace(ddl,'select s.step_key into step_key from automation.geographic_expansion_steps_v90 s where s.step_id=a.step_id;','select s.step_key into v_step_key from automation.geographic_expansion_steps_v90 s where s.step_id=a.step_id;');
  ddl := replace(ddl,'select step_key into next_key from automation.geographic_expansion_steps_v90 n where n.run_id=a.run_id and n.step_order>(select step_order from automation.geographic_expansion_steps_v90 where step_id=a.step_id) and n.step_status=''PENDING'' order by n.step_order limit 1;',
    'select n.step_key into v_next_key from automation.geographic_expansion_steps_v90 n where n.run_id=a.run_id and n.step_order>(select s2.step_order from automation.geographic_expansion_steps_v90 s2 where s2.step_id=a.step_id) and n.step_status=''PENDING'' order by n.step_order limit 1;');
  ddl := replace(ddl,'where run_id=a.run_id and step_key=next_key;','where automation.geographic_expansion_steps_v90.run_id=a.run_id and automation.geographic_expansion_steps_v90.step_key=v_next_key;');
  ddl := replace(ddl,'case when next_key=''ACTIVATE'' then ''READY'' when next_key in(''PROPERTY_FOUNDATION'',''CONTEXT_LAYERS'') then ''INGESTION'' else ''RUNNING'' end,current_phase=coalesce(next_key,current_phase)',
    'case when v_next_key=''ACTIVATE'' then ''READY'' when v_next_key in(''PROPERTY_FOUNDATION'',''CONTEXT_LAYERS'') then ''INGESTION'' else ''RUNNING'' end,current_phase=coalesce(v_next_key,automation.geographic_expansion_runs_v86.current_phase)');
  ddl := replace(ddl,'''next_step'',next_key','''next_step'',v_next_key');
  execute ddl;
end
$fix$;

do $fix$
declare ddl text; old_block text; new_block text;
begin
  select pg_get_functiondef(p.oid) into ddl
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='bridgepoint_expansion_approval_v90';

  old_block := $old$ if d='APPROVED' and a.approval_type='SOURCE_REVIEW' then
   update automation.geographic_source_candidates_v86 set decision_status='ACCEPTED',reviewed_at=now(),metadata=coalesce(metadata,'{}'::jsonb)||jsonb_build_object('owner_approved',true,'approved_at',now())
   where run_id=a.run_id and decision_status='NEEDS_REVIEW' and discovery_method='EXPANSION_WORKER_V90';
 end if;$old$;

  new_block := $new$ if d='APPROVED' and a.approval_type='SOURCE_REVIEW' then
   update automation.geographic_source_candidates_v86 c
   set decision_status='REJECTED',reviewed_at=now(),
       metadata=coalesce(c.metadata,'{}'::jsonb)||jsonb_build_object('owner_approval_filtered',true,'rejection_reason','EXPLICIT_OTHER_STATE_SOURCE','filtered_at',now())
   where c.run_id=a.run_id and c.decision_status='NEEDS_REVIEW' and c.discovery_method='EXPANSION_WORKER_V90'
     and exists (
       select 1
       from product.geographic_markets_v77 other_state
       where other_state.state_code<>a.state_code
         and (
           lower(coalesce(c.candidate_name,'')) like '%'||lower(other_state.state_name)||'%'
           or lower(coalesce(c.provider,'')) like '%.'||lower(other_state.state_code)||'.gov%'
           or lower(coalesce(c.source_url,'')) like '%.'||lower(other_state.state_code)||'.gov/%'
         )
         and not (
           lower(coalesce(c.candidate_name,'')) like '%'||lower((select gm.state_name from product.geographic_markets_v77 gm where gm.state_code=a.state_code))||'%'
           or lower(coalesce(c.provider,'')) like '%.'||lower(a.state_code)||'.gov%'
           or lower(coalesce(c.source_url,'')) like '%.'||lower(a.state_code)||'.gov/%'
         )
     );

   update automation.geographic_source_candidates_v86 c
   set decision_status='ACCEPTED',reviewed_at=now(),metadata=coalesce(c.metadata,'{}'::jsonb)||jsonb_build_object('owner_approved',true,'approved_at',now(),'state_conflict_filter_passed',true)
   where c.run_id=a.run_id and c.decision_status='NEEDS_REVIEW' and c.discovery_method='EXPANSION_WORKER_V90';
 end if;$new$;

  if position(old_block in ddl)>0 then
    ddl := replace(ddl,old_block,new_block);
    execute ddl;
  end if;
end
$fix$;
