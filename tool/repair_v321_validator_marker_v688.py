#!/usr/bin/env python3
from pathlib import Path

p=Path('tool/apply_resilience_expansion_radar_v321.py')
s=p.read_text(encoding='utf-8')
old='U.S. precipitation radar on • expansion badges hidden so the radar stays clear.'
if old not in s:
    print('V688: retired snackbar marker already absent from V321 validator.')
    raise SystemExit(0)

# The old human-facing snackbar disappeared when the map controls evolved. It is
# not a functional release contract. Replace only the final/plain validator
# occurrence; the compressed historical patch payload remains untouched.
pos=s.rfind(old)
if pos < 0:
    raise SystemExit('V688: validator marker not found')
s=s[:pos]+'_loadNoaaRadarFramesV271'+s[pos+len(old):]
p.write_text(s,encoding='utf-8')

out=p.read_text(encoding='utf-8')
if out.rfind(old) > pos:
    raise SystemExit('V688: unexpected trailing stale marker remains')
if '_loadNoaaRadarFramesV271' not in out:
    raise SystemExit('V688: stable NOAA loader marker missing after patch')
print('V688: replaced retired V321 snackbar validator marker with stable NOAA loader contract.')
