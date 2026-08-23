# BridgePoint Property Trust and State V549

## Purpose

V549 extends the Autonomous Data Machine with a defensive network/edge trust layer, a deterministic property-state engine, and a zero-knowledge-ready property oracle commitment layer.

The design is deliberately defensive. BridgePoint does not perform BGP hijacking, unauthorized route manipulation, covert firmware interception, packet-payload capture, security bypass, or unsanctioned machine access.

## Trust pipeline

1. **Authorized network topology observations** — summarized eBPF, netlink, operating-system route or signed agent telemetry from BridgePoint-owned or explicitly authorized hosts. Packet payload capture is hard-disabled.
2. **BGP/RPKI route integrity** — passive route observations store prefix, origin ASN, AS path summary, RPKI status and validated anomaly class. External route telemetry is not yet connected.
3. **Edge firmware attestation** — device firmware digest, secure-boot state and TPM/TEE/vendor-signature evidence can be recorded. Firmware writes and autonomous image application are hard-disabled.
4. **Signed firmware manifests** — expected firmware digests/signatures can be registered for authorized verification. This is verification, not interception.
5. **Storage abstraction** — conventional object storage and authorized edge buffers are operational abstractions; ambient/environmental storage is research-only; biological storage is design-only. No wet-lab execution exists.
6. **Deterministic property events** — only VERIFIED events with rights status VERIFIED_PUBLIC or PERMITTED can set deterministic_eligible=true.
7. **Deterministic snapshots** — eligible events are ordered deterministically, latest values are reduced by event type, and snapshots are SHA-256 hash chained under ruleset DPS-1.0. Re-materialization with an unchanged event set is a no-op and returns the same snapshot/hash.
8. **ZKP-POL commitments** — commitments bind a statement and public inputs to the current deterministic property state hash. `proof_system=UNCONFIGURED`; commitment hashes are explicitly not zero-knowledge proofs. A real proving/verifier stack is a future validation gate.
9. **Trust control** — `bridgepoint_ai.trust_control_tick_v549()` runs hourly at minute 44 and reports real counts plus approval/block queues.

## Core database objects

- `bridgepoint_ai.network_route_observations_v549`
- `bridgepoint_ai.network_topology_observations_v549`
- `bridgepoint_ai.edge_device_attestations_v549`
- `bridgepoint_ai.edge_firmware_manifests_v549`
- `bridgepoint_ai.storage_media_registry_v549`
- `bridgepoint_ai.property_state_events_v549`
- `bridgepoint_ai.property_state_snapshots_v549`
- `bridgepoint_ai.zkp_property_oracle_commitments_v549`
- `bridgepoint_ai.trust_layer_state_v549`
- `bridgepoint_ai.trust_action_queue_v549`
- `bridgepoint_ai.record_property_state_event_v549(...)`
- `bridgepoint_ai.materialize_property_state_v549(uuid)`
- `bridgepoint_ai.create_zkp_commitment_v549(...)`
- `bridgepoint_ai.trust_control_tick_v549()`
- `public.bridgepoint_owner_property_trust_v549()`

## Deterministic semantics

`DPS-1.0` currently uses PostgreSQL `jsonb::text` canonicalization labeled `PG_JSONB_TEXT_V1`. That representation is versioned and reproducible inside this engine, but is not represented as a universal cross-language canonical JSON standard. Before external cryptographic proof interoperability, BridgePoint should adopt and validate a language-independent canonical encoding, such as a reviewed JCS/RFC 8785 implementation or a purpose-built deterministic binary encoding.

A deterministic snapshot does not mean every source fact is physically true. It means BridgePoint will produce the same state from the same admitted event ledger under the same ruleset. Source verification and rights gates remain upstream requirements.

## Current production truth at activation

At the first V549 live control tick:
- route observations: 0
- validated route anomalies: 0
- validated kernel/topology observations: 0
- verified edge attestations: 0
- deterministic production events: 0
- deterministic production snapshots: 0
- ZKP-POL commitments: 0
- verified zero-knowledge proofs: 0

The control plane being GREEN means the V549 governor is healthy. It does not imply external feeds or proof systems are already connected.

## Hard blocked actions

- active BGP hijacking or unauthorized route changes
- covert network interception or packet-payload collection
- unauthorized kernel hooks
- covert firmware interception/modification
- autonomous firmware writes
- bypassing authentication or device/network controls
- autonomous biological/wet-lab operations
- presenting a hash commitment as a verified zero-knowledge proof

## Owner visibility

The owner-only Property Trust Engine is surfaced at `/owner/distribution/trust/`. It reads the authenticated owner RPC and displays control health, feed counts, capability truth, storage-medium policy, trust action queue, and recent defensive network observations.
