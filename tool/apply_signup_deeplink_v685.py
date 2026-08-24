#!/usr/bin/env python3
"""V685: make public trial/create deep links open the account-creation form directly.

This is intentionally idempotent. It patches the canonical Dart source once and is
also safe to run against generated source during release hardening.
"""
from pathlib import Path

PATH = Path("lib/main.dart")
MARKER = "bridgepoint-v685-signup-deeplink"

source = PATH.read_text(encoding="utf-8")
if MARKER in source:
    print("V685 signup deep-link migration already present.")
    raise SystemExit(0)

needle = """class _AuthScreenState extends State<_AuthScreen> {\n  final displayName=TextEditingController(); final email=TextEditingController(); final password=TextEditingController();\n  bool create=false,loading=false,showPassword=false,acceptTerms=false; String? error;\n  Future<void> submit() async {"""
replacement = """class _AuthScreenState extends State<_AuthScreen> {\n  // bridgepoint-v685-signup-deeplink\n  final displayName=TextEditingController(); final email=TextEditingController(); final password=TextEditingController();\n  bool create=false,loading=false,showPassword=false,acceptTerms=false; String? error;\n\n  @override\n  void initState(){\n    super.initState();\n    final mode=(Uri.base.queryParameters['mode']??'').trim().toLowerCase();\n    create=mode=='signup'||mode=='create'||mode=='trial';\n  }\n\n  Future<void> submit() async {"""

if needle not in source:
    raise SystemExit("V685 could not locate the canonical _AuthScreenState block; refusing a blind patch.")

source = source.replace(needle, replacement, 1)
PATH.write_text(source, encoding="utf-8")

check = PATH.read_text(encoding="utf-8")
required = [
    MARKER,
    "Uri.base.queryParameters['mode']",
    "mode=='signup'||mode=='create'||mode=='trial'",
    "create=mode=='signup'||mode=='create'||mode=='trial'",
]
missing = [item for item in required if item not in check]
if missing:
    raise SystemExit(f"V685 verification failed: {missing}")
print("Applied V685 signup deep-link migration.")
