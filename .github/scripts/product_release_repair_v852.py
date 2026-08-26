from pathlib import Path
import re

ROOT = Path('.')

def read(path):
    return (ROOT/path).read_text(encoding='utf-8')

def write(path, value):
    (ROOT/path).write_text(value, encoding='utf-8')

# WEATHER: remove duplicate imports introduced by partial V851 replay.
path = 'lib/v2/bridgepoint_map_weather_v2.dart'
s = read(path)
for line in ["import 'dart:convert';", "import 'package:http/http.dart' as http;"]:
    first = s.find(line)
    if first < 0:
        raise SystemExit(f'weather missing required import: {line}')
    cursor = s.find(line, first + len(line))
    while cursor >= 0:
        start = cursor
        end = cursor + len(line)
        if end < len(s) and s[end] == '\n':
            end += 1
        s = s[:start] + s[end:]
        cursor = s.find(line, first + len(line))
write(path, s)

# BUILDINGS: remove dead generic payload inspector. Real Twin UI is _TwinSummary.
path = 'lib/v2/bridgepoint_buildings_v2.dart'
s = read(path)
marker = '\nclass _Payload extends StatelessWidget {'
if marker in s:
    s = s[:s.index(marker)].rstrip() + '\n'
write(path, s)

# GLOBAL SEARCH: remove dead recursive payload inspectors. Search now uses curated property presenters.
path = 'lib/v2/bridgepoint_global_search_v2.dart'
s = read(path)
marker = '\nclass _PayloadPanel extends StatelessWidget {'
if marker in s:
    s = s[:s.index(marker)].rstrip() + '\n'
write(path, s)

# PACKAGES: never expose checkout/Supabase exception text to a buyer.
path = 'lib/v2/settings/bridgepoint_packages_v2.dart'
s = read(path)
s = s.replace("    } catch (e) {\n      if (mounted) setState(() => _message = 'Checkout unavailable: $e');\n", "    } catch (_) {\n      if (mounted) setState(() => _message = 'Checkout is temporarily unavailable. Please try again.');\n")
s = s.replace("    } catch (e) {\n      if (mounted) setState(() => _message = 'Could not request activation: $e');\n", "    } catch (_) {\n      if (mounted) setState(() => _message = 'Could not submit this activation request right now. Please try again.');\n")
s = s.replace("              Text('Package catalog unavailable: ${snapshot.error}')", "              const Text('Package catalog is temporarily unavailable. Please refresh and try again.')")
write(path, s)

print('V852 deterministic product repairs applied')
