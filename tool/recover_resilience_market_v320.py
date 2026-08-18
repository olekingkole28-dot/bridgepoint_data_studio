from pathlib import Path
import base64
import hashlib
import re
import subprocess
import zlib

path=Path('lib/main.dart')
legacy=Path('tool/apply_resilience_market_v320.py').read_text(encoding='utf-8')

def grab(pattern,label):
    match=re.search(pattern,legacy,re.S)
    if not match:
        raise SystemExit(f'v320 recovery could not read {label}')
    return match.group(1)

expected_pre=grab(r"expected_pre='([^']+)'",'expected_pre')
expected_post=grab(r"expected_post='([^']+)'",'expected_post')
blob=grab(r"blob='([^']+)'",'payload')
actual=hashlib.sha256(path.read_bytes()).hexdigest()
if actual!=expected_pre:
    raise SystemExit(f'v320 recovery baseline mismatch: expected {expected_pre}, got {actual}')

alphabet='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

def decode(candidate):
    padded=candidate + '='*((4-len(candidate)%4)%4)
    raw=base64.b64decode(padded,validate=False)
    patch=zlib.decompress(raw)
    if b'lib/main.dart' not in patch:
        raise ValueError('decoded payload is not the BridgePoint main.dart patch')
    return patch

patch=None
method=None
try:
    patch=decode(blob)
    method='unchanged'
except Exception:
    pass

if patch is None:
    # The committed payload has a Base64 data-character count of 1 mod 4. First test
    # the inexpensive and most likely case: one accidental extra character.
    for i in range(len(blob)):
        try:
            candidate=blob[:i]+blob[i+1:]
            patch=decode(candidate)
            method=f'removed extra Base64 character at index {i}'
            break
        except Exception:
            continue

if patch is None:
    # If one character was omitted instead, find the unique insertion that restores a
    # valid zlib stream. A valid full zlib checksum makes accidental success negligible.
    for i in range(len(blob)+1):
        prefix=blob[:i]
        suffix=blob[i:]
        for ch in alphabet:
            try:
                patch=decode(prefix+ch+suffix)
                method=f'restored missing Base64 character at index {i}'
                break
            except Exception:
                continue
        if patch is not None:
            break

if patch is None:
    raise SystemExit('v320 recovery could not reconstruct the committed patch payload safely')

print(f'V320 payload recovery: {method}')
subprocess.run(['patch','--batch','--forward','--reject-file=-','-p0'],input=patch,check=True)
actual=hashlib.sha256(path.read_bytes()).hexdigest()
if actual!=expected_post:
    raise SystemExit(f'v320 recovered output mismatch: expected {expected_post}, got {actual}')

body=path.read_text(encoding='utf-8')
for needle in [
    'bridgepoint-v320-resilience-market-guard-service-credit',
    'bridgepoint-v320-unsupported-market-preview',
    'bridgepoint-v320-owner-resilience-metrics',
    'bridgepoint_public_system_status_v320',
    'bridgepoint_user_market_context_v320',
    'bridgepoint_owner_resilience_metrics_v320',
    'BridgePoint is temporarily unavailable',
    'estimated restoration',
    'LIVE SOURCE OUTAGES',
    'AUTO-DISCOVERY PENDING',
]:
    if needle not in body:
        raise SystemExit(f'v320 recovered release marker missing: {needle}')
print('BridgePoint v320 resilience + market guard payload recovered and verified.')
