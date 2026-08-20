from pathlib import Path

source_path=Path('tool/apply_national_dashboard_v352.py')
source=source_path.read_text(encoding='utf-8')

# The generated release has evolved the Daily Brief ValueKey formatting. Keep the
# V352 surface logic unchanged, but replace only that brittle source-code anchor with
# a structural regex before executing the migration.
section=source.index('# Keep Daily Brief keyed to its selected state and pass state/control to overview.')
first_once=source.index('once(',section)
next_once=source.index('\nonce(',first_once+5)
repair=r'''key_pattern=re.compile(r"key\s*:\s*ValueKey\(\s*'brief-[^']*'\s*\),")
key_replacement="key:ValueKey('brief-$_liveRefreshTick-$selectedPackage-$selectedDashboardStateCode'),"
text,key_count=key_pattern.subn(key_replacement,text,count=1)
if key_count!=1:
    raise SystemExit(f'v353 daily brief key: expected 1 structural anchor, found {key_count}')
'''
patched=source[:first_once]+repair+source[next_once+1:]

namespace={'__name__':'__main__','__file__':str(source_path)}
exec(compile(patched,str(source_path),'exec'),namespace,namespace)
print('BRIDGEPOINT NATIONAL DASHBOARD V353 COMPATIBILITY PASSED')
print(' - Daily Brief key matched structurally; V352 runtime/performance behavior unchanged')
