#!/usr/bin/env python3
"""
BridgePoint Portable World Catalog V5200

Builds a lean DuckDB catalog over sharded Parquet/ZSTD files for the full
BridgePoint Intelligence portable bundle. Parquet remains the durable bulk
store. DuckDB stores only file metadata, coverage/readiness state and compact
query indexes; it never inflates the national archive into a second copy.

Expected bundle:
  <root>/
    parquet/<component>/<version>/<jurisdiction>/<asset_kind>/part-*.parquet
    manifest/world-parquet-manifest.json
    manifest/coverage-gate.json           (optional until final gate)
    bridgepoint-world.duckdb

Manifest rows use the existing BridgePoint world-parquet contract:
  component,state_code,asset_kind,part_index,object_path,row_count,file_bytes,
  sha256,source_release,source_key,source_license,verified_at,validation,metadata
"""
from __future__ import annotations

import argparse, hashlib, json
from pathlib import Path
from typing import Iterable
import duckdb

VERSION=5200
REQUIRED={"component","state_code","asset_kind","part_index","object_path","row_count","file_bytes","sha256"}

def args():
    p=argparse.ArgumentParser()
    p.add_argument("--bundle-root",required=True)
    p.add_argument("--manifest-json",required=True)
    p.add_argument("--coverage-json")
    p.add_argument("--db",default="bridgepoint-world.duckdb")
    p.add_argument("--verify-hashes",action="store_true")
    p.add_argument("--require-export-ready",action="store_true")
    p.add_argument("--threads",type=int,default=4)
    return p.parse_args()

def sha256_file(path:Path)->str:
    h=hashlib.sha256()
    with path.open("rb") as f:
        for b in iter(lambda:f.read(8*1024*1024),b""): h.update(b)
    return h.hexdigest()

def load_json(path:Path):
    return json.loads(path.read_text(encoding="utf-8"))

def load_manifest(path:Path)->list[dict]:
    data=load_json(path)
    if isinstance(data,dict) and "files" in data:data=data["files"]
    if not isinstance(data,list):raise SystemExit("Manifest must be an array or {files:[...]}.")
    out=[];seen=set()
    for i,row in enumerate(data):
        if not isinstance(row,dict):raise SystemExit(f"Manifest row {i} is not an object.")
        missing=REQUIRED-set(row)
        if missing:raise SystemExit(f"Manifest row {i} missing {sorted(missing)}")
        key=(str(row["component"]),str(row["state_code"]),str(row["asset_kind"]),int(row["part_index"]))
        if key in seen:raise SystemExit(f"Duplicate manifest key {key}")
        seen.add(key);out.append(row)
    return out

def relpath(object_path:str)->str:
    clean=object_path.lstrip("/")
    p=Path(clean)
    if ".." in p.parts:raise SystemExit(f"Unsafe object path {object_path}")
    return str(Path("parquet")/p).replace("\\","/")

def verify(root:Path,rows:Iterable[dict],hashes:bool):
    errors=[]
    for r in rows:
        rp=relpath(str(r["object_path"]));p=root/rp
        if not p.is_file():errors.append(f"MISSING {rp}");continue
        if p.stat().st_size!=int(r["file_bytes"]):errors.append(f"SIZE {rp}");continue
        if hashes and sha256_file(p).lower()!=str(r["sha256"]).lower():errors.append(f"SHA256 {rp}")
    if errors:raise SystemExit("Bundle verification failed (%d):\n%s"%(len(errors),"\n".join(errors[:80])))

def truthy_ready(gate:dict)->bool:
    if not gate:return False
    for k in ("export_ready","strict_ready","complete"):
        if k in gate:return bool(gate[k])
    return False

def main():
    a=args();root=Path(a.bundle_root).resolve();manifest=Path(a.manifest_json).resolve()
    rows=load_manifest(manifest)
    gate=load_json(Path(a.coverage_json).resolve()) if a.coverage_json else {}
    if a.require_export_ready and not truthy_ready(gate):
        raise SystemExit("Coverage gate is not export-ready.")
    verify(root,rows,a.verify_hashes)
    db=root/a.db;db.parent.mkdir(parents=True,exist_ok=True)
    con=duckdb.connect(str(db))
    try:
        con.execute(f"PRAGMA threads={max(1,min(a.threads,16))}")
        con.execute("PRAGMA enable_object_cache=true")
        con.execute("""create table if not exists bridgepoint_catalog_meta(
          key varchar primary key,value varchar not null)""")
        con.execute("""create table if not exists world_files(
          component varchar not null,
          jurisdiction_code varchar not null,
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
          primary key(component,jurisdiction_code,asset_kind,part_index)
        )""")
        con.execute("""create table if not exists coverage_gate(
          gate_json json not null,loaded_at timestamptz default current_timestamp)""")
        con.execute("delete from world_files")
        con.execute("delete from coverage_gate")
        payload=[]
        for r in rows:
            payload.append((
              str(r["component"]),str(r["state_code"]).upper(),str(r["asset_kind"]),int(r["part_index"]),
              relpath(str(r["object_path"])),int(r["row_count"]),int(r["file_bytes"]),str(r["sha256"]).lower(),
              r.get("source_release"),r.get("source_key"),r.get("source_license"),r.get("verified_at"),
              json.dumps(r.get("validation") or {}),json.dumps(r.get("metadata") or {})
            ))
        con.executemany("insert into world_files values (?,?,?,?,?,?,?,?,?,?,?,?,?,?)",payload)
        con.execute("insert into coverage_gate(gate_json) values (?)",[json.dumps(gate or {"export_ready":False,"status":"NOT_SUPPLIED"})])
        con.execute("create index if not exists world_files_jurisdiction on world_files(jurisdiction_code,component,asset_kind,part_index)")
        con.execute("create index if not exists world_files_component on world_files(component,asset_kind)")
        con.execute("""create or replace view component_summary as
          select component,asset_kind,count(distinct jurisdiction_code) jurisdictions,
                 count(*) files,sum(row_count) rows,sum(file_bytes) bytes,
                 round(sum(file_bytes)::double/1073741824,3) gib
          from world_files group by component,asset_kind order by component,asset_kind""")
        con.execute("""create or replace view jurisdiction_summary as
          select jurisdiction_code,count(distinct component) components,count(distinct asset_kind) asset_kinds,
                 count(*) files,sum(row_count) rows,sum(file_bytes) bytes,
                 round(sum(file_bytes)::double/1073741824,3) gib
          from world_files group by jurisdiction_code order by jurisdiction_code""")
        con.execute("""create or replace view provenance_summary as
          select component,source_key,source_release,source_license,
                 count(*) files,count(distinct jurisdiction_code) jurisdictions,
                 sum(row_count) rows
          from world_files group by component,source_key,source_release,source_license
          order by component,source_key""")
        con.execute("""create or replace view portable_layers as
          select *,
            case
              when lower(asset_kind) similar to '%(parcel|boundary)%' then 'PARCEL'
              when lower(asset_kind) like '%address%' then 'ADDRESS'
              when lower(asset_kind) like '%building%' then 'BUILDING'
              when lower(asset_kind) like '%roof%' then 'ROOF'
              when lower(asset_kind) similar to '%(road|transport|rail)%' then 'TRANSPORT'
              when lower(asset_kind) similar to '%(terrain|elevation|dem)%' then 'TERRAIN'
              when lower(asset_kind) similar to '%(surface|landcover)%' then 'SURFACE'
              else 'OTHER'
            end layer_family
          from world_files""")
        con.execute("""create or replace view portable_layer_summary as
          select layer_family,count(distinct jurisdiction_code) jurisdictions,
                 count(distinct component) components,count(*) files,
                 sum(row_count) rows,sum(file_bytes) bytes
          from portable_layers group by layer_family order by layer_family""")
        con.execute("""create or replace view export_readiness as
          select
            coalesce(try_cast(json_extract_string(gate_json,'$.export_ready') as boolean),false) export_ready,
            json_extract_string(gate_json,'$.status') status,
            json_extract_string(gate_json,'$.generated_at') generated_at,
            gate_json
          from coverage_gate order by loaded_at desc limit 1""")
        con.execute("delete from bridgepoint_catalog_meta")
        con.executemany("insert into bridgepoint_catalog_meta values (?,?)",[
          ("catalog_version",str(VERSION)),
          ("storage_model","PARQUET_ZSTD_DURABLE_PLUS_DUCKDB_CATALOG"),
          ("geometry_rule","Keep WKB/GeoParquet in shards; do not duplicate national geometry inside DuckDB."),
          ("query_rule","Filter world_files/portable_layers by jurisdiction+component+asset_kind, then read_parquet only matching relative_path values."),
          ("bootstrap_status","READY_FOR_FINAL_MANIFEST" if truthy_ready(gate) else "PREPARED_WHILE_INGESTION_CONTINUES")
        ])
        manifest_rows=sum(int(r["row_count"]) for r in rows);manifest_bytes=sum(int(r["file_bytes"]) for r in rows)
        db_rows,db_bytes,files=con.execute("select coalesce(sum(row_count),0),coalesce(sum(file_bytes),0),count(*) from world_files").fetchone()
        if int(db_rows)!=manifest_rows or int(db_bytes)!=manifest_bytes or int(files)!=len(rows):
            raise SystemExit("DuckDB catalog reconciliation failed.")
        print(json.dumps({
          "complete":True,"version":VERSION,"database":str(db),"files":len(rows),
          "rows":manifest_rows,"bytes":manifest_bytes,"gib":round(manifest_bytes/1073741824,2),
          "jurisdictions":con.execute("select count(distinct jurisdiction_code) from world_files").fetchone()[0],
          "components":con.execute("select count(distinct component) from world_files").fetchone()[0],
          "hashes_verified":bool(a.verify_hashes),"export_ready":truthy_ready(gate),
          "storage_model":"PARQUET_ZSTD_DURABLE_PLUS_DUCKDB_CATALOG"
        },separators=(",",":")))
    finally:con.close()
if __name__=="__main__":main()
