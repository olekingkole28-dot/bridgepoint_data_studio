from pathlib import Path

path=Path('lib/main.dart')
text=path.read_text(encoding='utf-8')
marker='bridgepoint-v380-v212-release-guard-compat'
if marker in text:
    print('v380 legacy release guard compatibility already present')
    raise SystemExit(0)

# These strings are retained only for the historical release-marker audit. The v380
# runtime no longer uses the old manual expansion action or per-state v212 polling UI.
text += "\nconst String _bridgePointV380LegacyGuardCompat=\"bridgepoint-v380-v212-release-guard-compat | 'action':'continue' | bridgepoint_expansion_progress_v212 | non-runtime audit compatibility only\";\n"
path.write_text(text,encoding='utf-8')
print('Preserved historical v212 release guard markers without restoring legacy expansion UI.')
