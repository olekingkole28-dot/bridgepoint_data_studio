from pathlib import Path

source_path=Path('tool/apply_national_dashboard_v352.py')
source=source_path.read_text(encoding='utf-8')

# The generated release has evolved formatting around Daily Brief. Keep V352 runtime
# behavior unchanged, but replace only the brittle source-code anchors with structural
# regexes before executing the isolated migration.
section=source.index('# Keep Daily Brief keyed to its selected state and pass state/control to overview.')
first_once=source.index('once(',section)
second_once=source.index('\nonce(',first_once+5)+1
key_repair=r'''key_pattern=re.compile(r"key\s*:\s*ValueKey\(\s*'brief-[^']*'\s*\),")
key_replacement="key:ValueKey('brief-$_liveRefreshTick-$selectedPackage-$selectedDashboardStateCode'),"
text,key_count=key_pattern.subn(key_replacement,text,count=1)
if key_count!=1:
    raise SystemExit(f'v353 daily brief key: expected 1 structural anchor, found {key_count}')
'''
patched=source[:first_once]+key_repair+source[second_once:]

# Replace only the V352 script's exact 'overview state call' once() block with a
# generated-Flutter structural matcher. This tolerates whitespace/newline drift while
# remaining scoped to selectedPackage immediately followed by dashboardRequest.
label="'overview state call'"
label_idx=patched.index(label)
overview_start=patched.rfind('once(',0,label_idx)
overview_end=patched.index('\nonce(',label_idx)+1
overview_repair=r'''overview_pattern=re.compile(
    r"selectedPackage\s*:\s*selectedPackage\s*,\s*dashboardRequest\s*:\s*dashboardRequest\s*,"
)
overview_replacement=(
    "selectedPackage: selectedPackage,\n"
    "            selectedStateCode: selectedDashboardStateCode,\n"
    "            onStateChanged: _selectDashboardStateV352,\n"
    "            dashboardRequest: dashboardRequest,"
)
text,overview_count=overview_pattern.subn(overview_replacement,text,count=1)
if overview_count!=1:
    raise SystemExit(f'v353 overview state call: expected 1 structural anchor, found {overview_count}')
'''
patched=patched[:overview_start]+overview_repair+patched[overview_end:]

namespace={'__name__':'__main__','__file__':str(source_path)}
exec(compile(patched,str(source_path),'exec'),namespace,namespace)
print('BRIDGEPOINT NATIONAL DASHBOARD V353 COMPATIBILITY PASSED')
print(' - Daily Brief key and overview call matched structurally; V352 runtime/performance behavior unchanged')
