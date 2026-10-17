from pathlib import Path

path=Path('lib/main.dart')
text=path.read_text(encoding='utf-8')
start=text.find('class _AuthScreenState extends State<_AuthScreen> {')
end=text.find('class _PublicLegalSummaryDialog',start)
if start<0 or end<0:
    raise SystemExit('v735 remembered auth: AuthScreenState boundaries missing')
block=text[start:end]

api_marker="const _supabaseUrl = 'https://xdfsjztwgsbmabshzsjw.supabase.co';\n"
if '_bpRememberInfoKey' not in text:
    if api_marker not in text:
        raise SystemExit('v735 remembered auth: Supabase URL anchor missing')
    text=text.replace(api_marker,api_marker+"const _bpRememberInfoKey='bridgepoint_remember_info_v1';\nconst _bpRememberEmailKey='bridgepoint_remember_email_v1';\nconst _bpRememberNicknameKey='bridgepoint_remember_nickname_v1';\n",1)
    start=text.find('class _AuthScreenState extends State<_AuthScreen> {')
    end=text.find('class _PublicLegalSummaryDialog',start)
    block=text[start:end]

# Use the same v735 marker as the later restore validator so this repair remains
# idempotent even when the final avatar layer re-checks remembered-auth compatibility.
if 'bridgepoint-v735-secure-remembered-auth' not in block:
    fields_old="""  // bridgepoint-v685-signup-deeplink
  final displayName=TextEditingController(); final email=TextEditingController(); final password=TextEditingController();
  bool create=false,loading=false,showPassword=false,acceptTerms=false; String? error;
"""
    fields_new="""  // bridgepoint-v685-signup-deeplink
  // bridgepoint-v735-secure-remembered-auth
  final displayName=TextEditingController(); final email=TextEditingController(); final password=TextEditingController();
  bool create=false,loading=false,showPassword=false,acceptTerms=false,rememberInfo=false; String? error;
"""
    if fields_old in block:
        block=block.replace(fields_old,fields_new,1)
    elif 'rememberInfo=false' in block:
        anchor='  // bridgepoint-v685-signup-deeplink\n'
        if anchor not in block:
            raise SystemExit('v735 remembered auth: signup marker missing while rememberInfo already exists')
        block=block.replace(anchor,anchor+'  // bridgepoint-v735-secure-remembered-auth\n',1)
    else:
        raise SystemExit('v735 remembered auth: auth boolean field anchor missing')

if 'rememberInfo=false' not in block:
    old="  bool create=false,loading=false,showPassword=false,acceptTerms=false; String? error;\n"
    new="  bool create=false,loading=false,showPassword=false,acceptTerms=false,rememberInfo=false; String? error;\n"
    if old not in block:
        raise SystemExit('v735 remembered auth: auth boolean field anchor missing')
    block=block.replace(old,new,1)

if 'Future<void> _loadRememberedInfo()' not in block:
    init_anchor="""  @override
  void initState(){
    super.initState();
    final mode=(Uri.base.queryParameters['mode']??'').trim().toLowerCase();
    create=mode=='signup'||mode=='create'||mode=='trial';
  }

"""
    init_new="""  @override
  void initState(){
    super.initState();
    final mode=(Uri.base.queryParameters['mode']??'').trim().toLowerCase();
    create=mode=='signup'||mode=='create'||mode=='trial';
    unawaited(_loadRememberedInfo());
  }

  Future<void> _loadRememberedInfo() async {
    final prefs=await SharedPreferences.getInstance();
    final remember=prefs.getBool(_bpRememberInfoKey)??false;
    if(!remember||!mounted)return;
    email.text=prefs.getString(_bpRememberEmailKey)??'';
    displayName.text=prefs.getString(_bpRememberNicknameKey)??'';
    setState(()=>rememberInfo=true);
  }

  Future<void> _persistRememberedInfo() async {
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
    if init_anchor not in block:
        raise SystemExit('v735 remembered auth: deeplink initState anchor missing')
    block=block.replace(init_anchor,init_new,1)

if 'await _persistRememberedInfo();' not in block:
    signup_old="""        final response=await Supabase.instance.client.auth.signUp(email:email.text.trim(),password:password.text,
          data:{'display_name':displayName.text.trim(),'legal_accepted':true,'legal_version':'2026-08-15'});
        if(response.session==null&&mounted) setState(()=>error='Check your email to confirm the account, then sign in.');
      } else {
        await Supabase.instance.client.auth.signInWithPassword(email:email.text.trim(),password:password.text);
      }
"""
    signup_new="""        final nickname=displayName.text.trim();
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
    if signup_old not in block:
        raise SystemExit('v735 remembered auth: submit anchor missing')
    block=block.replace(signup_old,signup_new,1)

block=block.replace("labelText:'Profile name',hintText:'How BridgePoint should welcome you'","labelText:'Nickname / profile name',hintText:'What should BridgePoint call you?'",1)

if 'Save my info for next time' not in block:
    placement="""      ),
      if(create)...[const SizedBox(height:10),CheckboxListTile(
"""
    remembered="""      ),
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
    if placement not in block:
        raise SystemExit('v735 remembered auth: remember-info UI placement anchor missing')
    block=block.replace(placement,remembered,1)

text=text[:start]+block+text[end:]
for needle in (
    '// bridgepoint-v735-secure-remembered-auth',
    'Save my info for next time',
    'BridgePoint never stores your password here.',
    '_bpRememberInfoKey',
    'Future<void> _loadRememberedInfo()',
    'await _persistRememberedInfo();',
    '// bridgepoint-v685-signup-deeplink',
):
    if needle not in text:
        raise SystemExit(f'v735 remembered auth contract missing: {needle}')

for forbidden in ("prefs.setString('password'",'prefs.setString(_bpRememberPassword','bridgepoint_remember_password'):
    if forbidden in text:
        raise SystemExit(f'v735 remembered auth: forbidden password persistence detected: {forbidden}')

auth=text[text.find('class _AuthScreenState extends State<_AuthScreen> {'):text.find('class _PublicLegalSummaryDialog',text.find('class _AuthScreenState extends State<_AuthScreen> {'))]
if auth.count('void initState()')!=1:
    raise SystemExit(f'v735 remembered auth: expected one initState, found {auth.count("void initState()")}; refusing release')

path.write_text(text,encoding='utf-8')
print('BridgePoint v735 preserved secure remembered email/nickname behavior after canonical auth normalization.')
