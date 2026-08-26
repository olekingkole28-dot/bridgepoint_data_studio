from pathlib import Path
import re

path=Path('lib/main.dart')
text=path.read_text(encoding='utf-8')
original=text

# v800: match the semantic unread-alert MiniStat regardless of dart format.
unread_pattern=re.compile(r"(?P<indent>\s*)_MiniStat\(\s*label:\s*'UNREAD ALERTS',\s*value:\s*_compactNumber\(\s*data\['unread_notifications'\]\s*\)\s*\),",re.S)
unread_match=unread_pattern.search(text)
if unread_match is None:
    raise SystemExit('unread-alerts-opens-center: unread alert MiniStat not found')
indent=unread_match.group('indent')
unread_new=f"""{indent}InkWell(
{indent}  borderRadius: BorderRadius.circular(12),
{indent}  onTap: () async {{
{indent}    await showDialog<void>(
{indent}      context: context,
{indent}      builder: (context) => const _NotificationCenterDialog(),
{indent}    );
{indent}    if (mounted) {{
{indent}      setState(() => request = _callRpc('bridgepoint_daily_brief_v74', const {{}}));
{indent}    }}
{indent}  }},
{indent}  child: _MiniStat(
{indent}    label: 'UNREAD ALERTS',
{indent}    value: _compactNumber(data['unread_notifications']),
{indent}  ),
{indent}),"""
text=unread_pattern.sub(unread_new,text,count=1)

# Insert the inbox usage note after the Mark all read row, independent of
# formatting. Do not duplicate it if a later canonical source already has it.
help_copy='Tap any alert to read the full message, source/action target, and timestamp. Opening an unread alert marks it read.'
if help_copy not in text:
    mark_pattern=re.compile(r"(?P<row>Row\(children:\s*\[.*?child:\s*const Text\('Mark all read'\)\)\s*\]\),)\s*const Divider\(\),",re.S)
    mark_match=mark_pattern.search(text)
    if mark_match is None:
        raise SystemExit('notification-center-help: Mark all read row not found')
    replacement=mark_match.group('row')+"\n                      const SizedBox(height: 6),\n                      const Align(\n                        alignment: Alignment.centerLeft,\n                        child: Text(\n                          '"+help_copy+"',\n                          style: TextStyle(\n                            color: AppTheme.textMuted,\n                            fontSize: 9,\n                            height: 1.4,\n                          ),\n                        ),\n                      ),\n                      const Divider(),"
    text=mark_pattern.sub(replacement,text,count=1)

# v801: target the notification itemBuilder structurally. This avoids one-line
# vs dart-format drift while still refusing to touch unrelated ListViews.
row_pattern=re.compile(
    r"itemBuilder:\s*\(context,\s*i\)\s*\{\s*"
    r"final n\s*=\s*items\[i\];\s*"
    r"final unread\s*=\s*n\['read_at'\]\s*==\s*null;\s*"
    r"return ListTile\(.*?"
    r"trailing:\s*unread\s*\?\s*const Icon\(Icons\.circle,\s*color:\s*AppTheme\.cyan,\s*size:\s*8\)\s*:\s*null\);\s*"
    r"\}",
    re.S,
)
row_match=row_pattern.search(text)
if row_match is None:
    raise SystemExit('notification-rows-interactive: notification itemBuilder not found')
row_new=r'''itemBuilder: (context, i) {
                                        final n = items[i];
                                        final unread = n['read_at'] == null;
                                        final created = DateTime.tryParse(
                                                '${n['created_at'] ?? ''}')
                                            ?.toLocal();
                                        final createdLabel = created == null
                                            ? 'Time unavailable'
                                            : '${created.month}/${created.day}/${created.year} • ${(created.hour % 12) == 0 ? 12 : created.hour % 12}:${created.minute.toString().padLeft(2, '0')} ${created.hour >= 12 ? 'PM' : 'AM'}';
                                        final action =
                                            '${n['action_page'] ?? ''}'.trim();
                                        return ListTile(
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                  vertical: 4),
                                          leading: CircleAvatar(
                                            backgroundColor: (unread
                                                    ? AppTheme.cyan
                                                    : AppTheme.textMuted)
                                                .withOpacity(.12),
                                            child: Icon(
                                              _notificationIcon(
                                                  '${n['notification_type']}'),
                                              color: unread
                                                  ? AppTheme.cyan
                                                  : AppTheme.textMuted,
                                              size: 20,
                                            ),
                                          ),
                                          title: Text(
                                            '${n['title']}',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: unread
                                                  ? FontWeight.w800
                                                  : FontWeight.w500,
                                            ),
                                          ),
                                          subtitle: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const SizedBox(height: 3),
                                              Text(
                                                '${n['message']}',
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: AppTheme.textMuted,
                                                  fontSize: 10,
                                                  height: 1.4,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '$createdLabel${action.isEmpty ? '' : ' • ${action.replaceAll('_', ' ').toUpperCase()}'}',
                                                style: const TextStyle(
                                                  color: AppTheme.textMuted,
                                                  fontSize: 8,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ],
                                          ),
                                          trailing: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              if (unread) ...[
                                                const Icon(Icons.circle,
                                                    color: AppTheme.cyan,
                                                    size: 8),
                                                const SizedBox(width: 8),
                                              ],
                                              const Icon(
                                                  Icons.chevron_right_rounded,
                                                  color: AppTheme.textMuted),
                                            ],
                                          ),
                                          onTap: () async {
                                            if (unread) {
                                              try {
                                                await _callRpc(
                                                  'bridgepoint_mark_notifications_read_v74',
                                                  {
                                                    'p_notification_id':
                                                        n['notification_id']
                                                  },
                                                );
                                              } catch (_) {
                                                // Detail still opens even if read-state persistence fails.
                                              }
                                            }
                                            if (!mounted) return;
                                            await showDialog<void>(
                                              context: context,
                                              builder: (detailContext) =>
                                                  AlertDialog(
                                                backgroundColor: AppTheme.panel,
                                                title: Row(
                                                  children: [
                                                    Icon(
                                                      _notificationIcon(
                                                          '${n['notification_type']}'),
                                                      color: AppTheme.cyan,
                                                    ),
                                                    const SizedBox(width: 9),
                                                    Expanded(
                                                        child: Text(
                                                            '${n['title']}')),
                                                  ],
                                                ),
                                                content: SizedBox(
                                                  width: 580,
                                                  child: Column(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        '${n['message']}',
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 11,
                                                          height: 1.55,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 14),
                                                      Container(
                                                        width: double.infinity,
                                                        padding:
                                                            const EdgeInsets.all(
                                                                11),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: AppTheme
                                                              .panelSoft,
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(10),
                                                        ),
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Text(
                                                              'TYPE • ${'${n['notification_type'] ?? 'ALERT'}'.replaceAll('_', ' ')}',
                                                              style:
                                                                  const TextStyle(
                                                                color: AppTheme
                                                                    .cyan,
                                                                fontSize: 9,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w900,
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                                height: 5),
                                                            Text(
                                                              'WHEN • $createdLabel',
                                                              style:
                                                                  const TextStyle(
                                                                color: AppTheme
                                                                    .textMuted,
                                                                fontSize: 9,
                                                              ),
                                                            ),
                                                            if (action
                                                                .isNotEmpty) ...[
                                                              const SizedBox(
                                                                  height: 5),
                                                              Text(
                                                                'RELATED AREA • ${action.replaceAll('_', ' ').toUpperCase()}',
                                                                style:
                                                                    const TextStyle(
                                                                  color: AppTheme
                                                                      .textMuted,
                                                                  fontSize: 9,
                                                                ),
                                                              ),
                                                            ],
                                                            if (n['action_id'] !=
                                                                null) ...[
                                                              const SizedBox(
                                                                  height: 5),
                                                              Text(
                                                                'REFERENCE • ${n['action_id']}',
                                                                style:
                                                                    const TextStyle(
                                                                  color: AppTheme
                                                                      .textMuted,
                                                                  fontSize: 8,
                                                                ),
                                                              ),
                                                            ],
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                            detailContext),
                                                    child: const Text('Done'),
                                                  ),
                                                ],
                                              ),
                                            );
                                            if (mounted) {
                                              setState(() => request = _load());
                                            }
                                          },
                                        );
                                      }'''
text=row_pattern.sub(row_new,text,count=1)

if text==original:
    raise SystemExit('No notification center changes applied')
path.write_text(text,encoding='utf-8')
print('Applied BridgePoint notification center patch v109/v801')
