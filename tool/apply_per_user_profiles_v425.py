from pathlib import Path
import re

path = Path('lib/main.dart')
body = path.read_text(encoding='utf-8')
marker = 'bridgepoint-v425-per-user-profiles'

if marker in body:
    print('v425 per-user profile layer already applied')
    raise SystemExit(0)

# The legacy top bar rendered the founder initials for every authenticated session.
# Replace only those two known header avatars and fail closed if release-source drift
# changes the contract instead of silently shipping an identity leak.
pattern = re.compile(
    r"const\s+CircleAvatar\(\s*"
    r"radius:\s*(?P<radius>18|19),\s*"
    r"backgroundColor:\s*AppTheme\.blue,\s*"
    r"child:\s*Text\(\s*"
    r"'KJ',\s*"
    r"style:\s*TextStyle\(\s*"
    r"color:\s*Colors\.white,\s*"
    r"fontWeight:\s*FontWeight\.w800,\s*"
    r"fontSize:\s*(?:11|12),\s*"
    r"\),\s*"
    r"\),\s*"
    r"\)",
    re.S,
)

body, replaced = pattern.subn(
    lambda match: f"_AccountProfileButtonV425(radius: {match.group('radius')})",
    body,
)

if replaced != 2:
    raise SystemExit(
        f'v425 profile guard expected exactly 2 hard-coded KJ header avatars, found {replaced}'
    )

profile_widget = r'''

// bridgepoint-v425-per-user-profiles
// Every signed-in account owns its own header identity. Never fall back to the
// founder's name/initials for another authenticated user.
class _AccountProfileButtonV425 extends StatefulWidget {
  const _AccountProfileButtonV425({required this.radius});

  final double radius;

  @override
  State<_AccountProfileButtonV425> createState() =>
      _AccountProfileButtonV425State();
}

class _AccountProfileButtonV425State extends State<_AccountProfileButtonV425> {
  User? get _user => Supabase.instance.client.auth.currentUser;

  String _displayName(User? user) {
    final metadataName = '${user?.userMetadata?['display_name'] ?? ''}'.trim();
    if (metadataName.isNotEmpty) return metadataName;

    final email = (user?.email ?? '').trim();
    if (email.isNotEmpty) {
      final local = email.split('@').first.replaceAll(RegExp(r'[._-]+'), ' ').trim();
      if (local.isNotEmpty) {
        return local
            .split(RegExp(r'\s+'))
            .where((part) => part.isNotEmpty)
            .map((part) => part.length == 1
                ? part.toUpperCase()
                : '${part[0].toUpperCase()}${part.substring(1)}')
            .join(' ');
      }
    }
    return 'My profile';
  }

  String _initials(User? user) {
    final value = _displayName(user).trim();
    if (value.isEmpty || value == 'My profile') return '?';
    final parts = value.split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final one = parts.first;
      return one.substring(0, one.length >= 2 ? 2 : 1).toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  String _colorKey(User? user) {
    final value = '${user?.userMetadata?['profile_color'] ?? 'blue'}'.toLowerCase();
    return const {'blue', 'cyan', 'green', 'amber'}.contains(value) ? value : 'blue';
  }

  Color _profileColor(String key) {
    switch (key) {
      case 'cyan':
        return AppTheme.cyan;
      case 'green':
        return AppTheme.green;
      case 'amber':
        return AppTheme.amber;
      default:
        return AppTheme.blue;
    }
  }

  Future<void> _editProfile() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return;

    final nameController = TextEditingController(text: _displayName(user));
    var selectedColor = _colorKey(user);

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.account_circle_outlined, color: AppTheme.cyan),
              SizedBox(width: 10),
              Text('My profile'),
            ],
          ),
          content: SizedBox(
            width: 390,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This profile belongs only to your signed-in account. Your name and avatar are never borrowed from another user.',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 11, height: 1.45),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  maxLength: 60,
                  decoration: const InputDecoration(
                    labelText: 'Profile name',
                    hintText: 'Your name or nickname',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Avatar color',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ['blue', 'cyan', 'green', 'amber'].map((key) {
                    final selected = selectedColor == key;
                    return ChoiceChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(radius: 6, backgroundColor: _profileColor(key)),
                          const SizedBox(width: 7),
                          Text(key[0].toUpperCase() + key.substring(1)),
                        ],
                      ),
                      selected: selected,
                      onSelected: (_) => setDialogState(() => selectedColor = key),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),
                Text(
                  user.email ?? '',
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 10),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('Enter a profile name first.')),
                  );
                  return;
                }
                Navigator.of(dialogContext).pop({
                  'display_name': name,
                  'profile_color': selectedColor,
                });
              },
              icon: const Icon(Icons.save_outlined),
              label: const Text('Save profile'),
            ),
          ],
        ),
      ),
    );

    nameController.dispose();
    if (result == null) return;

    try {
      await client.auth.updateUser(UserAttributes(data: result));
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your BridgePoint profile was updated.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update profile: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    if (user == null) {
      return CircleAvatar(
        radius: widget.radius,
        backgroundColor: AppTheme.panelSoft,
        child: const Icon(Icons.person_outline_rounded, color: AppTheme.textMuted, size: 18),
      );
    }

    final name = _displayName(user);
    final color = _profileColor(_colorKey(user));
    return Tooltip(
      message: 'Profile • $name',
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: _editProfile,
          child: CircleAvatar(
            radius: widget.radius,
            backgroundColor: color,
            child: Text(
              _initials(user),
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: widget.radius <= 18 ? 11 : 12,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
'''

body += profile_widget

if "'KJ'" in body:
    raise SystemExit('v425 privacy guard failed: hard-coded KJ identity remains in generated app source')
if body.count('_AccountProfileButtonV425(radius:') != 2:
    raise SystemExit('v425 privacy guard failed: both top-bar profile positions were not converted')

path.write_text(body, encoding='utf-8')
print('Applied v425 per-user profiles: removed hard-coded founder avatar, enabled per-account profile editing')
