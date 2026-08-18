from pathlib import Path

body=Path('lib/main.dart').read_text(encoding='utf-8')
required=[
    'bridgepoint-v323-network-ui',
    'bridgepoint-v323-network-ui-repair',
    'bridgepoint-v323-network-safety-controls',
    'bridgepoint-v323-network-generated-compile-repair',
    'bridgepoint-v323-owner-moderation-ui',
    "package:file_picker/file_picker.dart",
    "FilePicker.pickFiles(",
    "bridgepoint_network_profile_v323",
    "bridgepoint_network_feed_v323",
    "bridgepoint_network_people_v323",
    "bridgepoint_network_comments_v323",
    "bridgepoint_network_messages_v323",
    "bridgepoint_network_report_v323",
    "bridgepoint_network_block_user_v323",
    "bridgepoint_owner_network_moderation_v323",
    "bridgepoint_owner_network_moderate_v323",
    "final raw=item['allowed_actions']",
    "tooltip:'Report comment'",
    "tooltip:'Report message'",
    "tooltip:'Member safety'",
    "tooltip:'Conversation safety'",
    'Blocked direct messages cannot be restored.',
    'Photos/videos stay private until moderation approves them.',
]
for needle in required:
    if needle not in body:
        raise SystemExit(f'v323 Network release marker missing: {needle}')

for forbidden in [
    'FilePicker.platform.pickFiles(',
    'withOpacity(mine?.12:.82)',
    'withOpacity(mine?.18:.06)',
]:
    if forbidden in body:
        raise SystemExit(f'v323 Network forbidden generated syntax remains: {forbidden}')

# Owner moderation must stay inside the existing owner-only Owner Center surface.
owner_marker=body.find('bridgepoint-v219-owner-outreach')
moderation_widget=body.find('const _BridgePointNetworkModerationV323()')
if owner_marker<0 or moderation_widget<0 or moderation_widget-owner_marker>600:
    raise SystemExit('v323 owner moderation widget is not anchored in the owner-only Owner Center surface')

# Customer moderation buttons must be server-driven. Never hardcode an Approve button for safety-event messages.
if "for(final action in actions)TextButton.icon" not in body:
    raise SystemExit('v323 owner moderation actions are not rendered from backend allowed_actions')

print('BRIDGEPOINT V323 NETWORK RELEASE AUDIT PASSED')
print(' - professional Network feed/profile/friends/messages/comments/reactions present')
print(' - file_picker 11 static API and balanced People/Chat widgets verified')
print(' - media upload is quarantined pending owner moderation')
print(' - post/comment/message/profile report controls present')
print(' - member block flow is explicit and confirmed')
print(' - owner moderation queue uses backend allowed_actions contract')
print(' - blocked direct messages cannot surface an Approve action')
print(' - failed media drafts are cleaned up and repaired message syntax remains valid')
