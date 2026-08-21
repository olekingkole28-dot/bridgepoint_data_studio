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

    # The generated release has evolved several times. Replace the create-mode default
    # structurally inside the auth state rather than depending on the entire field line.
    auth_state_start=text.find('class _AuthScreenState extends State<_AuthScreen>')
    if auth_state_start<0:
        raise SystemExit('V440 auth state class missing')
    auth_state_end=text.find('\nclass ',auth_state_start+1)
    if auth_state_end<0:
        auth_state_end=len(text)
    auth_block=text[auth_state_start:auth_state_end]
    auth_block,replaced=re.subn(r'\bbool\s+create\s*=\s*false\b','bool create=_bridgePointStartsInSignupV440()',auth_block,count=1)
    if replaced!=1:
        raise SystemExit(f'V440 create-mode default replacement count {replaced}')

    # Keep the actual Supabase auth implementation intact. Only remove the profile-name
    # field from the first-run critical path when its known structure is present.
    auth_block,profile_removed=re.subn(
        r"if\(create\)\.\.\.\[TextField\(controller:displayName,.*?const SizedBox\(height:12\)\],",
        '',auth_block,count=1,flags=re.S)

    # Add browser autofill where the canonical field shapes are still present.
    email_old="TextField(controller:email,keyboardType:TextInputType.emailAddress,decoration:const InputDecoration(labelText:'Email',border:OutlineInputBorder()))"
    email_new="TextField(controller:email,keyboardType:TextInputType.emailAddress,autofillHints:const [AutofillHints.email],textInputAction:TextInputAction.next,decoration:const InputDecoration(labelText:'Email',border:OutlineInputBorder()))"
    if email_old in auth_block:
        auth_block=auth_block.replace(email_old,email_new,1)

    password_old="""        controller:password,obscureText:!showPassword,onSubmitted:(_)=>submit(),
        decoration:InputDecoration("""
    password_new="""        controller:password,obscureText:!showPassword,onSubmitted:(_)=>submit(),
        autofillHints:create?const [AutofillHints.newPassword]:const [AutofillHints.password],
        textInputAction:TextInputAction.done,
        decoration:InputDecoration("""
    if password_old in auth_block:
        auth_block=auth_block.replace(password_old,password_new,1)

    # Make the conversion action explicit without changing auth semantics.
    auth_block=auth_block.replace("create?'Start free trial':'Sign in'","create?'Create account & start trial':'Sign in'",1)

    text=text[:auth_state_start]+auth_block+text[auth_state_end:]
    text += "\nconst String _bridgePointSignupConversionV440='bridgepoint-v440-signup-conversion | trial links open signup | reduced first-run friction | truthful intent tracking';\n"
    main_path.write_text(text,encoding='utf-8')
    print(f'Applied V440 signup conversion repair; profile_field_removed={profile_removed}.')
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
