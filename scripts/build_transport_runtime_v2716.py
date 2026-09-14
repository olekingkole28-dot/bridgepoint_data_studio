#!/usr/bin/env python3
import argparse
import datetime as dt
import hashlib
import json
import os
import pathlib
import subprocess
import sys

import duckdb
import requests

SUPABASE_URL=os.environ["SUPABASE_URL"].rstrip("/")
OIDC=os.environ["TRANSPORT_RUNTIME_OIDC_TOKEN"]
BROKER=f"{SUPABASE_URL}/functions/v1/bridgepoint-transport-runtime-broker-v2716"
TIPPECANOE_SHA=os.environ.get("TIPPECANOE_SHA","4f2621186acfec33b63ddf636f665623c0fef2dd")

def post(payload,timeout=180):
    r=requests.post(BROKER,json={**payload,"oidc_token":OIDC},headers={"content-type":"application/json"},timeout=timeout)
    if not r.ok:
        raise RuntimeError(f"broker {payload.get('action')} -> {r.status_code}: {r.text[:1600]}")
    j=r.json()
    if j.get("complete") is False:
        raise RuntimeError(f"broker {payload.get('action')}: {j}")
    return j

def sha256_file(path):
    h=hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda:f.read(8*1024*1024),b""):
            h.update(chunk)
    return h.hexdigest()

def download_sources(state,out_dir):
    listing=post({"action":"list_sources","state_code":state})
    objects=listing["objects"]
    local={"segment":[],"connector":[]}
    for i,obj in enumerate(objects):
        kind=obj["asset_kind"]
        signed=post({"action":"sign_download","state_code":state,"object_path":obj["object_path"]})
        suffix=pathlib.Path(obj["object_path"]).name or f"part-{i:05d}.parquet"
        path=out_dir/f"{kind}-{i:05d}-{suffix}"
        with requests.get(signed["url"],stream=True,timeout=900) as r:
            r.raise_for_status()
            with path.open("wb") as f:
                for chunk in r.iter_content(8*1024*1024):
                    if chunk:f.write(chunk)
        got_size=path.stat().st_size
        got_sha=sha256_file(path)
        if got_size!=int(obj["file_bytes"]):
            raise RuntimeError(f"size mismatch {obj['object_path']}: {got_size}!={obj['file_bytes']}")
        if got_sha.lower()!=str(obj["sha256"]).lower():
            raise RuntimeError(f"sha256 mismatch {obj['object_path']}")
        local[kind].append(path)
        print(json.dumps({"verified_source":obj["object_path"],"kind":kind,"bytes":got_size,"sha256":got_sha}))
    for kind in ("segment","connector"):
        if not local[kind]:
            raise RuntimeError(f"missing verified {kind} source")
    return listing,local

def sql_list(paths):
    return "["+",".join("'" + str(p).replace("'","''") + "'" for p in paths)+"]"

def write_geojsonseq(con,paths,kind,out_path):
    src=sql_list(paths)
    cols={r[0] for r in con.execute(f"DESCRIBE SELECT * FROM read_parquet({src},union_by_name=true)").fetchall()}
    extra=[]
    for name in ("subtype","class"):
        if name in cols:
            extra.append((name,f'cast("{name}" as varchar)'))
    select_extra="".join(","+expr for _,expr in extra)
    cur=con.execute(f"""
      select cast(id as varchar) id,
             ST_AsGeoJSON(ST_GeomFromWKB(geometry)) geom
             {select_extra}
      from read_parquet({src},union_by_name=true)
      where geometry is not null
    """)
    count=0
    with out_path.open("w",encoding="utf-8") as f:
        while True:
            rows=cur.fetchmany(10000)
            if not rows:break
            for row in rows:
                props={"kind":kind}
                for idx,(name,_) in enumerate(extra,start=2):
                    if row[idx] is not None:props[name]=row[idx]
                feat={"type":"Feature","id":row[0],"geometry":json.loads(row[1]),"properties":props}
                f.write(json.dumps(feat,separators=(",",":"))+"\n")
                count+=1
    return count,sorted(cols)

def build_pmtiles(state,local,out_dir,expected):
    con=duckdb.connect(database=":memory:")
    con.execute("SET threads=4")
    con.execute("SET memory_limit='5GB'")
    con.execute("INSTALL spatial; LOAD spatial")
    segment_geo=out_dir/"segments.geojsonseq"
    connector_geo=out_dir/"connectors.geojsonseq"
    seg_count,seg_cols=write_geojsonseq(con,local["segment"],"segment",segment_geo)
    con_count,con_cols=write_geojsonseq(con,local["connector"],"connector",connector_geo)
    con.close()
    if seg_count!=int(expected["segment_rows"]) or con_count!=int(expected["connector_rows"]):
        raise RuntimeError(f"export row mismatch segments={seg_count}/{expected['segment_rows']} connectors={con_count}/{expected['connector_rows']}")
    output=out_dir/"transport.pmtiles"
    cmd=[
        "tippecanoe","--force","-Z6","-z16","--drop-densest-as-needed","--extend-zooms-if-still-dropping",
        "-o",str(output),
        "-L",f"segments:{segment_geo}",
        "-L",f"connectors:{connector_geo}",
    ]
    print("RUN"," ".join(cmd))
    subprocess.run(cmd,check=True)
    if not output.exists() or output.stat().st_size<=0:
        raise RuntimeError("tippecanoe produced no PMTiles output")
    return output,seg_count,con_count,{"segment_columns":seg_cols,"connector_columns":con_cols}

def upload_finalize(state,output,seg_count,con_count,metadata):
    digest=sha256_file(output)
    size=output.stat().st_size
    signed=post({"action":"sign_upload","state_code":state})
    with output.open("rb") as f:
        r=requests.put(signed["signed_url"],data=f,headers={
            "content-type":"application/octet-stream","x-upsert":"true","content-length":str(size)
        },timeout=1800)
    if not r.ok:
        raise RuntimeError(f"runtime upload {r.status_code}: {r.text[:1200]}")
    generated=dt.datetime.now(dt.timezone.utc).isoformat()
    receipt=post({
        "action":"finalize","state_code":state,"file_bytes":size,"sha256":digest,
        "segment_rows":seg_count,"connector_rows":con_count,"minzoom":6,"maxzoom":16,
        "generated_at":generated,
        "metadata":{
            **metadata,
            "generator":"felt/tippecanoe",
            "tippecanoe_sha":TIPPECANOE_SHA,
            "layers":["segments","connectors"],
            "source_archive_version":2696,
            "runtime_version":2716,
        }
    })
    print(json.dumps({"runtime_receipt":receipt,"sha256":digest,"bytes":size},separators=(",",":")))

def main():
    p=argparse.ArgumentParser()
    p.add_argument("--state",default="DC")
    p.add_argument("--work-dir",default="transport-runtime-output")
    args=p.parse_args()
    state=args.state.upper()
    work=pathlib.Path(args.work_dir)
    work.mkdir(parents=True,exist_ok=True)
    listing,local=download_sources(state,work)
    expected=listing["summary"]
    output,seg_count,con_count,meta=build_pmtiles(state,local,work,expected)
    meta["source_object_count"]=len(listing["objects"])
    meta["source_bytes"]=int(expected["source_bytes"])
    upload_finalize(state,output,seg_count,con_count,meta)

if __name__=="__main__":
    try:
        main()
    except Exception as e:
        print(f"RUNTIME_BUILD_FAILED: {e}",file=sys.stderr)
        raise
