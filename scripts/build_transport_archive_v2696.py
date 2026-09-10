#!/usr/bin/env python3
import argparse
import datetime as dt
import hashlib
import json
import os
import pathlib
import sys

import duckdb
import requests

SUPABASE_URL = os.environ["SUPABASE_URL"].rstrip("/")
SUPABASE_KEY = os.environ["SUPABASE_KEY"]
BROKER_TOKEN = os.environ["TRANSPORT_ARCHIVE_BROKER_TOKEN"]
BROKER_URL = f"{SUPABASE_URL}/functions/v1/bridgepoint-transport-archive-broker-v2696"
CATALOG_URL = f"{SUPABASE_URL}/rest/v1/rpc/bridgepoint_public_transport_archive_catalog_v2696"


def post_json(url, payload, headers=None, timeout=120):
    h = {"content-type": "application/json"}
    if headers:
        h.update(headers)
    r = requests.post(url, headers=h, json=payload, timeout=timeout)
    if not r.ok:
        raise RuntimeError(f"POST {url} -> {r.status_code}: {r.text[:1500]}")
    return r.json()


def catalog(state, kind):
    return post_json(
        CATALOG_URL,
        {"p_state_code": state, "p_asset_kind": kind},
        {"apikey": SUPABASE_KEY, "authorization": f"Bearer {SUPABASE_KEY}"},
    )


def sql_string(value):
    return "'" + value.replace("'", "''") + "'"


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

    query = f"""
    COPY (
      WITH candidate AS (
        SELECT *, ST_GeomFromWKB(geometry) AS _bp_geom
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
    """
    con.execute(query)

    row = con.execute(
        f"""
        WITH a AS (
          SELECT *, ST_GeomFromWKB(geometry) AS g
          FROM read_parquet({output_sql})
        ), b AS (SELECT geom FROM bp_boundary)
        SELECT count(*)::BIGINT AS rows,
               count(*) FILTER (WHERE geometry IS NULL)::BIGINT AS null_geometry,
               count(*) FILTER (WHERE geometry IS NOT NULL AND ST_IsEmpty(g))::BIGINT AS empty_geometry,
               count(*) FILTER (WHERE geometry IS NOT NULL AND NOT ST_IsEmpty(g)
                  AND NOT ST_IsEmpty(ST_Difference(g, b.geom)))::BIGINT AS outside_geometry,
               (count(*) - count(DISTINCT id))::BIGINT AS duplicate_ids
        FROM a CROSS JOIN b
        """
    ).fetchone()
    validation = {
        "null_geometry": int(row[1]),
        "empty_geometry": int(row[2]),
        "outside_geometry": int(row[3]),
        "duplicate_ids": int(row[4]),
    }
    rows = int(row[0])
    if any(validation.values()):
        raise RuntimeError(f"Archive validation failed {state}/{kind}: {validation}")
    con.close()
    return rows, validation, len(urls)


def upload_and_finalize(state, kind, path, rows, validation, source_files):
    data = path.read_bytes()
    file_bytes = len(data)
    digest = hashlib.sha256(data).hexdigest()
    sign = post_json(BROKER_URL, {
        "action": "sign",
        "broker_token": BROKER_TOKEN,
        "state_code": state,
        "asset_kind": kind,
    })
    signed_url = sign["signed_url"]
    put = requests.put(
        signed_url,
        data=data,
        headers={"content-type": "application/vnd.apache.parquet", "x-upsert": "true"},
        timeout=1800,
    )
    if not put.ok:
        raise RuntimeError(f"Signed upload failed {put.status_code}: {put.text[:1500]}")
    generated_at = dt.datetime.now(dt.timezone.utc).isoformat()
    fin = post_json(BROKER_URL, {
        "action": "finalize",
        "broker_token": BROKER_TOKEN,
        "state_code": state,
        "asset_kind": kind,
        "row_count": rows,
        "file_bytes": file_bytes,
        "sha256": digest,
        "validation": validation,
        "metadata": {
            "generated_at": generated_at,
            "source_files": source_files,
            "builder": "GITHUB_DUCKDB_EXACT_CLIP_V2696",
            "compression": "ZSTD",
        },
    }, timeout=180)
    print(json.dumps({
        "state": state, "kind": kind, "rows": rows, "bytes": file_bytes,
        "sha256": digest, "validation": validation, "finalize": fin,
    }, separators=(",", ":")))


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--state", required=True)
    p.add_argument("--kind", required=True, choices=["segment", "connector"])
    p.add_argument("--out-dir", default="transport-output")
    args = p.parse_args()
    state = args.state.upper()
    out_dir = pathlib.Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    out_path = out_dir / f"{state}-{args.kind}.parquet"
    rows, validation, source_files = build(state, args.kind, out_path)
    upload_and_finalize(state, args.kind, out_path, rows, validation, source_files)


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        raise
