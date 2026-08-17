from pathlib import Path

path=Path('lib/main.dart')
s=path.read_text(encoding='utf-8')
marker='bridgepoint-v227-first-login-password'
if marker in s:
    print('v227 first-login password flow already applied')
    raise SystemExit(0)

old_gate="""class _AuthGate extends StatelessWidget {
  const _AuthGate();
  @override
  Widget build(BuildContext context) => StreamBuilder<AuthState>(
    stream: Supabase.instance.client.auth.onAuthStateChange,
    builder: (context, _) => Supabase.instance.client.auth.currentSession == null
        ? const _AuthScreen()
        : const _WorkspaceGate(),
  );
}
"""
new_gate="""class _AuthGate extends StatefulWidget {
  const _AuthGate();
  @override State<_AuthGate> createState()=>_AuthGateState();
}
class _AuthGateState extends State<_AuthGate>{
  StreamSubscription<AuthState>? _authSub;
  bool _recovering=Uri.base.fragment.contains('type=recovery')||Uri.base.queryParameters['type']=='recovery';
  @override void initState(){
    super.initState();
    _authSub=Supabase.instance.client.auth.onAuthStateChange.listen((state){
      if(!mounted)return;
      if(state.event==AuthChangeEvent.passwordRecovery)setState(()=>_recovering=true);
      else if(state.event==AuthChangeEvent.signedOut)setState(()=>_recovering=false);
      else setState((){});
    });
  }
  @override void dispose(){_authSub?.cancel();super.dispose();}
  @override Widget build(BuildContext context){
    final session=Supabase.instance.client.auth.currentSession;
    if(_recovering&&session!=null)return _PasswordRecoveryScreen(onComplete:()=>setState(()=>_recovering=false));
    return session==null?const _AuthScreen():const _WorkspaceGate();
  }
}
"""
if old_gate not in s:
    raise SystemExit('v227 auth gate anchor missing')
s=s.replace(old_gate,new_gate,1)

auth_start=s.find('class _AuthScreenState extends State<_AuthScreen> {')
auth_end=s.find('class _PublicLegalSummaryDialog',auth_start)
if auth_start<0 or auth_end<0:
    raise SystemExit('v227 auth screen block missing')
block=s[auth_start:auth_end]
if 'String? notice;' not in block:
    error_decl='String? error;'
    if error_decl not in block: raise SystemExit('v227 error declaration anchor missing')
    block=block.replace(error_decl,'String? error; String? notice;',1)

submit_anchor='  Future<void> submit() async {'
reset_method="""  Future<void> resetPassword() async {
    final address=email.text.trim().toLowerCase();
    if(address.isEmpty||!address.contains('@')){setState(()=>error='Enter the email address for your BridgePoint account first.');return;}
    setState(()=>loading=true);error=null;notice=null;
    try{
      await Supabase.instance.client.auth.resetPasswordForEmail(address,redirectTo:_bridgePointLiveUrl);
      if(mounted)setState(()=>notice='Password setup email sent. Open the newest BridgePoint reset email, choose your password, then BridgePoint will sign you in securely.');
    }catch(e){if(mounted)setState(()=>error=e.toString());}
    finally{if(mounted)setState(()=>loading=false);}
  }

"""
if 'Future<void> resetPassword()' not in block:
    if submit_anchor not in block: raise SystemExit('v227 submit anchor missing')
    block=block.replace(submit_anchor,reset_method+submit_anchor,1)

old_actions="""      if(error!=null)...[const SizedBox(height:12),Text(error!,style:const TextStyle(color:AppTheme.amber,fontSize:11))],
      const SizedBox(height:18),FilledButton(onPressed:loading?null:submit,child:Text(loading?'Please wait…':create?'Start free trial':'Sign in')),
      TextButton(onPressed:loading?null:()=>setState(()=>create=!create),child:Text(create?'Already have an account? Sign in':'New here? Start 7-day trial')),
"""
new_actions="""      if(error!=null)...[const SizedBox(height:12),Text(error!,style:const TextStyle(color:AppTheme.amber,fontSize:11))],
      if(notice!=null)...[const SizedBox(height:12),Text(notice!,style:const TextStyle(color:AppTheme.green,fontSize:11,height:1.4))],
      const SizedBox(height:18),FilledButton(onPressed:loading?null:submit,child:Text(loading?'Please wait…':create?'Start free trial':'Sign in')),
      if(!create)TextButton.icon(onPressed:loading?null:resetPassword,icon:const Icon(Icons.key_rounded,size:17),label:const Text('First-time invited owner / Forgot password')),
      TextButton(onPressed:loading?null:()=>setState(()=>create=!create),child:Text(create?'Already have an account? Sign in':'New here? Start 7-day trial')),
      const Text('bridgepoint-v227-first-login-password',style:TextStyle(fontSize:0,color:Colors.transparent)),
"""
if old_actions not in block:
    raise SystemExit('v227 auth actions anchor missing')
block=block.replace(old_actions,new_actions,1)
s=s[:auth_start]+block+s[auth_end:]

insert_anchor='class _PublicLegalSummaryDialog extends StatelessWidget{'
recovery=r'''class _PasswordRecoveryScreen extends StatefulWidget{
  const _PasswordRecoveryScreen({required this.onComplete});
  final VoidCallback onComplete;
  @override State<_PasswordRecoveryScreen> createState()=>_PasswordRecoveryScreenState();
}
class _PasswordRecoveryScreenState extends State<_PasswordRecoveryScreen>{
  final password=TextEditingController();
  final confirm=TextEditingController();
  bool loading=false,show=false;
  String? error;
  @override void dispose(){password.dispose();confirm.dispose();super.dispose();}
  Future<void> save()async{
    final p=password.text;
    if(p.length<8){setState(()=>error='Use at least 8 characters for your password.');return;}
    if(p!=confirm.text){setState(()=>error='The passwords do not match.');return;}
    setState(()=>loading=true);error=null;
    try{
      await Supabase.instance.client.auth.updateUser(UserAttributes(password:p));
      if(!mounted)return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Password saved. Welcome to BridgePoint.')));
      widget.onComplete();
    }catch(e){if(mounted)setState(()=>error=e.toString());}
    finally{if(mounted)setState(()=>loading=false);}
  }
  @override Widget build(BuildContext context)=>Scaffold(body:_ExperienceBackground(child:Center(child:SingleChildScrollView(padding:const EdgeInsets.all(20),child:Card(child:Container(
    width:460,padding:const EdgeInsets.all(30),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      const Center(child:_BridgePointMark(size:58)),const SizedBox(height:14),
      const Text('CHOOSE YOUR BRIDGEPOINT PASSWORD',textAlign:TextAlign.center,style:TextStyle(fontSize:17,fontWeight:FontWeight.w900,letterSpacing:.6)),
      const SizedBox(height:8),const Text('Your email has been verified. Create the password you will use to sign in from now on.',textAlign:TextAlign.center,style:TextStyle(color:AppTheme.textMuted,height:1.45)),
      const SizedBox(height:22),TextField(controller:password,obscureText:!show,autofillHints:const [AutofillHints.newPassword],decoration:InputDecoration(labelText:'New password',border:const OutlineInputBorder(),suffixIcon:IconButton(onPressed:()=>setState(()=>show=!show),icon:Icon(show?Icons.visibility_off_rounded:Icons.visibility_rounded)))),
      const SizedBox(height:12),TextField(controller:confirm,obscureText:!show,onSubmitted:(_)=>save(),autofillHints:const [AutofillHints.newPassword],decoration:const InputDecoration(labelText:'Confirm password',border:OutlineInputBorder())),
      if(error!=null)...[const SizedBox(height:12),Text(error!,style:const TextStyle(color:AppTheme.amber,fontSize:11))],
      const SizedBox(height:18),FilledButton.icon(onPressed:loading?null:save,icon:const Icon(Icons.lock_reset_rounded),label:Text(loading?'Saving…':'Save password and enter BridgePoint')),
      const SizedBox(height:8),const Text('For security, BridgePoint never displays or emails your password.',textAlign:TextAlign.center,style:TextStyle(color:AppTheme.textMuted,fontSize:9,height:1.4)),
    ]),
  ))))));
}

'''
idx=s.find(insert_anchor)
if idx<0:
    raise SystemExit('v227 recovery class anchor missing')
s=s[:idx]+recovery+s[idx:]
path.write_text(s,encoding='utf-8')
print('Applied first-time owner password and recovery flow v227.')
