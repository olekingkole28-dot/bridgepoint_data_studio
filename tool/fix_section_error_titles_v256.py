from pathlib import Path

path = Path('lib/main.dart')
body = path.read_text(encoding='utf-8')
marker = 'bridgepoint-v256-section-error-titles'

if marker in body:
    print('Section-aware error titles v256 already applied.')
    raise SystemExit(0)

old_ctor = """class _DashboardError extends StatelessWidget {
  const _DashboardError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;
"""
new_ctor = """class _DashboardError extends StatelessWidget {
  const _DashboardError({required this.message, required this.onRetry, this.title = 'This section could not load'});

  final String message;
  final VoidCallback onRetry;
  final String title;
"""
if body.count(old_ctor) != 1:
    raise SystemExit(f'v256 dashboard error constructor anchor count {body.count(old_ctor)}')
body = body.replace(old_ctor, new_ctor, 1)

old_title = """                  const Text(
                    'Live dashboard could not load',
"""
new_title = """                  Text(
                    title,
"""
if body.count(old_title) != 1:
    raise SystemExit(f'v256 shared error title anchor count {body.count(old_title)}')
body = body.replace(old_title, new_title, 1)

workspace_old = "_DashboardError(message:snapshot.error.toString(),onRetry:()=>setState(()=>request=_load()))"
workspace_new = "_DashboardError(title:'Workspace could not load',message:snapshot.error.toString(),onRetry:()=>setState(()=>request=_load()))"
if body.count(workspace_old) != 1:
    raise SystemExit(f'v256 workspace error anchor count {body.count(workspace_old)}')
body = body.replace(workspace_old, workspace_new, 1)

start = body.find('class _PropertiesPageState extends State<_PropertiesPage>')
if start < 0:
    raise SystemExit('v256 Properties class anchor missing')
end = body.find('\nclass ', start + 20)
if end < 0:
    end = len(body)
segment = body[start:end]
properties_anchor = '_DashboardError('
properties_count = segment.count(properties_anchor)
if properties_count != 1:
    raise SystemExit(f'v256 Properties error widget count {properties_count}')
segment = segment.replace(properties_anchor, "_DashboardError(title:'Properties could not load',", 1)
body = body[:start] + segment + body[end:]

body += "\nconst String _bridgePointSectionErrorsV256='bridgepoint-v256-section-error-titles | Properties could not load | This section could not load';\n"
path.write_text(body, encoding='utf-8')
print('Applied section-aware BridgePoint error titles v256.')
