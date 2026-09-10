#!/usr/bin/env python3
import argparse, datetime as dt, hashlib, json, math, os, pathlib, sys, time
import duckdb, requests

U=os.environ['SUPABASE_URL'].rstrip('/'); KEY=os.environ['SUPABASE_KEY']
BROKER=f'{U}/functions/v1/bridgepoint-building-archive-broker-v2710'
CAT=f'{U}/rest/v1/rpc/bridgepoint_public_building_archive_catalog_v2710'
ITEM=f'{U}/rest/v1/rpc/bridgepoint_public_building_archive_item_v2710'
AUD='bridgepoint-building-v2710'; TOL=1e-7; TARGET=28*1024*1024; HARD=42*1024*1024

def post(url,payload,headers=None,timeout=120):
 h={'content-type':'application/json'}; h.update(headers or {})
 r=requests.post(url,json=payload,headers=h,timeout=timeout)
 if not r.ok: raise RuntimeError(f'POST {url} -> {r.status_code}: {r.text[:1500]}')
 return r.json()

def oidc():
 url=os.environ.get('ACTIONS_ID_TOKEN_REQUEST_URL',''); tok=os.environ.get('ACTIONS_ID_TOKEN_REQUEST_TOKEN','')
 if not url or not tok: raise RuntimeError('GitHub renewable OIDC endpoint unavailable')
 sep='&' if '?' in url else '?'; r=requests.get(f'{url}{sep}audience={AUD}',headers={'Authorization':f'bearer {tok}'},timeout=30)
 if not r.ok: raise RuntimeError(f'OIDC refresh {r.status_code}: {r.text[:500]}')
 return r.json()['value']

def broker(action,state,kind,extra=None,timeout=120):
 b={'action':action,'oidc_token':oidc(),'state_code':state,'asset_kind':kind}; b.update(extra or {}); return post(BROKER,b,timeout=timeout)

def rpc(url,payload): return post(url,payload,{'apikey':KEY,'authorization':f'Bearer {KEY}'})
def q(s): return "'"+str(s).replace("'","''")+"'"
def sha(path):
 h=hashlib.sha256()
 with open(path,'rb') as f:
  for c in iter(lambda:f.read(8*1024*1024),b''): h.update(c)
 return h.hexdigest()

def build(state,kind,out):
 cat=rpc(CAT,{'p_state_code':state,'p_asset_kind':kind}); files=cat.get('files',[]); urls=[x['url'] for x in files]
 if not urls: raise RuntimeError(f'No candidate Overture files for {state}/{kind}; refusing false-empty archive')
 west,south,east,north=map(float,cat['bbox']); gj=json.dumps(cat['state_geojson'],separators=(',',':'))
 con=duckdb.connect(':memory:'); con.execute('SET threads=4'); con.execute("SET memory_limit='5GB'"); con.execute('SET preserve_insertion_order=false'); con.execute('INSTALL httpfs; LOAD httpfs'); con.execute('INSTALL spatial; LOAD spatial')
 con.execute('CREATE TEMP TABLE bp_boundary AS SELECT ST_GeomFromGeoJSON(?) geom',[gj])
 source=f"read_parquet([{','.join(q(u) for u in urls)}], union_by_name=true)"
 # Preserve every Overture attribute and replace geometry only with exact jurisdiction clip.
 con.execute(f"""COPY (
  WITH candidate AS (
   SELECT *, geometry AS _bp_geom FROM {source}
   WHERE bbox.xmin <= {east} AND bbox.xmax >= {west} AND bbox.ymin <= {north} AND bbox.ymax >= {south}
  ), clipped AS (
   SELECT candidate.* EXCLUDE(geometry,_bp_geom), ST_Intersection(_bp_geom,b.geom) _bp_clip
   FROM candidate CROSS JOIN bp_boundary b WHERE ST_Intersects(_bp_geom,b.geom)
  )
  SELECT clipped.* EXCLUDE(_bp_clip), ST_AsWKB(_bp_clip) geometry,
   {q(state)}::VARCHAR _bp_jurisdiction,{q(kind)}::VARCHAR _bp_asset_kind,
   {q(cat['source_release'])}::VARCHAR _bp_source_release,{q(cat['source_key'])}::VARCHAR _bp_source_key
  FROM clipped WHERE NOT ST_IsEmpty(_bp_clip)
 ) TO {q(str(out))} (FORMAT PARQUET,COMPRESSION ZSTD,ROW_GROUP_SIZE 100000)""")
 desc=[r[0] for r in con.execute(f"DESCRIBE SELECT * FROM read_parquet({q(str(out))})").fetchall()]
 a=f"read_parquet({q(str(out))})"
 row=con.execute(f"""WITH x AS(SELECT *,geometry g FROM {a}),b AS(SELECT geom FROM bp_boundary),d AS(SELECT x.*,ST_Difference(g,b.geom) outside_geom FROM x CROSS JOIN b)
 SELECT count(*)::BIGINT,count(*) FILTER(WHERE geometry IS NULL)::BIGINT,count(*) FILTER(WHERE geometry IS NOT NULL AND ST_IsEmpty(g))::BIGINT,
 count(*) FILTER(WHERE geometry IS NOT NULL AND NOT ST_IsEmpty(g) AND NOT ST_IsEmpty(outside_geom) AND ST_Length(outside_geom)>{TOL})::BIGINT,
 (count(*)-count(DISTINCT id))::BIGINT,
 count(*) FILTER(WHERE geometry IS NOT NULL AND NOT ST_IsEmpty(g) AND NOT ST_IsEmpty(outside_geom) AND ST_Length(outside_geom)<={TOL})::BIGINT,
 coalesce(max(ST_Length(outside_geom)) FILTER(WHERE outside_geom IS NOT NULL AND NOT ST_IsEmpty(outside_geom)),0)::DOUBLE FROM d""").fetchone()
 validation={'null_geometry':int(row[1]),'empty_geometry':int(row[2]),'outside_geometry':int(row[3]),'duplicate_ids':int(row[4]),'precision_slivers':int(row[5]),'max_outside_length_degrees':float(row[6]),'boundary_validation_tolerance_degrees':TOL}
 if any(validation[k] for k in ('null_geometry','empty_geometry','outside_geometry','duplicate_ids')): raise RuntimeError(f'Validation failed {state}/{kind}: {validation}')
 stats={'rows':int(row[0])}
 for col in ('height','num_floors','min_height','min_floor'):
  if col in desc: stats[f'{col}_source_values']=int(con.execute(f'SELECT count(*) FILTER(WHERE {col} IS NOT NULL) FROM {a}').fetchone()[0])
 for col in ('roof','facade_color','roof_color'):
  if col in desc: stats[f'{col}_source_values']=int(con.execute(f'SELECT count(*) FILTER(WHERE {col} IS NOT NULL) FROM {a}').fetchone()[0])
 con.close(); return int(row[0]),validation,len(urls),stats

def split(path,total):
 base=path.stat().st_size; n=max(1,math.ceil(base/TARGET)); src=q(str(path))
 while True:
  for old in path.parent.glob(path.stem+'-part-*.parquet'): old.unlink()
  con=duckdb.connect(':memory:'); con.execute('SET threads=4'); con.execute("SET memory_limit='5GB'"); con.execute('SET preserve_insertion_order=false'); parts=[]
  for i in range(n):
   p=path.parent/f'{path.stem}-part-{i:05d}.parquet'; con.execute(f"COPY (SELECT * FROM read_parquet({src}) WHERE hash(id)%{n}={i}) TO {q(str(p))} (FORMAT PARQUET,COMPRESSION ZSTD,ROW_GROUP_SIZE 100000)")
   r=con.execute(f'SELECT count(*)::BIGINT,(count(*)-count(DISTINCT id))::BIGINT FROM read_parquet({q(str(p))})').fetchone(); rows=int(r[0]); dups=int(r[1])
   if dups: raise RuntimeError(f'Duplicate IDs in shard {i}: {dups}')
   parts.append({'index':i,'path':p,'rows':rows,'bytes':p.stat().st_size})
  con.close()
  if sum(x['rows'] for x in parts)!=total: raise RuntimeError('Shard row totals do not reconcile')
  if max(x['bytes'] for x in parts)<=HARD: return parts,base
  n*=2

def upload(state,kind,path,rows,validation,source_files,attr_stats):
 parts,base=split(path,rows); broker('report',state,kind,{'status':'BUILDING','stage':'SHARDED','metadata':{'rows':rows,'base_file_bytes':base,'part_count':len(parts),'max_part_bytes':max(p['bytes'] for p in parts),'attribute_stats':attr_stats}})
 receipts=[]
 for p in parts:
  digest=sha(p['path']); signed=broker('sign_part',state,kind,{'part_index':p['index']}); err=None
  for attempt in range(1,4):
   try:
    with open(p['path'],'rb') as f: r=requests.put(signed['signed_url'],data=f,headers={'content-type':'application/vnd.apache.parquet','x-upsert':'true','content-length':str(p['bytes'])},timeout=3600)
    if r.ok: err=None; break
    err=f'HTTP {r.status_code}: {r.text[:700]}'
   except Exception as e: err=str(e)
   if attempt<3: time.sleep(attempt*5); signed=broker('sign_part',state,kind,{'part_index':p['index']})
  if err: raise RuntimeError(f'Part upload failed {p["index"]}: {err}')
  meta={'generated_at':dt.datetime.now(dt.timezone.utc).isoformat(),'source_files':source_files,'builder':'GITHUB_DUCKDB_BUILDING_V2710','compression':'ZSTD','attribute_stats':attr_stats}
  broker('finalize_part',state,kind,{'part_index':p['index'],'row_count':p['rows'],'file_bytes':p['bytes'],'sha256':digest,'validation':validation,'metadata':meta},180)
  receipts.append((p['index'],p['rows'],p['bytes'],digest))
 agg=hashlib.sha256(); [agg.update(f'{i}:{r}:{b}:{s}\n'.encode()) for i,r,b,s in receipts]
 fin=broker('complete_sharded',state,kind,{'part_count':len(receipts),'total_rows':rows,'total_bytes':sum(x[2] for x in receipts),'aggregate_sha256':agg.hexdigest(),'metadata':{'generated_at':dt.datetime.now(dt.timezone.utc).isoformat(),'source_files':source_files,'validation':validation,'attribute_stats':attr_stats,'base_file_bytes':base}},180)
 print(json.dumps({'state':state,'kind':kind,'rows':rows,'parts':len(receipts),'validation':validation,'attribute_stats':attr_stats,'finalize':fin},separators=(',',':')))

def main():
 p=argparse.ArgumentParser();p.add_argument('--state',required=True);p.add_argument('--kind',required=True,choices=['building','building_part']);p.add_argument('--out-dir',default='building-output');a=p.parse_args();state=a.state.upper();kind=a.kind
 existing=rpc(ITEM,{'p_state_code':state,'p_asset_kind':kind})
 if existing.get('verified'): print(json.dumps({'state':state,'kind':kind,'skipped':True,'reason':'ALREADY_VERIFIED'}));return
 broker('reset_parts',state,kind); outdir=pathlib.Path(a.out_dir);outdir.mkdir(parents=True,exist_ok=True);out=outdir/f'{state}-{kind}.parquet';broker('report',state,kind,{'status':'BUILDING','stage':'STARTED','metadata':{'runner':'github-actions','builder_version':2710}})
 try:
  rows,val,nfiles,stats=build(state,kind,out);broker('report',state,kind,{'status':'BUILDING','stage':'VALIDATED','metadata':{'rows':rows,'source_files':nfiles,'validation':val,'attribute_stats':stats,'base_file_bytes':out.stat().st_size}});upload(state,kind,out,rows,val,nfiles,stats)
 except Exception as e:
  try: broker('report',state,kind,{'status':'FAILED','stage':'BUILD_OR_UPLOAD','message':str(e)})
  except Exception: pass
  raise
if __name__=='__main__': main()
