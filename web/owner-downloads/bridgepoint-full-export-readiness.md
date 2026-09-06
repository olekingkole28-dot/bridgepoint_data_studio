# BridgePoint Full Export — Owner Readiness Gate

**This file is instructions only. It does not start an export.**

Final export remains locked until all of these are true:

1. The owner explicitly marks the BridgePoint build ready for final export.
2. Parcel canonicalization/dedupe truth is at the agreed final checkpoint.
3. The three fragmented lanes have been reconciled: vertical legal units, legal public/unincorporated/tribal land identities, and subdivision ghosts (ghosts remain PRE_CANONICAL until a legal parcel ID exists).
4. Nationwide source/legal provenance has been captured for the final source manifest.
5. The local computer has been checked with `bridgepoint-storage-check.ps1` and enough free space exists for the chosen export format plus safety margin.
6. Node has been upgraded to the current supported release selected by the owner and `node --version` has been rechecked in a fresh terminal.
7. A destination drive/path has been chosen and is writable.
8. Nearmap remains excluded unless a later signed/authorized agreement specifically allows data to be included.
9. The owner has reviewed what is included: canonical properties, geometry/provenance, claims-lifecycle intelligence, source manifests, 3D/building manifests, audit/health state, code/technical archive, and later final documentation/PDFs.
10. Only then use the final BridgePoint export launcher. Do not trigger the export from this instruction file.

## Before export

Download and run the two safe owner helpers first:

- `bridgepoint-storage-check.ps1` — read-only disk/Node check.
- `bridgepoint-local-node-readiness.ps1` — Node/export sequencing instructions.

## Export architecture rule

The future final export launcher should be resumable, checksum every chunk, preserve source provenance, never overwrite the only copy, and produce a manifest that can be verified after transfer. Large state/property tables should be exported in independent chunks so one failure does not invalidate the whole export.

## Nearmap rule

No Nearmap API or bulk-access interface is enabled by this workflow. If a later deal is agreed, BridgePoint should expose only specifically permitted fields/products through a separately authenticated, rate-limited, auditable interface rather than allowing unrestricted scanning of the underlying database.
