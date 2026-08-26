from pathlib import Path

p = Path('lib/v2/bridgepoint_property_dossier_v2.dart')
s = p.read_text()

s = s.replace(
"""    required this.propertyId,
    required this.seed,
  });

  final String propertyId;
  final Map<String, dynamic> seed;
""",
"""    required this.propertyId,
    required this.seed,
    this.asPage = false,
  });

  final String propertyId;
  final Map<String, dynamic> seed;
  final bool asPage;
""",
1,
)

old = """  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: .95,
        child: FutureBuilder<List<dynamic>>(
"""
new = """  @override
  Widget build(BuildContext context) {
    final content = FutureBuilder<List<dynamic>>(
"""
if old not in s:
    raise SystemExit('dossier build root contract changed')
s = s.replace(old, new, 1)

old_tail = """          },
        ),
      ),
    );
  }
}

class _SignedPhoto"""
new_tail = """          },
        );

    if (widget.asPage) {
      return Scaffold(
        backgroundColor: const Color(0xFF040B14),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF05111F), Color(0xFF071B2B), Color(0xFF040B14)],
            ),
          ),
          child: SafeArea(child: content),
        ),
      );
    }
    return SafeArea(
      child: FractionallySizedBox(heightFactor: .95, child: content),
    );
  }
}

class _SignedPhoto"""
if old_tail not in s:
    raise SystemExit('dossier build tail contract changed')
s = s.replace(old_tail, new_tail, 1)

s = s.replace(
"""                        icon: const Icon(Icons.close_rounded),
""",
"""                        icon: Icon(widget.asPage ? Icons.arrow_back_rounded : Icons.close_rounded),
""",
1,
)
p.write_text(s)

for file in ['lib/v2/bridgepoint_properties_v2.dart','lib/v2/bridgepoint_investor_v2.dart']:
    p = Path(file)
    s = p.read_text()
    if 'showModalBottomSheet<void>(' in s:
        if file.endswith('bridgepoint_properties_v2.dart'):
            old = """    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => BridgePointPropertyDossierV2(propertyId: id, seed: property),
    );
"""
            new = """    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => BridgePointPropertyDossierV2(
          propertyId: id,
          seed: property,
          asPage: true,
        ),
      ),
    );
"""
        else:
            old = """    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => BridgePointPropertyDossierV2(
        propertyId: propertyId,
        seed: row,
      ),
    );
"""
            new = """    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => BridgePointPropertyDossierV2(
          propertyId: propertyId,
          seed: row,
          asPage: true,
        ),
      ),
    );
"""
        if old not in s:
            raise SystemExit(f'navigation contract changed: {file}')
        s = s.replace(old,new,1)
    p.write_text(s)

print('Full-screen property dossier wired')
