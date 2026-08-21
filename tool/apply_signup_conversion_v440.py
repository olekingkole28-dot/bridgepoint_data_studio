from pathlib import Path
import re

main_path=Path('lib/main.dart')
text=main_path.read_text(encoding='utf-8')
marker='bridgepoint-v440-signup-conversion'

if marker not in text:
    auth_class='class _AuthScreen extends StatefulWidget {'
    if text.count(auth_class)!=1:
        raise SystemExit(f'V440 auth screen anchor count {text.count(auth_class)}')

    helper="""bool _bridgePointStartsInSignupV440(){
  final params=Uri.base.queryParameters;
  final mode=(params['mode']??params['intent']??'').trim().toLowerCase();
  if(mode=='signin'||mode=='login')return false;
  if(mode=='signup'||mode=='create'||mode=='trial')return true;
  final campaign=(params['utm_campaign']??'').trim().toLowerCase();
  return campaign.contains('trial')||campaign.contains('signup')||campaign.contains('create_account');
}

"""
    text=text.replace(auth_class,helper+auth_class,1)

    state_anchor="  bool create=false,loading=false,showPassword=false,acceptTerms=false; String? error;"
    state_replacement="  bool create=_bridgePointStartsInSignupV440(),loading=false,showPassword=false,acceptTerms=false; String? error,success;"
    if text.count(state_anchor)!=1:
        raise SystemExit(f'V440 auth state anchor count {text.count(state_anchor)}')
    text=text.replace(state_anchor,state_replacement,1)

    submit_anchor="    setState(()=>loading=true); error=null;"
    if text.count(submit_anchor)!=1:
        raise SystemExit(f'V440 submit state anchor count {text.count(submit_anchor)}')
    text=text.replace(submit_anchor,"    setState((){loading=true;error=null;success=null;});",1)

    signup_old="""        final response=await Supabase.instance.client.auth.signUp(email:email.text.trim(),password:password.text,
          data:{'display_name':displayName.text.trim(),'legal_accepted':true,'legal_version':'2026-08-15'});
        if(response.session==null&&mounted) setState(()=>error='Check your email to confirm the account, then sign in.');"""
    signup_new="""        final trimmedEmail=email.text.trim();
        if(trimmedEmail.isEmpty)throw Exception('Enter your email address.');
        if(password.text.isEmpty)throw Exception('Create a password.');
        final response=await Supabase.instance.client.auth.signUp(
          email:trimmedEmail,password:password.text,
          data:{'legal_accepted':true,'legal_version':'2026-08-15'},
        );
        if(response.session==null&&mounted){
          setState((){
            success='Account created. Check your email for the confirmation link, then sign in.';
            create=false;
            password.clear();
          });
        }"""
    if text.count(signup_old)!=1:
        raise SystemExit(f'V440 signup submit anchor count {text.count(signup_old)}')
    text=text.replace(signup_old,signup_new,1)

    signin_old="""      } else {
        await Supabase.instance.client.auth.signInWithPassword(email:email.text.trim(),password:password.text);
      }"""
    signin_new="""      } else {
        final trimmedEmail=email.text.trim();
        if(trimmedEmail.isEmpty)throw Exception('Enter your email address.');
        if(password.text.isEmpty)throw Exception('Enter your password.');
        await Supabase.instance.client.auth.signInWithPassword(email:trimmedEmail,password:password.text);
      }"""
    if text.count(signin_old)!=1:
        raise SystemExit(f'V440 signin anchor count {text.count(signin_old)}')
    text=text.replace(signin_old,signin_new,1)

    # Remove the optional profile-name field from first-run signup. Users can personalize
    # after activation; signup should only ask for the credentials and required legal assent.
    pattern=r"if\(create\)\.\.\.\[TextField\(controller:displayName,.*?const SizedBox\(height:12\)\],"
    text,replaced=re.subn(pattern,'',text,count=1,flags=re.S)
    if replaced!=1:
        raise SystemExit(f'V440 profile-field removal count {replaced}')

    email_old="TextField(controller:email,keyboardType:TextInputType.emailAddress,decoration:const InputDecoration(labelText:'Email',border:OutlineInputBorder()))"
    email_new="TextField(controller:email,keyboardType:TextInputType.emailAddress,autofillHints:const [AutofillHints.email],textInputAction:TextInputAction.next,decoration:const InputDecoration(labelText:'Email',border:OutlineInputBorder()))"
    if text.count(email_old)!=1:
        raise SystemExit(f'V440 email field anchor count {text.count(email_old)}')
    text=text.replace(email_old,email_new,1)

    password_old="""        controller:password,obscureText:!showPassword,onSubmitted:(_)=>submit(),
        decoration:InputDecoration("""
    password_new="""        controller:password,obscureText:!showPassword,onSubmitted:(_)=>submit(),
        autofillHints:create?const [AutofillHints.newPassword]:const [AutofillHints.password],
        textInputAction:TextInputAction.done,
        decoration:InputDecoration("""
    if text.count(password_old)!=1:
        raise SystemExit(f'V440 password field anchor count {text.count(password_old)}')
    text=text.replace(password_old,password_new,1)

    error_anchor="      if(error!=null)...[const SizedBox(height:12),Text(error!,style:const TextStyle(color:AppTheme.amber,fontSize:11))],"
    success_block="""      if(success!=null)...[const SizedBox(height:12),Container(padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:AppTheme.cyan.withOpacity(.08),borderRadius:BorderRadius.circular(10),border:Border.all(color:AppTheme.cyan.withOpacity(.28))),child:Text(success!,style:const TextStyle(color:AppTheme.cyan,fontSize:11,height:1.4,fontWeight:FontWeight.w700)))],
"""
    if text.count(error_anchor)!=1:
        raise SystemExit(f'V440 error display anchor count {text.count(error_anchor)}')
    text=text.replace(error_anchor,success_block+error_anchor,1)

    button_old="child:Text(loading?'Please wait…':create?'Start free trial':'Sign in'))"
    button_new="child:Text(loading?'Please wait…':create?'Create account & start trial':'Sign in'))"
    if text.count(button_old)!=1:
        raise SystemExit(f'V440 submit label anchor count {text.count(button_old)}')
    text=text.replace(button_old,button_new,1)

    text += "\nconst String _bridgePointSignupConversionV440='bridgepoint-v440-signup-conversion | trial links open signup | two-field account creation | confirmation clarity';\n"
    main_path.write_text(text,encoding='utf-8')
    print('Applied V440 signup conversion repair.')
else:
    print('V440 signup conversion repair already applied.')

# Strengthen any generated public homepage without assuming one fixed output path.
# Trial CTAs must explicitly enter signup mode; existing-user links must stay sign-in.
patched_homepages=[]
for page in Path('web').rglob('*.html'):
    body=page.read_text(encoding='utf-8')
    original=body
    body=body.replace('/app/?utm_source=homepage&utm_medium=hero&utm_campaign=start_trial','/app/?mode=signup&utm_source=homepage&utm_medium=hero&utm_campaign=start_trial')
    body=body.replace('/app/?utm_source=homepage&utm_medium=live_proof&utm_campaign=proof_to_trial','/app/?mode=signup&utm_source=homepage&utm_medium=live_proof&utm_campaign=proof_to_trial')
    body=body.replace('/app/?utm_source=homepage&utm_medium=nav&utm_campaign=open_app','/app/?mode=signin&utm_source=homepage&utm_medium=nav&utm_campaign=open_app')

    hero_old='''<div class="actions"><a class="btn primary" href="#live-proof">See live Connecticut proof</a><a class="btn secondary" href="/sample/?utm_source=homepage&utm_medium=hero&utm_campaign=territory_request">Request your territory</a><a class="btn secondary" href="/app/?mode=signup&utm_source=homepage&utm_medium=hero&utm_campaign=start_trial">Open BridgePoint / Start trial</a></div>'''
    hero_new='''<div class="actions"><a class="btn primary" href="/app/?mode=signup&utm_source=homepage&utm_medium=hero&utm_campaign=start_trial">Start 7-day free trial</a><a class="btn secondary" href="#live-proof">See live Connecticut proof</a><a class="btn secondary" href="/sample/?utm_source=homepage&utm_medium=hero&utm_campaign=territory_request">Request your territory</a></div>'''
    if hero_old in body:
        body=body.replace(hero_old,hero_new,1)

    nav_old='''<a class="open" href="/app/?mode=signin&utm_source=homepage&utm_medium=nav&utm_campaign=open_app">Open app</a>'''
    nav_new='''<a href="/app/?mode=signin&utm_source=homepage&utm_medium=nav&utm_campaign=open_app">Sign in</a><a class="open" href="/app/?mode=signup&utm_source=homepage&utm_medium=nav&utm_campaign=start_trial">Start free trial</a>'''
    if nav_old in body:
        body=body.replace(nav_old,nav_new,1)

    proof_old='''<div class="actions"><a class="btn primary" href="/sample/?utm_source=homepage&utm_medium=live_proof&utm_campaign=proof_to_territory">Show me my Connecticut territory</a><a class="btn secondary" href="/app/?mode=signup&utm_source=homepage&utm_medium=live_proof&utm_campaign=proof_to_trial">Start the 7-day trial</a></div>'''
    proof_new='''<div class="actions"><a class="btn primary" href="/app/?mode=signup&utm_source=homepage&utm_medium=live_proof&utm_campaign=proof_to_trial">Start the 7-day trial</a><a class="btn secondary" href="/sample/?utm_source=homepage&utm_medium=live_proof&utm_campaign=proof_to_territory">Show me my Connecticut territory</a></div>'''
    if proof_old in body:
        body=body.replace(proof_old,proof_new,1)

    body=body.replace('<a href="/app/">Open app</a>','<a href="/app/?mode=signin">Sign in</a>')
    if body!=original:
        page.write_text(body,encoding='utf-8')
        patched_homepages.append(str(page))

print('V440 homepage patches:',patched_homepages or ['no generated public homepage matched; auth fix remains active'])

# Repair the older generated tracker variant if a prior release layer recreated it.
tracker_path=Path('web/acquisition_tracker.js')
if tracker_path.exists():
    tracker=tracker_path.read_text(encoding='utf-8')
    tracker=tracker.replace('const CAPTURE_VERSION=436;','const CAPTURE_VERSION=440;',1)
    tracker=tracker.replace("const route=`${location.pathname}${location.hash}`.toLowerCase();","const route=`${location.pathname}${location.search}${location.hash}`.toLowerCase();",1)
    bad="""    if(href.startsWith('/app')||text.includes('start trial')||text.includes('start free')||text.includes('create account')){
      send('CREATE_ACCOUNT_CLICK',{surface:'public_cta',destination:href.slice(0,160)});
    }"""
    good="""    if(text.includes('start trial')||text.includes('start free')||text.includes('create account')||href.includes('mode=signup')||href.includes('campaign=start_trial')||href.includes('proof_to_trial')){
      send('CREATE_ACCOUNT_CLICK',{surface:'public_cta',destination:href.slice(0,160)});
    }else if(href.startsWith('/app')||text.includes('open app')||text==='sign in'){
      send('VALUE_VIEW',{surface:'app_open_click',destination:href.slice(0,160)});
    }"""
    if bad in tracker:
        tracker=tracker.replace(bad,good,1)
    tracker_path.write_text(tracker,encoding='utf-8')
    print('Applied V440 acquisition classification repair.')
