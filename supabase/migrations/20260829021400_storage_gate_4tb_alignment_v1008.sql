-- BridgePoint V1008
-- Align the stale expansion runtime disk throttle to the existing authoritative
-- 4096 GB capacity plan. Preserve 800+ GB reserve and all non-storage safety gates.
update automation.expansion_load_policy_v321
set db_soft_limit_gb = 2800,
    db_hard_limit_gb = 3200,
    metadata = coalesce(metadata,'{}'::jsonb) || jsonb_build_object(
      'runtime_disk_gate_version',1008,
      'runtime_disk_gate_updated_at',now(),
      'runtime_disk_gate_reason','Aligned stale 350/380GB expansion throttle to authoritative 4096GB BridgePoint capacity plan with 2800GB warning and 3200GB hard stop',
      'planned_final_disk_gb',4096,
      'planned_final_warning_gb',2800,
      'planned_final_hard_stop_gb',3200,
      'owner_storage_unthrottle_v1008',true
    ),
    updated_at=now()
where singleton=true;
