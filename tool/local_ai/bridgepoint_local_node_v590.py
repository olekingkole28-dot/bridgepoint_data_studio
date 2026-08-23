#!/usr/bin/env python3
"""BridgePoint Local AI V590: ledger-aware wrapper around the V584 runner."""
import importlib.util
from pathlib import Path

base = Path(__file__).with_name("bridgepoint_local_node.py")
spec = importlib.util.spec_from_file_location("bp_local_base", base)
mod = importlib.util.module_from_spec(spec)
assert spec and spec.loader
spec.loader.exec_module(mod)

mod.PRIMARY_SYSTEM = mod.PRIMARY_SYSTEM.replace(
    "For normal worker tasks return: summary, verified_facts[], assumptions[], hypotheses[], recommendation, proposed_actions[], action_kind, action_key|null, reversible, confidence, verification_tests[].",
    "For normal worker tasks return: summary, verified_facts[], assumptions[], hypotheses[], recommendation, proposed_actions[], action_kind, action_key|null, reversible, confidence, verification_tests[]. If task_type is MASTER_LEDGER_VERIFY, you MUST additionally return pass (boolean), verification_evidence[] and remaining_gaps[]. pass=true only when current production evidence proves the entire requirement, not merely that a worker attempted it."
)
mod.REVIEW_SYSTEM = mod.REVIEW_SYSTEM.replace(
    "Return JSON only with: approve, summary, concerns[], required_changes[], strongest_objections[], missing_evidence[], policy_or_security_risks[], safer_alternative, confidence, requires_owner_approval.",
    "Return JSON only with: approve, summary, concerns[], required_changes[], strongest_objections[], missing_evidence[], policy_or_security_risks[], safer_alternative, confidence, requires_owner_approval. For MASTER_LEDGER_VERIFY, independently challenge the primary pass/fail result and include pass (boolean), verification_evidence[] and remaining_gaps[]."
)

if __name__ == "__main__":
    raise SystemExit(mod.main())
