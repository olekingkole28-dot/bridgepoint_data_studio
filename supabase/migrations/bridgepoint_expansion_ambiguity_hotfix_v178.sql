-- BridgePoint expansion runtime ambiguity hotfix v178
-- Persists the production fixes for SOURCE_REVIEW approval generation and owner approval continuation.

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
