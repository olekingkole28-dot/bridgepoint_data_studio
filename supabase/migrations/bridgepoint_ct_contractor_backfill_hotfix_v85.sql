-- Increase only the bounded initial-backfill batch. The Edge Function still
-- caps every page and run, retries rate limits, and resumes from its watermark.
create or replace function automation.ct_hic_scheduler_tick_v85()
returns jsonb language plpgsql security definer
set search_path='pg_catalog','public','automation','net' as $$
declare s record;request_id bigint;
begin
  select configuration->>'task_token' token into s from automation.source_registry
  where source_code='CT_DCP_HIC_REGISTRY' and enabled and
    (next_scheduled_check_at is null or next_scheduled_check_at<=now() or coalesce((configuration->>'has_more')::boolean,false));
  if not found then return jsonb_build_object('complete',true,'requests_created',0); end if;
  select net.http_post(
    url:='https://xdfsjztwgsbmabshzsjw.supabase.co/functions/v1/bridgepoint-ct-hic-registry-refresh-v85',
    headers:=jsonb_build_object('Content-Type','application/json'),
    body:=jsonb_build_object('task_token',s.token,'page_size',1000,'max_pages',20),
    timeout_milliseconds:=300000) into request_id;
  return jsonb_build_object('complete',true,'requests_created',1,'request_id',request_id);
end $$;
revoke all on function automation.ct_hic_scheduler_tick_v85() from public,anon,authenticated;
