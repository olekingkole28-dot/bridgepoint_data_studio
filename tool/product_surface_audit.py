from pathlib import Path
import json,re

ROOT=Path('lib')
patterns={
 'raw_json_encoder': re.compile(r'JsonEncoder|jsonEncode\('),
 'raw_entries_render': re.compile(r'\.entries(?:\.take\(|\s*\.map\()'),
 'raw_payload_widget': re.compile(r'class\s+_[A-Za-z0-9]*(?:Payload|CompactMap|DataPanel)'),
 'exception_to_user': re.compile(r'(snapshot\.error|error\.toString\(\)|_error!|\$e\b|PostgrestException)'),
 'generic_value_render': re.compile(r"['\"]value['\"]\s*:\s*value|\$\{e\.value\}|\$payload"),
 'placeholder_driver': re.compile(r"\?\?\s*['\"]driver['\"]|No driver rows returned"),
 'raw_rpc_field': re.compile(r"['\"]rpc['\"]\s*:\s*"),
 'debug_copy': re.compile(r'raw owner-only|debugging and verification|control-plane snapshot',re.I),
}
rows=[]
for p in sorted(ROOT.rglob('*.dart')):
    text=p.read_text(encoding='utf-8',errors='ignore')
    hits={}
    lines=text.splitlines()
    for name,rx in patterns.items():
        found=[]
        for i,line in enumerate(lines,1):
            if rx.search(line):
                found.append({'line':i,'text':line.strip()[:220]})
        if found: hits[name]=found[:30]
    if hits:
        rows.append({'file':str(p),'hits':hits})
out={'files_scanned':len(list(ROOT.rglob('*.dart'))),'files_flagged':len(rows),'results':rows}
Path('product-surface-audit.json').write_text(json.dumps(out,indent=2),encoding='utf-8')
print(json.dumps({'files_scanned':out['files_scanned'],'files_flagged':out['files_flagged']}))
