from pathlib import Path
import re

path = Path('lib/main.dart')
text = path.read_text(encoding='utf-8')
original = text

# v802: Pull the verified auth + telemetry people list returned by
# owner_dashboard_v84 without depending on dart-format line wrapping.
data_pattern = re.compile(
    r"(?P<prefix>final offer\s*=\s*map\(data\['founding_offer'\]\),\s*"
    r"intel\s*=\s*map\(data\['intelligence'\]\);\s*"
    r"final verticals\s*=\s*rows\(data\['top_opportunity_verticals'\]\),\s*"
    r"failures\s*=\s*rows\(data\['recent_failures'\]\);)",
    re.S,
)
match = data_pattern.search(text)
if match is None:
    raise SystemExit('owner-recent-people-data: owner payload block not found')
text = data_pattern.sub(
    match.group('prefix') + "\n          final recentPeople = rows(usage['recent_people']);",
    text,
    count=1,
)

# Clarify that USING NOW combines heartbeat + authenticated evidence.
active_pattern = re.compile(
    r"_MetricCard\(\s*width:\s*w,\s*label:\s*'USING NOW',\s*"
    r"value:\s*_formatInteger\(usage\['active_now'\]\s*\?\?\s*0\),\s*"
    r"detail:\s*'Active during the last 5 minutes',\s*"
    r"icon:\s*Icons\.online_prediction_rounded,\s*accent:\s*AppTheme\.cyan\s*\)",
    re.S,
)
if active_pattern.search(text) is None:
    raise SystemExit('owner-active-now-copy: USING NOW metric not found')
text = active_pattern.sub(
    """_MetricCard(
                        width: w,
                        label: 'USING NOW',
                        value: _formatInteger(usage['active_now'] ?? 0),
                        detail: 'Heartbeat + very recent authenticated sign-ins',
                        icon: Icons.online_prediction_rounded,
                        accent: AppTheme.cyan)""",
    text,
    count=1,
)

panel = r'''        const SizedBox(height: 18),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _PanelHeader(
                  title: 'Recent People Using BridgePoint',
                  subtitle: 'Verified Supabase sign-ins + BridgePoint session/activity telemetry',
                  action: 'Last 30 days',
                ),
                const SizedBox(height: 8),
                const Text(
                  'A real sign-in is counted even if the browser never sends a heartbeat. When telemetry is available, BridgePoint also shows the last page and last activity time.',
                  style: TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 9.5,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 12),
                if (recentPeople.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(18),
                    child: Text(
                      'No verified sign-ins or BridgePoint activity have been recorded yet.',
                      style: TextStyle(color: AppTheme.textMuted),
                    ),
                  )
                else
                  ...recentPeople.take(20).map((person) {
                    final status = '${person['presence_status'] ?? 'RECENT'}';
                    final color = status == 'ACTIVE_NOW'
                        ? AppTheme.green
                        : status == 'TODAY'
                            ? AppTheme.cyan
                            : status == 'THIS_WEEK'
                                ? AppTheme.blue
                                : AppTheme.textMuted;
                    final seen = DateTime.tryParse(
                            '${person['last_seen_at'] ?? person['last_sign_in_at'] ?? person['account_created_at'] ?? ''}')
                        ?.toLocal();
                    final seenLabel = seen == null
                        ? 'No activity timestamp'
                        : '${seen.month}/${seen.day} • ${(seen.hour % 12) == 0 ? 12 : seen.hour % 12}:${seen.minute.toString().padLeft(2, '0')} ${seen.hour >= 12 ? 'PM' : 'AM'}';
                    final page = '${person['last_page'] ?? ''}'.trim();
                    final source = '${person['tracking_source'] ?? 'AUTH'}'
                        .replaceAll('_', ' ');
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.panelSoft.withOpacity(.5),
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(color: color.withOpacity(.12)),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: color.withOpacity(.12),
                            child: Icon(
                              status == 'ACTIVE_NOW'
                                  ? Icons.person_pin_circle_rounded
                                  : Icons.person_outline_rounded,
                              color: color,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${person['display_name'] ?? person['email'] ?? 'BridgePoint user'}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${person['email'] ?? ''}',
                                  style: const TextStyle(
                                    color: AppTheme.textMuted,
                                    fontSize: 9,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '$seenLabel${page.isEmpty ? '' : ' • last page: $page'} • $source',
                                  style: const TextStyle(
                                    color: AppTheme.textMuted,
                                    fontSize: 8.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _OpportunityChip(
                            label: status.replaceAll('_', ' '),
                            color: color,
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
'''

# Insert immediately before the Stripe payout card using the semantic title as
# the locator, then back up to the nearest preceding section spacer.
payout_title = "Text('Stripe payout readiness'"
payout_index = text.find(payout_title)
if payout_index < 0:
    raise SystemExit('owner payout insertion marker: Stripe payout card not found')
spacer_token = 'const SizedBox(height: 18),'
spacer_index = text.rfind(spacer_token, 0, payout_index)
if spacer_index < 0:
    raise SystemExit('owner payout insertion marker: preceding section spacer not found')
line_start = text.rfind('\n', 0, spacer_index) + 1
text = text[:line_start] + panel + text[line_start:]

if text == original:
    raise SystemExit('No owner recent-user changes applied')
path.write_text(text, encoding='utf-8')
print('Applied BridgePoint owner recent-people patch v112/v802')
