#!/usr/bin/env python3
import argparse
import datetime as dt
import hashlib
import json
import math
import os
import pathlib
import sys
import time

import duckdb
import requests

SUPABASE_URL = os.environ["SUPABASE_URL"].rstrip("/")
SUPABASE_KEY = os.environ["SUPABASE_KEY"]
BROKER_URL = f"{SUPABASE_URL}/functions/v1/bridgepoint-transport-archive-broker-v2696"
CATALOG_URL = f"{SUPABASE_URL}/rest/v1/rpc/bridgepoint_public_transport_archive_catalog_v2696"
ITEM_STATUS_URL = f"{SUPABASE_URL}/rest/v1/rpc/bridgepoint_public_transport_archive_item_v2703"
OIDC_AUDIENCE = "bridgepoint-transport-v2696"
BOUNDARY_VALIDATION_TOLERANCE_DEGREES = 1e-7
PART_TARGET_BYTES = 28 * 1024 * 1024
PART_HARD_MAX_BYTES = 42 * 1024 * 1024


def post_json(url, payload, headers=None, timeout=120):
    h = {"content-type": "application/json"}
    if headers:
        h.update(headers)
    r = requests.post(url, headers=h, json=payload, timeout=timeout)
    if not r.ok:
        raise RuntimeError(f"POST {url} -> {r.status_code}: {r.text[:1500]}")
    return r.json()


def fresh_oidc_token():
    request_url = os.environ.get("ACTIONS_ID_TOKEN_REQUEST_URL", "")
    request_token = os.environ.get("ACTIONS_ID_TOKEN_REQUEST_TOKEN", "")
    if not request_url or not request_token:
        raise RuntimeError("GitHub renewable OIDC request endpoint is unavailable")
    sep = "&" if "?" in request_url else "?"
    r = requests.get(
        f"{request_url}{sep}audience={OIDC_AUDIENCE}",
        headers={"Authorization": f"bearer {request_token}"},
        timeout=30,
    )
    if not r.ok:
        raise RuntimeError(f"GitHub OIDC refresh failed {r.status_code}: {r.text[:500]}")
    token = r.json().get("value")
    if not token:
        raise RuntimeError("GitHub OIDC refresh returned no token")
    return token


def broker_post(action, state, kind, extra=None, timeout=120):
    body = {
        "action": action,
        "oidc_token": fresh_oidc_token(),
        "state_code": state,
        "asset_kind": kind,
    }
    if extra:
        body.update(extra)
    return post_json(BROKER_URL, body, timeout=timeout)


def public_rpc(url, payload):
    return post_json(
        url,
        payload,
        {"apikey": SUPABASE_KEY, "authorization": f"Bearer {SUPABASE_KEY}"},
    )


def item_status(state, kind):
    return public_rpc(ITEM_STATUS_URL, {"p_state_code": state, "p_asset_kind": kind})


def broker_report(state, kind, status, stage, message="", metadata=None):
    return broker_post("report", state, kind, {
        "status": status,
        "stage": stage,
        "message": message,
        "metadata": metadata or {},
    })


def catalog(state, kind):
    return public_rpc(CATALOG_URL, {"p_state_code": state, "p_asset_kind": kind})


def sql_string(value):
    return "'" + value.replace("'", "''") + "'"


def sha256_file(path):
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(8 * 1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def build(state, kind, out_path):
    cat = catalog(state, kind)
    urls = [x["url"] for x in cat.get("files", [])]
    if not urls:
        raise RuntimeError(f"No candidate Overture files for {state}/{kind}; refusing false-empty archive")
    west, south, east, north = [float(x) for x in cat["bbox"]]
    state_geojson = json.dumps(cat["state_geojson"], separators=(",", ":"))

    con = duckdb.connect(database=":memory:")
    con.execute("SET threads=4")
    con.execute("SET memory_limit='5GB'")
    con.execute("SET preserve_insertion_order=false")
    con.execute("INSTALL httpfs; LOAD httpfs")
    con.execute("INSTALL spatial; LOAD spatial")
    con.execute("CREATE TEMP TABLE bp_boundary AS SELECT ST_GeomFromGeoJSON(?) AS geom", [state_geojson])

    url_list = "[" + ",".join(sql_string(u) for u in urls) + "]"
    source = f"read_parquet({url_list}, union_by_name=true)"
    release = sql_string(str(cat["source_release"]))
    source_key = sql_string(str(cat["source_key"]))
    state_sql = sql_string(state)
    kind_sql = sql_string(kind)
    output_sql = sql_string(str(out_path))

    con.execute(f"""
    COPY (
      WITH candidate AS (
        SELECT *, geometry AS _bp_geom
        FROM {source}
        WHERE bbox.xmin <= {east} AND bbox.xmax >= {west}
          AND bbox.ymin <= {north} AND bbox.ymax >= {south}
      ), clipped AS (
        SELECT candidate.* EXCLUDE (geometry, _bp_geom),
               ST_Intersection(_bp_geom, b.geom) AS _bp_clip
        FROM candidate CROSS JOIN bp_boundary b
        WHERE ST_Intersects(_bp_geom, b.geom)
      )
      SELECT clipped.* EXCLUDE (_bp_clip),
             ST_AsWKB(_bp_clip) AS geometry,
             {state_sql}::VARCHAR AS _bp_jurisdiction,
             {kind_sql}::VARCHAR AS _bp_asset_kind,
             {release}::VARCHAR AS _bp_source_release,
             {source_key}::VARCHAR AS _bp_source_key
      FROM clipped
      WHERE NOT ST_IsEmpty(_bp_clip)
    ) TO {output_sql} (FORMAT PARQUET, COMPRESSION ZSTD, ROW_GROUP_SIZE 100000)
    """)

    row = con.execute(f"""
        WITH a AS (
          SELECT *, geometry AS g
          FROM read_parquet({output_sql})
        ), b AS (SELECT geom FROM bp_boundary), d AS (
          SELECT a.*, ST_Difference(g, b.geom) AS outside_geom
          FROM a CROSS JOIN b
        )
        SELECT count(*)::BIGINT AS rows,
               count(*) FILTER (WHERE geometry IS NULL)::BIGINT AS null_geometry,
               count(*) FILTER (WHERE geometry IS NOT NULL AND ST_IsEmpty(g))::BIGINT AS empty_geometry,
               count(*) FILTER (
                 WHERE geometry IS NOT NULL AND NOT ST_IsEmpty(g)
                   AND NOT ST_IsEmpty(outside_geom)
                   AND ST_Length(outside_geom) > {BOUNDARY_VALIDATION_TOLERANCE_DEGREES}
               )::BIGINT AS outside_geometry,
               (count(*) - count(DISTINCT id))::BIGINT AS duplicate_ids,
               count(*) FILTER (
                 WHERE geometry IS NOT NULL AND NOT ST_IsEmpty(g)
                   AND NOT ST_IsEmpty(outside_geom)
                   AND ST_Length(outside_geom) <= {BOUNDARY_VALIDATION_TOLERANCE_DEGREES}
               )::BIGINT AS precision_slivers,
               coalesce(max(ST_Length(outside_geom)) FILTER (WHERE outside_geom IS NOT NULL AND NOT ST_IsEmpty(outside_geom)),0)::DOUBLE AS max_outside_length_degrees
        FROM d
    """).fetchone()
    validation = {
        "null_geometry": int(row[1]),
        "empty_geometry": int(row[2]),
        "outside_geometry": int(row[3]),
        "duplicate_ids": int(row[4]),
        "precision_slivers": int(row[5]),
        "max_outside_length_degrees": float(row[6]),
        "boundary_validation_tolerance_degrees": BOUNDARY_VALIDATION_TOLERANCE_DEGREES,
    }
    rows = int(row[0])
    blocking = {k: validation[k] for k in ("null_geometry", "empty_geometry", "outside_geometry", "duplicate_ids")}
    if any(blocking.values()):
        raise RuntimeError(f"Archive validation failed {state}/{kind}: {validation}")
    con.close()
    return rows, validation, len(urls)


def split_archive(path, total_rows):
    base_bytes = path.stat().st_size
    part_count = max(1, math.ceil(base_bytes / PART_TARGET_BYTES))
    source_sql = sql_string(str(path))
    while True:
        for old in path.parent.glob(f"{path.stem}-part-*.parquet"):
            old.unlink()
        con = duckdb.connect(database=":memory:")
        con.execute("SET threads=4")
        con.execute("SET memory_limit='5GB'")
        con.execute("SET preserve_insertion_order=false")
        parts = []
        for i in range(part_count):
            part_path = path.parent / f"{path.stem}-part-{i:05d}.parquet"
            part_sql = sql_string(str(part_path))
            con.execute(f"""
                COPY (
                  SELECT * FROM read_parquet({source_sql})
                  WHERE hash(id) % {part_count} = {i}
                ) TO {part_sql} (FORMAT PARQUET, COMPRESSION ZSTD, ROW_GROUP_SIZE 100000)
            """)
            row = con.execute(f"SELECT count(*)::BIGINT,(count(*)-count(DISTINCT id))::BIGINT FROM read_parquet({part_sql})").fetchone()
            rows = int(row[0])
            dups = int(row[1])
            if rows <= 0 or dups != 0:
                con.close()
                raise RuntimeError(f"Invalid shard {i}: rows={rows} duplicate_ids={dups}")
            parts.append({"index": i, "path": part_path, "rows": rows, "bytes": part_path.stat().st_size})
        con.close()
        if sum(x["rows"] for x in parts) != total_rows:
            raise RuntimeError("Shard row totals do not reconcile to validated archive")
        largest = max(x["bytes"] for x in parts)
        if largest <= PART_HARD_MAX_BYTES:
            return parts, base_bytes
        part_count *= 2
        if part_count > 99999:
            raise RuntimeError("Unable to shard archive below storage hard limit")


def upload_one_part(state, kind, part, validation, source_files):
    path = part["path"]
    digest = sha256_file(path)
    sign = broker_post("sign_part", state, kind, {"part_index": part["index"]})
    signed_url = sign["signed_url"]
    last_error = None
    for attempt in range(1, 4):
        try:
            with path.open("rb") as fh:
                put = requests.put(
                    signed_url,
                    data=fh,
                    headers={"content-type": "application/vnd.apache.parquet", "x-upsert": "true", "content-length": str(part["bytes"])},
                    timeout=3600,
                )
            if put.ok:
                last_error = None
                break
            last_error = f"HTTP {put.status_code}: {put.text[:1500]}"
        except Exception as exc:
            last_error = str(exc)
        if attempt < 3:
            time.sleep(attempt * 5)
            sign = broker_post("sign_part", state, kind, {"part_index": part["index"]})
            signed_url = sign["signed_url"]
    if last_error:
        raise RuntimeError(f"Part {part['index']} upload failed after 3 attempts: {last_error}")

    generated_at = dt.datetime.now(dt.timezone.utc).isoformat()
    receipt = broker_post("finalize_part", state, kind, {
        "part_index": part["index"],
        "row_count": part["rows"],
        "file_bytes": part["bytes"],
        "sha256": digest,
        "validation": validation,
        "metadata": {
            "generated_at": generated_at,
            "source_files": source_files,
            "builder": "GITHUB_DUCKDB_EXACT_CLIP_V2705_SHARDED",
            "compression": "ZSTD",
            "logical_archive_version": 2696,
        },
    }, timeout=180)
    return {"index": part["index"], "rows": part["rows"], "bytes": part["bytes"], "sha256": digest, "receipt": receipt}


def upload_and_finalize_sharded(state, kind, path, rows, validation, source_files):
    parts, base_bytes = split_archive(path, rows)
    broker_report(state, kind, "BUILDING", "SHARDED", metadata={
        "rows": rows,
        "source_files": source_files,
        "base_file_bytes": base_bytes,
        "part_count": len(parts),
        "max_part_bytes": max(p["bytes"] for p in parts),
        "part_hard_max_bytes": PART_HARD_MAX_BYTES,
    })

    receipts = []
    for part in parts:
        receipts.append(upload_one_part(state, kind, part, validation, source_files))

    aggregate = hashlib.sha256()
    for r in receipts:
        aggregate.update(f"{r['index']}:{r['rows']}:{r['bytes']}:{r['sha256']}\n".encode("utf-8"))
    aggregate_sha = aggregate.hexdigest()
    total_bytes = sum(r["bytes"] for r in receipts)
    generated_at = dt.datetime.now(dt.timezone.utc).isoformat()
    fin = broker_post("complete_sharded", state, kind, {
        "part_count": len(receipts),
        "total_rows": rows,
        "total_bytes": total_bytes,
        "aggregate_sha256": aggregate_sha,
        "metadata": {
            "generated_at": generated_at,
            "source_files": source_files,
            "builder": "GITHUB_DUCKDB_EXACT_CLIP_V2705_SHARDED",
            "compression": "ZSTD",
            "base_file_bytes": base_bytes,
            "part_target_bytes": PART_TARGET_BYTES,
            "part_hard_max_bytes": PART_HARD_MAX_BYTES,
            "validation": validation,
        },
    }, timeout=180)
    print(json.dumps({
        "state": state,
        "kind": kind,
        "rows": rows,
        "logical_base_bytes": base_bytes,
        "stored_bytes": total_bytes,
        "part_count": len(receipts),
        "max_part_bytes": max(r["bytes"] for r in receipts),
        "aggregate_sha256": aggregate_sha,
        "validation": validation,
        "finalize": fin,
    }, separators=(",", ":")))


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--state", required=True)
    p.add_argument("--kind", required=True, choices=["segment", "connector"])
    p.add_argument("--out-dir", default="transport-output")
    args = p.parse_args()
    state = args.state.upper()
    kind = args.kind
    existing = item_status(state, kind)
    if bool(existing.get("verified")):
        print(json.dumps({"state": state, "kind": kind, "skipped": True, "reason": "ALREADY_VERIFIED", "existing": existing}, separators=(",", ":")))
        return

    broker_post("reset_parts", state, kind)
    out_dir = pathlib.Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    out_path = out_dir / f"{state}-{kind}.parquet"
    broker_report(state, kind, "BUILDING", "STARTED", metadata={"runner": "github-actions", "builder_version": 2705, "oidc_mode": "renew-per-broker-call", "archive_mode": "deterministic-sharded"})
    try:
        rows, validation, source_files = build(state, kind, out_path)
        broker_report(state, kind, "BUILDING", "VALIDATED", metadata={"rows": rows, "source_files": source_files, "validation": validation, "base_file_bytes": out_path.stat().st_size})
        upload_and_finalize_sharded(state, kind, out_path, rows, validation, source_files)
    except Exception as exc:
        try:
            broker_report(state, kind, "FAILED", "BUILD_OR_UPLOAD", str(exc))
        except Exception as report_exc:
            print(f"Secondary receipt failure: {report_exc}", file=sys.stderr)
        raise


if __name__ == "__main__":
    main()
