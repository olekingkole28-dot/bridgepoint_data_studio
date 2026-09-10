#!/usr/bin/env python3
"""
Build BridgePoint's portable local DuckDB catalog over already-materialized Parquet shards.

This DOES NOT copy national geometry into DuckDB. Parquet/ZSTD remains the durable
storage layer. DuckDB stores the compact file catalog and lets BridgePoint query
only the files/columns needed for a state/layer/property request.

Expected bundle layout:
  <bundle_root>/
    parquet/
      buildings/v2710/<STATE>/<building|building_part>/part-*.parquet
    manifest/
      world-parquet-manifest.json
    bridgepoint-world.duckdb

The manifest must be an array of records from
automation.world_parquet_export_manifest_v2733.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
from typing import Iterable

import duckdb

CATALOG_VERSION = 2733
REQUIRED_KEYS = {
    "component", "state_code", "asset_kind", "part_index", "object_path",
    "row_count", "file_bytes", "sha256"
}


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser()
    p.add_argument("--bundle-root", required=True)
    p.add_argument("--manifest-json", required=True)
    p.add_argument("--db", default="bridgepoint-world.duckdb")
    p.add_argument("--verify-hashes", action="store_true")
    return p.parse_args()


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for block in iter(lambda: f.read(8 * 1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def load_manifest(path: Path) -> list[dict]:
    data = json.loads(path.read_text(encoding="utf-8"))
    if isinstance(data, dict) and "files" in data:
        data = data["files"]
    if not isinstance(data, list):
        raise SystemExit("Manifest must be a JSON array or {files:[...]}.")
    out = []
    seen = set()
    for i, row in enumerate(data):
        if not isinstance(row, dict):
            raise SystemExit(f"Manifest row {i} is not an object.")
        missing = REQUIRED_KEYS - row.keys()
        if missing:
            raise SystemExit(f"Manifest row {i} missing keys: {sorted(missing)}")
        key = (row["component"], row["state_code"], row["asset_kind"], int(row["part_index"]))
        if key in seen:
            raise SystemExit(f"Duplicate manifest key: {key}")
        seen.add(key)
        out.append(row)
    return out


def local_relpath(object_path: str) -> str:
    # Storage object: buildings/v2710/TX/building/part-00000.parquet
    # Local bundle:   parquet/buildings/v2710/TX/building/part-00000.parquet
    clean = object_path.lstrip("/")
    if ".." in Path(clean).parts:
        raise SystemExit(f"Unsafe object path: {object_path}")
    return str(Path("parquet") / clean).replace("\\", "/")


def verify_files(root: Path, rows: Iterable[dict], verify_hashes: bool) -> None:
    errors = []
    for r in rows:
        rel = local_relpath(str(r["object_path"]))
        p = root / rel
        if not p.is_file():
            errors.append(f"MISSING {rel}")
            continue
        expected_size = int(r["file_bytes"])
        actual_size = p.stat().st_size
        if actual_size != expected_size:
            errors.append(f"SIZE {rel} expected={expected_size} actual={actual_size}")
            continue
        if verify_hashes:
            actual_sha = sha256_file(p)
            if actual_sha.lower() != str(r["sha256"]).lower():
                errors.append(f"SHA256 {rel}")
    if errors:
        sample = "\n".join(errors[:50])
        raise SystemExit(f"Bundle verification failed ({len(errors)} errors):\n{sample}")


def main() -> None:
    a = parse_args()
    root = Path(a.bundle_root).resolve()
    manifest_path = Path(a.manifest_json).resolve()
    rows = load_manifest(manifest_path)

    # If files already exist, verify size immediately. Full SHA verification is
    # optional because it scans every byte and is intentionally a final-export gate.
    verify_files(root, rows, a.verify_hashes)

    db_path = root / a.db
    db_path.parent.mkdir(parents=True, exist_ok=True)
    con = duckdb.connect(str(db_path))
    try:
        con.execute("PRAGMA threads=4")
        con.execute("PRAGMA enable_object_cache=true")
        con.execute("""
          create table if not exists bridgepoint_catalog_meta(
            key varchar primary key,
            value varchar not null
          )
        """)
        con.execute("""
          create table if not exists world_files(
            component varchar not null,
            state_code varchar not null,
            asset_kind varchar not null,
            part_index integer not null,
            relative_path varchar not null,
            row_count ubigint not null,
            file_bytes ubigint not null,
            sha256 varchar not null,
            source_release varchar,
            source_key varchar,
            source_license varchar,
            verified_at timestamptz,
            validation_json json,
            metadata_json json,
            primary key(component,state_code,asset_kind,part_index)
          )
        """)
        con.execute("delete from world_files")

        payload = []
        for r in rows:
            payload.append((
                str(r["component"]), str(r["state_code"]), str(r["asset_kind"]),
                int(r["part_index"]), local_relpath(str(r["object_path"])),
                int(r["row_count"]), int(r["file_bytes"]), str(r["sha256"]).lower(),
                r.get("source_release"), r.get("source_key"), r.get("source_license"),
                r.get("verified_at"), json.dumps(r.get("validation") or {}),
                json.dumps(r.get("metadata") or {})
            ))
        con.executemany("""
          insert into world_files values (?,?,?,?,?,?,?,?,?,?,?,?,?,?)
        """, payload)

        con.execute("create index if not exists world_files_state_kind on world_files(state_code,asset_kind,part_index)")
        con.execute("create index if not exists world_files_component on world_files(component)")
        con.execute("""
          create or replace view world_storage_summary as
          select component,asset_kind,
                 count(distinct state_code) jurisdictions,
                 count(*) files,
                 sum(row_count) rows,
                 sum(file_bytes) bytes,
                 round(sum(file_bytes)::double/1073741824,2) gib
          from world_files
          group by component,asset_kind
        """)
        con.execute("""
          insert or replace into bridgepoint_catalog_meta values
          ('catalog_version', ?),
          ('storage_model', 'PARQUET_ZSTD_DURABLE_PLUS_DUCKDB_CATALOG'),
          ('truth_rule', 'Never inflate the national archive into DuckDB merely to query it; select manifest files first, then read_parquet only those paths.')
        """, [str(CATALOG_VERSION)])

        # Materialize compact file lists by state/kind. The application can fetch
        # these paths and pass them directly to DuckDB read_parquet([...]).
        con.execute("""
          create or replace view building_files as
          select * from world_files
          where component='BUILDINGS_V2710' and asset_kind='building'
        """)
        con.execute("""
          create or replace view building_part_files as
          select * from world_files
          where component='BUILDINGS_V2710' and asset_kind='building_part'
        """)

        # Validate catalog reconciliation without scanning geometry.
        manifest_rows = sum(int(r["row_count"]) for r in rows)
        manifest_bytes = sum(int(r["file_bytes"]) for r in rows)
        db_rows, db_bytes, file_count = con.execute(
            "select coalesce(sum(row_count),0),coalesce(sum(file_bytes),0),count(*) from world_files"
        ).fetchone()
        if int(db_rows) != manifest_rows or int(db_bytes) != manifest_bytes or int(file_count) != len(rows):
            raise SystemExit("DuckDB catalog reconciliation failed.")

        print(json.dumps({
            "complete": True,
            "catalog_version": CATALOG_VERSION,
            "database": str(db_path),
            "files": len(rows),
            "rows": manifest_rows,
            "bytes": manifest_bytes,
            "gib": round(manifest_bytes / 1073741824, 2),
            "hashes_verified": bool(a.verify_hashes),
            "storage_model": "PARQUET_ZSTD_DURABLE_PLUS_DUCKDB_CATALOG"
        }, separators=(",", ":")))
    finally:
        con.close()


if __name__ == "__main__":
    main()
