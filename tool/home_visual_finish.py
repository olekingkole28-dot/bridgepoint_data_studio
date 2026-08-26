from pathlib import Path

p = Path('lib/v2/bridgepoint_home_live_v2.dart')
s = p.read_text(encoding='utf-8')

s = s.replace(
    "style: TextStyle(color: _muted, fontSize: 14, height: 1.55)",
    "style: TextStyle(color: _muted, fontSize: 15, height: 1.55, fontWeight: FontWeight.w600)",
)

old_card = """decoration: BoxDecoration(color: _BridgePointHomeLiveV2State._panel, borderRadius: BorderRadius.circular(17), border: Border.all(color: data.color.withValues(alpha: .14))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Container(width: 40, height: 40, decoration: BoxDecoration(color: data.color.withValues(alpha: .10), borderRadius: BorderRadius.circular(12)), child: Icon(data.icon, color: data.color)), const Spacer(), const Icon(Icons.chevron_right_rounded, color: _BridgePointHomeLiveV2State._muted)]),
            const SizedBox(height: 13),
            Text(data.label, style: const TextStyle(color: _BridgePointHomeLiveV2State._muted, fontSize: 11.5, fontWeight: FontWeight.w900, letterSpacing: .8)),
            const SizedBox(height: 4),
            Text(data.value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 5),
            Text(data.detail, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _BridgePointHomeLiveV2State._muted, fontSize: 12.5, height: 1.35)),
          ]),"""
new_card = """decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                data.color.withValues(alpha: .13),
                _BridgePointHomeLiveV2State._panel,
                _BridgePointHomeLiveV2State._panel,
              ],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: data.color.withValues(alpha: .28)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x2A000000),
                blurRadius: 18,
                offset: Offset(0, 7),
              ),
            ],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: data.color.withValues(alpha: .18),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: data.color.withValues(alpha: .26)),
                ),
                child: Icon(data.icon, color: data.color, size: 23),
              ),
              const Spacer(),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: data.color.withValues(alpha: .10),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.arrow_forward_rounded, color: data.color, size: 19),
              ),
            ]),
            const SizedBox(height: 14),
            Text(data.label, style: const TextStyle(color: _BridgePointHomeLiveV2State._muted, fontSize: 12.25, fontWeight: FontWeight.w900, letterSpacing: .85)),
            const SizedBox(height: 5),
            Text(data.value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900, letterSpacing: -.35)),
            const SizedBox(height: 6),
            Text(data.detail, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _BridgePointHomeLiveV2State._muted, fontSize: 13, fontWeight: FontWeight.w600, height: 1.4)),
          ]),"""
if old_card not in s:
    raise SystemExit('Home card contract changed; refusing blind patch')
s = s.replace(old_card, new_card)

s = s.replace(
    "style: const TextStyle(color: _BridgePointHomeLiveV2State._muted, fontSize: 9)",
    "style: const TextStyle(color: _BridgePointHomeLiveV2State._muted, fontSize: 13, fontWeight: FontWeight.w700, height: 1.3)",
)

s = s.replace(
    "Text(subtitle, style: const TextStyle(color: _BridgePointHomeLiveV2State._muted, fontSize: 10))",
    "Text(subtitle, style: const TextStyle(color: _BridgePointHomeLiveV2State._muted, fontSize: 12.75, fontWeight: FontWeight.w700, height: 1.35))",
)

s = s.replace(
    "decoration: BoxDecoration(color: _BridgePointHomeLiveV2State._soft.withValues(alpha: .68), borderRadius: BorderRadius.circular(12)),",
    "decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF16324E), Color(0xFF0E2035)]), borderRadius: BorderRadius.circular(13), border: Border.all(color: _BridgePointHomeLiveV2State._cyan.withValues(alpha: .10))),",
)

s = s.replace(
    "child: Row(children: [Icon(icon, color: _BridgePointHomeLiveV2State._cyan), const SizedBox(width: 9),",
    "child: Row(children: [Container(width: 38, height: 38, decoration: BoxDecoration(color: _BridgePointHomeLiveV2State._cyan.withValues(alpha: .12), borderRadius: BorderRadius.circular(11)), child: Icon(icon, color: _BridgePointHomeLiveV2State._cyan, size: 21)), const SizedBox(width: 10),",
)

p.write_text(s, encoding='utf-8')
print('Home visual finish applied: readable feed text, richer metric cards, stronger panel hierarchy.')
