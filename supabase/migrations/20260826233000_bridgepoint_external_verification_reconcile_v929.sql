-- BridgePoint Intelligence V929
-- Narrow ledger promotion path for current-release external browser evidence.
-- This function may only promote the two release/viewport QA requirements.

begin;

create or replace function automation.reconcile_external_verification_requirements_v929()
returns jsonb
language plpgsql
security definer
set search_path to 'pg_catalog','automation','bridgepoint_ai'
set statement_timeout to '8s'
as $$
declare
  e automation.external_verification_evidence_v925%rowtype;
  v_checks jsonb;
  v_valid boolean:=false;
  v_promoted int:=0;
  v_req text;
begin
  select * into e
  from automation.external_verification_evidence_v925
  where verification_key='CURRENT_LIVE_V925';

  if found then
    v_checks:=coalesce(e.evidence->'checks','{}'::jsonb);
    v_valid:=
      e.status='VERIFIED'
      and e.verifier_version>=926
      and coalesce(e.release_version,0)>=922
      and e.verified_at>=now()-interval '7 days'
      and e.trigger_sha ~ '^[0-9a-f]{40}$'
      and e.source_url='https://raw.githubusercontent.com/olekingkole28-dot/bridgepoint-live/main/live-verification-status-v926.json'
      and coalesce((v_checks->>'current_release_contract')::boolean,false)
      and coalesce((v_checks->>'custom_domain_https_200')::boolean,false)
      and coalesce((v_checks->>'public_secret_boundary_checked')::boolean,false)
      and coalesce((v_checks->>'phone_390x844_home_app_twin_passed')::boolean,false)
      and coalesce((v_checks->>'tablet_768x1024_home_app_twin_passed')::boolean,false)
      and coalesce((v_checks->>'desktop_1440x900_home_app_twin_passed')::boolean,false)
      and coalesce((v_checks->>'flutter_runtime_mounted_all_viewports')::boolean,false)
      and coalesce((v_checks->>'property_twin_auth_shell_all_viewports')::boolean,false)
      and coalesce((v_checks->>'horizontal_overflow_guard_all_viewports')::boolean,false);
  end if;

  if not v_valid then
    return jsonb_build_object(
      'complete',true,'version',929,'promoted',0,
      'blocker','NO_VALID_FRESH_EXTERNAL_BROWSER_EVIDENCE');
  end if;

  foreach v_req in array array['RELEASE_PUBLIC_POSTDEPLOY_VERIFY','APP_AUTOMATED_RESPONSIVE_QA_V734'] loop
    update bridgepoint_ai.master_completion_ledger_v586
    set status='PROVEN_DONE',
        verification=coalesce(verification,'{}'::jsonb)||jsonb_build_object(
          'verified_done_at',now(),
          'external_verification_reconciler_version',929,
          'external_verification_key',e.verification_key,
          'external_verifier_version',e.verifier_version,
          'external_release_version',e.release_version,
          'external_trigger_sha',e.trigger_sha,
          'external_verified_at',e.verified_at,
          'external_ingested_at',e.ingested_at,
          'external_source_url',e.source_url,
          'external_checks',v_checks,
          'awaiting_independent_verification',false,
          'truth_rule','PROVEN_DONE is permitted here only because the production browser verifier ran outside database cron, matched a successful GitHub Actions run by exact commit SHA, and the evidence passed all required phone/tablet/desktop runtime checks.'
        ),
        updated_at=now()
    where req_key=v_req
      and status<>'PROVEN_DONE';
    if found then v_promoted:=v_promoted+1; end if;
  end loop;

  return jsonb_build_object(
    'complete',true,'version',929,'promoted',v_promoted,
    'verification_key',e.verification_key,
    'verifier_version',e.verifier_version,
    'release_version',e.release_version,
    'trigger_sha',e.trigger_sha,
    'verified_at',e.verified_at);
end
$$;

commit;
