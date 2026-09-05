#!/usr/bin/env python3
"""BridgePoint Recovery Agent v1844.

Outbound-only owner-PC worker for independent recovery. It uses the existing
BridgePoint local-node id/token, never a Supabase service-role key. Server-side
privileged authority remains separately controlled.

Responsibilities:
- claim/execute full local database+storage+source backups
- SHA-256 verify backup artifacts
- run schema restore tests against an explicitly non-production PostgreSQL DB
- stream state portable exports to compressed JSONL, including addresses,
  parcel EWKB geometry, lifecycle data, source evidence, and legal manifest
"""
from __future__ import annotations

import gzip
import hashlib
import json
import os
import platform
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any

PROJECT_REF = "xdfsjztwgsbmabshzsjw"
BROKER = os.environ.get(
    "BRIDGEPOINT_RECOVERY_BROKER",
    f"https://{PROJECT_REF}.supabase.co/functions/v1/bridgepoint-recovery-broker-v1844",
)
LOCALAPP = Path(os.environ.get("LOCALAPPDATA", str(Path.home()))) / "BridgePoint" / "LocalAI"
STATE_FILE = LOCALAPP / "node.json"
BACKUP_CONFIG = LOCALAPP / "backup-config.json"
SCRIPT_DIR = Path(__file__).resolve().parent
FULL_EXPORT_SCRIPT = SCRIPT_DIR / "bridgepoint_full_export_windows.ps1"
EXPORT_ROOT = Path(os.environ.get("BRIDGEPOINT_PORTABLE_EXPORT_ROOT", str(Path.home() / "BridgePointExports")))
POLL_SECONDS = max(4, int(os.environ.get("BRIDGEPOINT_RECOVERY_POLL_SECONDS", "8")))
PAGE_LIMIT = max(100, min(int(os.environ.get("BRIDGEPOINT_EXPORT_PAGE_LIMIT", "1000")), 1000))
DATASETS = [
    "PROPERTIES", "ADDRESSES", "PARCEL_GEOMETRY", "SIGNALS", "PATTERNS",
    "SCORES", "OPPORTUNITIES", "MEDIA", "SOURCES", "EVIDENCE",
    "LEGAL_MANIFEST", "STATE_SUMMARY", "PACKAGE_MAP",
]


def request(state: dict[str, Any], action: str, timeout: int = 180, **payload: Any) -> dict[str, Any]:
    body = json.dumps({"action": action, "node_id": state["node_id"], **payload}, separators=(",", ":")).encode()
    req = urllib.request.Request(
        BROKER,
        data=body,
        headers={
            "content-type": "application/json",
            "user-agent": "BridgePoint-Recovery/1844",
            "x-bridgepoint-node-token": state["node_token"],
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            out = json.loads(r.read().decode("utf-8", "replace") or "{}")
    except urllib.error.HTTPError as e:
        text = e.read().decode("utf-8", "replace")
        raise RuntimeError(f"HTTP {e.code}: {text[:1600]}") from e
    if out.get("ok") is False:
        raise RuntimeError(str(out.get("error") or out))
    return out


def load_state() -> dict[str, Any]:
    if not STATE_FILE.exists():
        raise RuntimeError(f"Local node state not found: {STATE_FILE}. Enroll/start BridgePoint Local AI first.")
    state = json.loads(STATE_FILE.read_text(encoding="utf-8"))
    if not state.get("node_id") or not state.get("node_token"):
        raise RuntimeError("Local node state is missing node_id/node_token")
    return state


def hardware() -> dict[str, Any]:
    return {"platform": platform.platform(), "machine": platform.machine(), "python": platform.python_version()}


def have(cmd: str) -> bool:
    try:
        return subprocess.run(["where" if os.name == "nt" else "which", cmd], capture_output=True).returncode == 0
    except Exception:
        return False


def unprotect_windows(value: str) -> str:
    if not value:
        return ""
    if os.name != "nt":
        raise RuntimeError("DPAPI backup configuration can only be decrypted by the Windows user that created it")
    env = os.environ.copy()
    env["BP_PROTECTED"] = value
    script = (
        "$s=ConvertTo-SecureString $env:BP_PROTECTED;"
        "$p=[Runtime.InteropServices.Marshal]::SecureStringToBSTR($s);"
        "try{[Runtime.InteropServices.Marshal]::PtrToStringBSTR($p)}finally{[Runtime.InteropServices.Marshal]::ZeroFreeBSTR($p)}"
    )
    p = subprocess.run(["powershell", "-NoProfile", "-Command", script], capture_output=True, text=True, env=env, timeout=30)
    if p.returncode != 0:
        raise RuntimeError(f"Could not decrypt local backup configuration: {p.stderr[-600:]}")
    return p.stdout.rstrip("\r\n")


def backup_config() -> dict[str, Any]:
    if not BACKUP_CONFIG.exists():
        raise RuntimeError(f"Backup config missing. Run {SCRIPT_DIR / 'configure_backup_windows.ps1'} locally first.")
    cfg = json.loads(BACKUP_CONFIG.read_text(encoding="utf-8"))
    if not cfg.get("backup_enabled"):
        raise RuntimeError("Local backup is not enabled")
    return cfg


def latest_backup_root(cfg: dict[str, Any]) -> Path:
    root = Path(cfg.get("destination") or (Path.home() / "BridgePointBackups"))
    choices = sorted((p for p in root.glob("BridgePoint-*") if p.is_dir()), key=lambda p: p.name, reverse=True)
    if not choices:
        raise RuntimeError(f"No BridgePoint backup folders found under {root}")
    return choices[0]


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(8 * 1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def run_full_export(cfg: dict[str, Any]) -> dict[str, Any]:
    if os.name != "nt":
        raise RuntimeError("The installed full-export script currently targets Windows")
    if not FULL_EXPORT_SCRIPT.exists():
        raise RuntimeError(f"Missing full export script: {FULL_EXPORT_SCRIPT}")
    db_url = unprotect_windows(cfg.get("db_url_protected", ""))
    s3_id = unprotect_windows(cfg.get("s3_access_key_protected", ""))
    s3_secret = unprotect_windows(cfg.get("s3_secret_key_protected", ""))
    env = os.environ.copy()
    env["BRIDGEPOINT_BACKUP_DESTINATION"] = str(cfg.get("destination") or (Path.home() / "BridgePointBackups"))
    env["BRIDGEPOINT_BACKUP_DB_URL"] = db_url
    env["BRIDGEPOINT_BACKUP_S3_ACCESS_KEY_ID"] = s3_id
    env["BRIDGEPOINT_BACKUP_S3_SECRET_ACCESS_KEY"] = s3_secret
    try:
        p = subprocess.run(
            ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(FULL_EXPORT_SCRIPT), "-NonInteractive"],
            capture_output=True, text=True, env=env, timeout=None,
        )
    finally:
        db_url = s3_id = s3_secret = ""
        for k in ("BRIDGEPOINT_BACKUP_DB_URL", "BRIDGEPOINT_BACKUP_S3_ACCESS_KEY_ID", "BRIDGEPOINT_BACKUP_S3_SECRET_ACCESS_KEY"):
            env.pop(k, None)
    if p.returncode != 0:
        raise RuntimeError(f"Full export failed: {(p.stderr or p.stdout)[-1800:]}")
    root = None
    for line in p.stdout.splitlines():
        if line.startswith("BRIDGEPOINT_BACKUP_ROOT="):
            root = Path(line.split("=", 1)[1].strip())
    if root is None or not root.exists():
        root = latest_backup_root(cfg)
    manifest = root / "manifest.json"
    dump = root / "database" / "bridgepoint_full.dump"
    return {
        "backup_root": str(root),
        "manifest": str(manifest),
        "database_dump": str(dump),
        "database_dump_bytes": dump.stat().st_size if dump.exists() else None,
        "database_dump_sha256": sha256_file(dump) if dump.exists() else None,
        "completed_at": time.time(),
        "runner_version": 1844,
    }


def verify_backup(root: Path) -> dict[str, Any]:
    sums = root / "SHA256SUMS.txt"
    dump = root / "database" / "bridgepoint_full.dump"
    if not sums.exists() or not dump.exists():
        raise RuntimeError("Backup is missing SHA256SUMS.txt or bridgepoint_full.dump")
    checked = 0
    total_bytes = 0
    failures: list[str] = []
    for line in sums.read_text(encoding="ascii", errors="replace").splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            expected, rel = line.split(None, 1)
            rel = rel.strip()
            path = root / rel
            if not path.exists():
                failures.append(f"MISSING:{rel}")
                continue
            actual = sha256_file(path)
            checked += 1
            total_bytes += path.stat().st_size
            if actual.lower() != expected.lower():
                failures.append(f"HASH:{rel}")
        except Exception as e:
            failures.append(f"PARSE:{line[:160]}:{e}")
    p = subprocess.run(["pg_restore", "--list", str(dump)], capture_output=True, text=True, timeout=600)
    if p.returncode != 0:
        failures.append("PG_RESTORE_CATALOG_UNREADABLE")
    if failures:
        raise RuntimeError("Backup verification failed: " + ";".join(failures[:30]))
    return {
        "backup_root": str(root), "hash_files_verified": checked, "verified_bytes": total_bytes,
        "archive_catalog_readable": True, "status": "VERIFIED", "verified_at": time.time(), "runner_version": 1844,
    }


def _pg_env_from_url(url: str) -> tuple[dict[str, str], str]:
    u = urllib.parse.urlparse(url)
    if u.scheme not in ("postgres", "postgresql") or not u.hostname:
        raise RuntimeError("Invalid restore-test PostgreSQL URL")
    if PROJECT_REF in url:
        raise RuntimeError("Production BridgePoint database may never be a restore-test target")
    env = os.environ.copy()
    env.update({"PGHOST": u.hostname, "PGPORT": str(u.port or 5432), "PGDATABASE": (u.path or "/postgres").lstrip("/"), "PGUSER": urllib.parse.unquote(u.username or "postgres"), "PGSSLMODE": "require"})
    if u.password:
        env["PGPASSWORD"] = urllib.parse.unquote(u.password)
    return env, env["PGDATABASE"]


def restore_test(cfg: dict[str, Any], root: Path, schema_only: bool = True) -> dict[str, Any]:
    protected = cfg.get("restore_test_db_url_protected", "")
    if not cfg.get("restore_test_enabled") or not protected:
        raise RuntimeError("Restore-test target is not configured. Run configure_backup_windows.ps1 with a NON-PRODUCTION DB URL.")
    url = unprotect_windows(protected)
    env, dbname = _pg_env_from_url(url)
    dump = root / "database" / "bridgepoint_full.dump"
    args = ["pg_restore", "--clean", "--if-exists", "--no-owner", "--no-acl", "--dbname", dbname]
    if schema_only:
        args.append("--schema-only")
    args.append(str(dump))
    try:
        p = subprocess.run(args, capture_output=True, text=True, env=env, timeout=None)
    finally:
        env.pop("PGPASSWORD", None)
        url = ""
    if p.returncode != 0:
        raise RuntimeError(f"Restore test failed: {p.stderr[-1800:]}")
    return {"backup_root": str(root), "schema_only": schema_only, "status": "RESTORE_TEST_PASSED", "tested_at": time.time(), "runner_version": 1844}


def process_backup(state: dict[str, Any]) -> bool:
    claim = request(state, "backup_claim")
    job = claim.get("job")
    if not job:
        return False
    job_id = str(job["job_id"])
    op = str(job.get("operation") or "").upper()
    try:
        cfg = backup_config()
        if op == "EXPORT":
            result = run_full_export(cfg)
        elif op == "VERIFY":
            result = verify_backup(latest_backup_root(cfg))
        elif op == "RESTORE_TEST":
            result = restore_test(cfg, latest_backup_root(cfg), bool(job.get("schema_only", True)))
        else:
            raise RuntimeError(f"Unsupported backup operation {op}")
        request(state, "backup_complete", job_id=job_id, result=result, timeout=300)
        print(f"[BridgePoint Recovery] {op} succeeded {job_id}", flush=True)
    except Exception as e:
        request(state, "backup_fail", job_id=job_id, error=str(e)[:1800], result={"runner_version": 1844}, timeout=120)
        print(f"[BridgePoint Recovery] {op} failed {job_id}: {e}", file=sys.stderr, flush=True)
    return True


def process_export(state: dict[str, Any]) -> bool:
    claim = request(state, "export_claim")
    job = claim.get("job")
    if not job:
        return False
    request_id = str(job["request_id"])
    st = str(job["scope_key"]).upper()
    root = EXPORT_ROOT / st / request_id
    root.mkdir(parents=True, exist_ok=True)
    manifest: dict[str, Any] = {"version": 1844, "request_id": request_id, "state_code": st, "started_at": time.time(), "datasets": {}}
    try:
        for ds in DATASETS:
            path = root / f"{ds.lower()}.jsonl.gz"
            cursor = None
            rows_written = 0
            pages = 0
            with gzip.open(path, "wt", encoding="utf-8", compresslevel=6) as out:
                while True:
                    page = request(state, "export_page", request_id=request_id, dataset=ds, cursor=cursor, limit=PAGE_LIMIT, timeout=240)
                    for row in page.get("rows") or []:
                        out.write(json.dumps(row, separators=(",", ":"), ensure_ascii=False) + "\n")
                        rows_written += 1
                    pages += 1
                    if page.get("done"):
                        break
                    nxt = page.get("next_cursor")
                    if not nxt or nxt == cursor:
                        raise RuntimeError(f"Non-advancing cursor in {ds}: {cursor!r} -> {nxt!r}")
                    cursor = str(nxt)
            manifest["datasets"][ds] = {"file": path.name, "rows": rows_written, "pages": pages, "bytes": path.stat().st_size, "sha256": sha256_file(path)}
            print(f"[BridgePoint Recovery] {st} {ds}: {rows_written:,} rows", flush=True)
        manifest["completed_at"] = time.time()
        manifest_path = root / "manifest.json"
        manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True), encoding="utf-8")
        manifest_hash = sha256_file(manifest_path)
        result = {"root": str(root), "manifest": str(manifest_path), "manifest_sha256": manifest_hash, "datasets": manifest["datasets"], "runner_version": 1844}
        request(state, "export_complete", request_id=request_id, result=result, timeout=180)
        print(f"[BridgePoint Recovery] portable export complete: {st} {request_id}", flush=True)
    except Exception as e:
        request(state, "export_fail", request_id=request_id, error=str(e)[:1800], result={"root": str(root), "runner_version": 1844}, timeout=120)
        print(f"[BridgePoint Recovery] portable export failed {st} {request_id}: {e}", file=sys.stderr, flush=True)
    return True


def main() -> int:
    state = load_state()
    EXPORT_ROOT.mkdir(parents=True, exist_ok=True)
    print(f"[BridgePoint Recovery] node={state['node_id']} broker={BROKER}", flush=True)
    while True:
        try:
            request(state, "heartbeat", capabilities={"recovery_runner": True, "backup_runner": BACKUP_CONFIG.exists(), "portable_export_runner": True, "runner_version": "1844"}, hardware=hardware(), timeout=60)
            did = process_backup(state)
            if not did:
                did = process_export(state)
            if not did:
                time.sleep(POLL_SECONDS)
        except KeyboardInterrupt:
            return 0
        except Exception as e:
            print(f"[BridgePoint Recovery] loop error: {e}", file=sys.stderr, flush=True)
            time.sleep(max(POLL_SECONDS, 15))


if __name__ == "__main__":
    raise SystemExit(main())
