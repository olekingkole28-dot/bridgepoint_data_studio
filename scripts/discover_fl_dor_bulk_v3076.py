#!/usr/bin/env python3
import json
import sys
import urllib.parse
import urllib.request
from datetime import datetime, timezone

BASE = "https://floridarevenue.com/property/dataportal"
ROOT = "/property/dataportal/Documents/PTO Data Portal/Map Data/2026F"
OUT = "ops/fl-dor-bulk-files-v3076.json"

def get_json(url):
    req = urllib.request.Request(
        url,
        headers={
            "Accept": "application/json;odata=nometadata",
            "User-Agent": "BridgePointIntelligence/1.0",
        },
    )
    with urllib.request.urlopen(req, timeout=45) as r:
        return r.status, json.loads(r.read().decode("utf-8"))

def folder_api(folder, child):
    esc = folder.replace("'", "''")
    path = f"/_api/web/GetFolderByServerRelativeUrl('{esc}')/{child}"
    return BASE + path.replace(" ", "%20")

def list_folder(folder):
    status_f, jf = get_json(folder_api(folder, "Files?$select=Name,ServerRelativeUrl,Length,TimeLastModified"))
    status_d, jd = get_json(folder_api(folder, "Folders?$select=Name,ServerRelativeUrl,TimeLastModified"))
    files = jf.get("value", []) if isinstance(jf, dict) else []
    dirs = [x for x in (jd.get("value", []) if isinstance(jd, dict) else [])
            if str(x.get("Name", "")).lower() != "forms"]
    return status_f, status_d, files, dirs

def main():
    queue = [ROOT]
    seen = set()
    rows = []
    while queue:
        folder = queue.pop(0)
        if folder in seen:
            continue
        seen.add(folder)
        sf, sd, files, dirs = list_folder(folder)
        for x in files:
            rows.append({
                "kind": "FILE",
                "name": x.get("Name"),
                "server_relative_url": x.get("ServerRelativeUrl"),
                "byte_length": int(x.get("Length") or 0),
                "modified_at": x.get("TimeLastModified"),
                "download_url": BASE.split("/property/dataportal")[0] + str(x.get("ServerRelativeUrl") or ""),
            })
        for x in dirs:
            rel = x.get("ServerRelativeUrl")
            rows.append({
                "kind": "FOLDER",
                "name": x.get("Name"),
                "server_relative_url": rel,
                "modified_at": x.get("TimeLastModified"),
            })
            if rel:
                queue.append(rel)

    payload = {
        "version": 3076,
        "source": "FLORIDA_DOR_PTO_MAP_DATA_2026F",
        "official_root": ROOT,
        "discovered_at": datetime.now(timezone.utc).isoformat(),
        "files": sum(1 for x in rows if x["kind"] == "FILE"),
        "folders": sum(1 for x in rows if x["kind"] == "FOLDER"),
        "rows": sorted(rows, key=lambda x: (x["kind"], str(x.get("server_relative_url") or ""))),
    }
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(payload, f, indent=2, sort_keys=True)
        f.write("\n")
    print(json.dumps({k: payload[k] for k in ("version","source","files","folders")}, sort_keys=True))

if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(f"FL_DOR_BULK_DISCOVERY_ERROR: {exc}", file=sys.stderr)
        raise
