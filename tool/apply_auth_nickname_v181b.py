from pathlib import Path

path=Path('lib/main.dart')
text=path.read_text(encoding='utf-8')
original=text

imp="import 'package:share_plus/share_plus.dart';\n"
if imp not in text: raise SystemExit('share_plus import marker missing')
if "package:shared_preferences/shared_preferences.dart" not in text:
    text=text.replace(imp,imp+"import 'package:shared_preferences/shared_preferences.dart';\n",1)
api_marker="const _supabaseUrl = 'https://xdfsjztwgsbmabshzsjw.supabase.co';\n"
if api_marker not in text: raise SystemExit('Supabase URL marker missing')
if '_bpRememberInfoKey' not in text:
    text=text.replace(api_marker,api_marker+"const _bpRememberInfoKey='bridgepoint_remember_info_v1';\nconst _bpRememberEmailKey='bridgepoint_remember_email_v1';\nconst _bpRememberNicknameKey='bridgepoint_remember_nickname_v1';\n",1)

state_start=text.find('class _AuthScreenState extends State<_AuthScreen> {')
state_end=text.find('class _PublicLegalSummaryDialog',state_start)
if state_start<0 or state_end<0: raise SystemExit('auth screen state block missing')
block=text[state_start:state_end]
old_fields="""  final displayName=TextEditingController(); final email=TextEditingController(); final password=TextEditingController();
  bool create=false,loading=false,showPassword=false,acceptTerms=false; String? error;
"""
new_fields="""  final displayName=TextEditingController(); final email=TextEditingController(); final password=TextEditingController();
  bool create=false,loading=false,showPassword=false,acceptTerms=false,rememberInfo=false; String? error;

  @override void initState(){super.initState();unawaited(_loadRememberedInfo());}
  Future<void> _loadRememberedInfo()async{
    final prefs=await SharedPreferences.getInstance();final remember=prefs.getBool(_bpRememberInfoKey)??false;
    if(!remember||!mounted)return;email.text=prefs.getString(_bpRememberEmailKey)??'';displayName.text=prefs.getString(_bpRememberNicknameKey)??'';setState(()=>rememberInfo=true);
  }
  Future<void> _persistRememberedInfo()async{
    final prefs=await SharedPreferences.getInstance();await prefs.setBool(_bpRememberInfoKey,rememberInfo);
    if(rememberInfo){await prefs.setString(_bpRememberEmailKey,email.text.trim());final user=Supabase.instance.client.auth.currentUser;final meta=user?.userMetadata??const <String,dynamic>{};final nickname=(displayName.text.trim().isNotEmpty?displayName.text.trim():'${meta['nickname']??meta['display_name']??''}'.trim());await prefs.setString(_bpRememberNicknameKey,nickname);}
    else{await prefs.remove(_bpRememberEmailKey);await prefs.remove(_bpRememberNicknameKey);}
  }
"""
if old_fields not in block: raise SystemExit('auth field marker missing')
block=block.replace(old_fields,new_fields,1)
old_submit="""        final response=await Supabase.instance.client.auth.signUp(email:email.text.trim(),password:password.text,
          data:{'display_name':displayName.text.trim(),'legal_accepted':true,'legal_version':'2026-08-15'});
        if(response.session==null&&mounted) setState(()=>error='Check your email to confirm the account, then sign in.');
      } else {
        await Supabase.instance.client.auth.signInWithPassword(email:email.text.trim(),password:password.text);
      }
"""
new_submit="""        final nickname=displayName.text.trim();
        final response=await Supabase.instance.client.auth.signUp(email:email.text.trim(),password:password.text,data:{'display_name':nickname,'nickname':nickname,'legal_accepted':true,'legal_version':'2026-08-15'});
        await _persistRememberedInfo();
        if(response.session==null&&mounted) setState(()=>error='Check your email to confirm the account, then sign in.');
      } else {
        await Supabase.instance.client.auth.signInWithPassword(email:email.text.trim(),password:password.text);
        final meta=Supabase.instance.client.auth.currentUser?.userMetadata??const <String,dynamic>{};if(displayName.text.trim().isEmpty)displayName.text='${meta['nickname']??meta['display_name']??''}'.trim();await _persistRememberedInfo();
      }
"""
if old_submit not in block: raise SystemExit('auth submit marker missing')
block=block.replace(old_submit,new_submit,1)
block=block.replace("labelText:'Profile name',hintText:'How BridgePoint should welcome you'","labelText:'Nickname / profile name',hintText:'What should BridgePoint call you?'",1)
password_anchor="""      ),
      if(create)...[const SizedBox(height:10),CheckboxListTile(
"""
remember_ui="""      ),
      const SizedBox(height:8),CheckboxListTile(contentPadding:EdgeInsets.zero,controlAffinity:ListTileControlAffinity.leading,value:rememberInfo,onChanged:loading?null:(v)=>setState(()=>rememberInfo=v==true),title:const Text('Save my info for next time',style:TextStyle(fontSize:10.5,fontWeight:FontWeight.w800)),subtitle:const Text('Remembers your email and nickname on this device. BridgePoint never stores your password here.',style:TextStyle(color:AppTheme.textMuted,fontSize:8.5,height:1.35))),
      if(create)...[const SizedBox(height:10),CheckboxListTile(
"""
if password_anchor not in block: raise SystemExit('remember-info placement marker missing')
block=block.replace(password_anchor,remember_ui,1)
text=text[:state_start]+block+text[state_end:]

settings_start=text.find('class _SettingsPageState extends State<_SettingsPage> {')
settings_end=text.find('class _SettingsSection extends StatelessWidget',settings_start)
if settings_start<0 or settings_end<0: raise SystemExit('settings state block missing')
s=text[settings_start:settings_end]
if '_nicknameController' not in s:
    field_marker='  bool _savingAccessibility=false;\n'
    if field_marker not in s: raise SystemExit('settings accessibility field marker missing')
    s=s.replace(field_marker,field_marker+"  final _nicknameController=TextEditingController();\n  bool _savingNickname=false;\n",1)
init_line='    _accessibility=_displayPreferences.value;\n'
if init_line not in s: raise SystemExit('settings accessibility init line missing')
if '_nicknameController.text=' not in s:
    s=s.replace(init_line,init_line+"    final meta=Supabase.instance.client.auth.currentUser?.userMetadata??const <String,dynamic>{};\n    _nicknameController.text='${meta['nickname']??meta['display_name']??''}'.trim();\n",1)
old_dispose='  @override void dispose(){_feedback.dispose();super.dispose();}\n'
if old_dispose not in s: raise SystemExit('settings dispose marker missing')
s=s.replace(old_dispose,'  @override void dispose(){_feedback.dispose();_nicknameController.dispose();super.dispose();}\n',1)
method_anchor='  Future<void> _sendFeedback() async{\n'
nickname_method=r'''  Future<void> _saveNickname()async{
    final nickname=_nicknameController.text.trim();if(nickname.isEmpty){_showInfoDialog(context,'Nickname needed','Enter the name you want BridgePoint to use for you.');return;}
    setState(()=>_savingNickname=true);
    try{await Supabase.instance.client.auth.updateUser(UserAttributes(data:{'nickname':nickname,'display_name':nickname}));final prefs=await SharedPreferences.getInstance();if(prefs.getBool(_bpRememberInfoKey)??false)await prefs.setString(_bpRememberNicknameKey,nickname);if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('BridgePoint will call you $nickname.')));}
    catch(e){if(mounted)_showInfoDialog(context,'Could not save nickname','$e');}finally{if(mounted)setState(()=>_savingNickname=false);}
  }

'''
if method_anchor not in s: raise SystemExit('settings feedback marker missing')
s=s.replace(method_anchor,nickname_method+method_anchor,1)
account_children="""                        title: 'Account & trial',
                        subtitle: 'Every new account receives BridgePoint All Intelligence.',
                        children: [
"""
account_replace="""                        title: 'Account & trial',
                        subtitle: 'Every new account receives BridgePoint All Intelligence.',
                        children: [
                          TextField(controller:_nicknameController,textCapitalization:TextCapitalization.words,decoration:const InputDecoration(labelText:'Your nickname',hintText:'What should BridgePoint call you?',border:OutlineInputBorder())),
                          const SizedBox(height:8),SizedBox(width:double.infinity,child:OutlinedButton.icon(onPressed:_savingNickname?null:_saveNickname,icon:const Icon(Icons.badge_outlined),label:Text(_savingNickname?'Saving nickname…':'Save nickname'))),
                          const SizedBox(height:8),const Text('Your nickname follows your BridgePoint account and can be changed anytime.',style:TextStyle(color:AppTheme.textMuted,fontSize:9,height:1.4)),const SizedBox(height:10),
"""
if account_children not in s: raise SystemExit('account settings marker missing')
s=s.replace(account_children,account_replace,1)
text=text[:settings_start]+s+text[settings_end:]
for needle in ['Save my info for next time','BridgePoint never stores your password here.','Your nickname','SharedPreferences']:
    if needle not in text: raise SystemExit(f'missing v181b marker {needle}')
if text==original: raise SystemExit('No auth/nickname changes applied')
path.write_text(text,encoding='utf-8')
print('Applied secure remembered sign-in and editable nickname v181b')
