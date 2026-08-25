from pathlib import Path

path = Path('lib/main.dart')
text = path.read_text(encoding='utf-8')

# This compatibility layer belongs to the authoritative v735 normalization. It restores
# the older secure convenience after canonical auth is re-applied, while preserving the
# newer mode=signup|create|trial deep-link behavior. Only email/nickname are stored.
const_anchor = "const _bridgePointLiveUrl = 'https://bridgepointintelligence.online';\n"
const_block = """const _bpRememberInfoKey='bridgepoint_remember_info_v1';
const _bpRememberEmailKey='bridgepoint_remember_email_v1';
const _bpRememberNicknameKey='bridgepoint_remember_nickname_v1';
"""
if '_bpRememberInfoKey' not in text:
    if text.count(const_anchor) != 1:
        raise SystemExit(f'v735 remember auth: live URL anchor count={text.count(const_anchor)}')
    text = text.replace(const_anchor, const_anchor + const_block, 1)

start = text.find('class _AuthScreenState extends State<_AuthScreen> {')
end = text.find('class _PublicLegalSummaryDialog', start)
if start < 0 or end < 0:
    raise SystemExit('v735 remember auth: AuthScreenState boundaries missing')
block = text[start:end]

fields_old = """  // bridgepoint-v685-signup-deeplink
  final displayName=TextEditingController(); final email=TextEditingController(); final password=TextEditingController();
  bool create=false,loading=false,showPassword=false,acceptTerms=false; String? error;
"""
fields_new = """  // bridgepoint-v685-signup-deeplink
  // bridgepoint-v735-secure-remembered-auth
  final displayName=TextEditingController(); final email=TextEditingController(); final password=TextEditingController();
  bool create=false,loading=false,showPassword=false,acceptTerms=false,rememberInfo=false; String? error;
"""
if 'bridgepoint-v735-secure-remembered-auth' not in block:
    if block.count(fields_old) != 1:
        raise SystemExit(f'v735 remember auth: field anchor count={block.count(fields_old)}')
    block = block.replace(fields_old, fields_new, 1)

init_old = """  @override
  void initState(){
    super.initState();
    final mode=(Uri.base.queryParameters['mode']??'').trim().toLowerCase();
    create=mode=='signup'||mode=='create'||mode=='trial';
  }

"""
init_new = """  @override
  void initState(){
    super.initState();
    final mode=(Uri.base.queryParameters['mode']??'').trim().toLowerCase();
    create=mode=='signup'||mode=='create'||mode=='trial';
    unawaited(_loadRememberedInfo());
  }

  Future<void> _loadRememberedInfo()async{
    final prefs=await SharedPreferences.getInstance();
    final remember=prefs.getBool(_bpRememberInfoKey)??false;
    if(!remember||!mounted)return;
    email.text=prefs.getString(_bpRememberEmailKey)??'';
    displayName.text=prefs.getString(_bpRememberNicknameKey)??'';
    setState(()=>rememberInfo=true);
  }

  Future<void> _persistRememberedInfo()async{
    final prefs=await SharedPreferences.getInstance();
    await prefs.setBool(_bpRememberInfoKey,rememberInfo);
    if(rememberInfo){
      await prefs.setString(_bpRememberEmailKey,email.text.trim());
      final user=Supabase.instance.client.auth.currentUser;
      final meta=user?.userMetadata??const <String,dynamic>{};
      final nickname=(displayName.text.trim().isNotEmpty
          ? displayName.text.trim()
          : '${meta['nickname']??meta['display_name']??''}'.trim());
      await prefs.setString(_bpRememberNicknameKey,nickname);
    }else{
      await prefs.remove(_bpRememberEmailKey);
      await prefs.remove(_bpRememberNicknameKey);
    }
  }

"""
if '_loadRememberedInfo()' not in block:
    if block.count(init_old) != 1:
        raise SystemExit(f'v735 remember auth: init/deeplink anchor count={block.count(init_old)}')
    block = block.replace(init_old, init_new, 1)

signup_old = """        final response=await Supabase.instance.client.auth.signUp(email:email.text.trim(),password:password.text,
          data:{'display_name':displayName.text.trim(),'legal_accepted':true,'legal_version':'2026-08-15'});
        if(response.session==null&&mounted) setState(()=>error='Check your email to confirm the account, then sign in.');
      } else {
        await Supabase.instance.client.auth.signInWithPassword(email:email.text.trim(),password:password.text);
      }
"""
signup_new = """        final nickname=displayName.text.trim();
        final response=await Supabase.instance.client.auth.signUp(email:email.text.trim(),password:password.text,
          data:{'display_name':nickname,'nickname':nickname,'legal_accepted':true,'legal_version':'2026-08-15'});
        await _persistRememberedInfo();
        if(response.session==null&&mounted) setState(()=>error='Check your email to confirm the account, then sign in.');
      } else {
        await Supabase.instance.client.auth.signInWithPassword(email:email.text.trim(),password:password.text);
        final meta=Supabase.instance.client.auth.currentUser?.userMetadata??const <String,dynamic>{};
        if(displayName.text.trim().isEmpty)displayName.text='${meta['nickname']??meta['display_name']??''}'.trim();
        await _persistRememberedInfo();
      }
"""
if 'await _persistRememberedInfo();' not in block:
    if block.count(signup_old) != 1:
        raise SystemExit(f'v735 remember auth: submit anchor count={block.count(signup_old)}')
    block = block.replace(signup_old, signup_new, 1)

block = block.replace(
    "labelText:'Profile name',hintText:'How BridgePoint should welcome you'",
    "labelText:'Nickname / profile name',hintText:'What should BridgePoint call you?'",
    1,
)

remember_title = 'Save my info for next time'
if remember_title not in block:
    terms_anchor = """      ),
      if(create)...[const SizedBox(height:10),CheckboxListTile(
"""
    remember_ui = """      ),
      const SizedBox(height:8),CheckboxListTile(
        contentPadding:EdgeInsets.zero,
        controlAffinity:ListTileControlAffinity.leading,
        value:rememberInfo,
        onChanged:loading?null:(v)=>setState(()=>rememberInfo=v==true),
        title:const Text('Save my info for next time',style:TextStyle(fontSize:10.5,fontWeight:FontWeight.w800)),
        subtitle:const Text('Remembers your email and nickname on this device. BridgePoint never stores your password here.',style:TextStyle(color:AppTheme.textMuted,fontSize:8.5,height:1.35)),
      ),
      if(create)...[const SizedBox(height:10),CheckboxListTile(
"""
    if block.count(terms_anchor) != 1:
        raise SystemExit(f'v735 remember auth: remember checkbox anchor count={block.count(terms_anchor)}')
    block = block.replace(terms_anchor, remember_ui, 1)

# Contract: preserve both generations of auth behavior, and explicitly forbid local password persistence.
required = [
    'bridgepoint-v685-signup-deeplink',
    'bridgepoint-v735-secure-remembered-auth',
    "create=mode=='signup'||mode=='create'||mode=='trial'",
    'unawaited(_loadRememberedInfo())',
    '_persistRememberedInfo()',
    'Save my info for next time',
    'Remembers your email and nickname on this device. BridgePoint never stores your password here.',
]
missing = [needle for needle in required if needle not in block]
if missing:
    raise SystemExit(f'v735 remember auth contract missing: {missing}')
for forbidden in (
    "prefs.setString('password'",
    'prefs.setString(_bpRememberPassword',
    'bridgepoint_remember_password',
):
    if forbidden in text or forbidden in block:
        raise SystemExit(f'v735 remember auth: forbidden password persistence detected: {forbidden}')

text = text[:start] + block + text[end:]
path.write_text(text, encoding='utf-8')
print('Restored secure remembered email/nickname while preserving v685 signup deep-link behavior; password persistence remains forbidden.')
