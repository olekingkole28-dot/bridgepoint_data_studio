from pathlib import Path
import base64,hashlib,json,zlib

path=Path('lib/main.dart')
pre='d03929fed826e5cbc5e3f105d598654aad990b2db753738fda88e163784362cb'
post='d1aa4c6e972937b7053bfe94dc9f9c8c677c0cac716b0800bbc3fec48eac3755'
raw=path.read_bytes()
actual=hashlib.sha256(raw).hexdigest()
if actual==post:
    print('BridgePoint v325/V318 compatibility repair already applied.')
    raise SystemExit(0)
if actual!=pre:
    body=raw.decode('utf-8')
    required=[
        'bridgepoint-v324-owner-truth-customer-safe-catalog',
        'bridgepoint-v325-mobile-community-share-radar',
        'bridgepoint_customer_access_contract_v318',
        '_RadarIntensityLegendV318',
        '_community3dStartupV325',
        '_community3dFallbackV325',
        'Loading BridgePoint Community 3D',
        '_BridgePointCommunityShareKitV325',
        'Share this Community post',
        'radar_base_reflectivity/MapServer/WMSServer',
        'radar_base_reflectivity_time/ImageServer/WMSServer',
    ]
    missing=[item for item in required if item not in body]
    if missing:
        raise SystemExit(f'v325/V318 semantic compatibility failure: {actual}; missing={missing}')

    def repair(old,new,label,verified):
        global body
        count=body.count(old)
        if count==1:
            body=body.replace(old,new,1)
            print(f'v325 evolved-source repair: {label}')
            return
        if count>1:
            raise SystemExit(f'v325 evolved-source {label}: ambiguous legacy anchors={count}')
        if not all(item in body for item in verified):
            raise SystemExit(f'v325 evolved-source {label}: neither legacy nor repaired contract found')

    repair("""    'Solar Opportunity',
  ];

    'BridgePoint Company',
  List<String> get packages => <String>[
""","""    'Solar Opportunity',
    'BridgePoint Company',
  ];

  List<String> get packages => <String>[
""",'customer package list',["'BridgePoint Company',","List<String> get packages => <String>["])

    repair("""  Future<void> _restoreWorkspaceState()async{
    try{
      final allowedPackages=_accessResolvedV318?_availablePackagesV318:packages;
      final nextPackage=widget.ownerMode?'All Intelligence':(savedPackage!=null&&allowedPackages.contains(savedPackage)?savedPackage:selectedPackage);
      final savedPackage=await prefs.getString('bp_workspace_package');
      final savedNav=await prefs.getInt('bp_workspace_navigation');
      final nextPackage=widget.ownerMode?'Owner Full Platform':(savedPackage!=null&&packages.contains(savedPackage)?savedPackage:selectedPackage);
      final maxIndex=visibleNavigationItems.length-1;
""","""  Future<void> _restoreWorkspaceState()async{
    try{
      final prefs=SharedPreferencesAsync();
      final savedPackage=await prefs.getString('bp_workspace_package');
      final savedNav=await prefs.getInt('bp_workspace_navigation');
      final allowedPackages=_accessResolvedV318?_availablePackagesV318:packages;
      final fallbackPackage=allowedPackages.contains(selectedPackage)?selectedPackage:(allowedPackages.isNotEmpty?allowedPackages.first:selectedPackage);
      final nextPackage=widget.ownerMode?'Owner Full Platform':(savedPackage!=null&&allowedPackages.contains(savedPackage)?savedPackage:fallbackPackage);
      final maxIndex=visibleNavigationItems.length-1;
""",'workspace restore',['final prefs=SharedPreferencesAsync();'])

    workspace_start=body.find('  Future<void> _restoreWorkspaceState()async{')
    workspace_end=body.find('  Future<void> _persistWorkspaceState',workspace_start)
    if workspace_start<0 or workspace_end<0:
        raise SystemExit('v325 evolved-source workspace restore boundaries missing')
    workspace=body[workspace_start:workspace_end]
    if workspace.count('final nextPackage=')!=1:
        raise SystemExit(f"v325 evolved-source workspace restore nextPackage declarations={workspace.count('final nextPackage=')}")
    if 'SharedPreferencesAsync()' not in workspace or 'savedPackage' not in workspace:
        raise SystemExit('v325 evolved-source workspace restore persistence contract missing')
    if '_availablePackagesV318' not in workspace and 'packages.contains(savedPackage)' not in workspace:
        raise SystemExit('v325 evolved-source workspace restore package guard missing')

    repair("""                      _TopBar(
                        packages: _availablePackagesV318,
                        accent:_bridgePointPageAccentV290(visibleNavigationItems[selectedNavigation].label),
                        package: selectedPackage,
                        packages: packages,
""","""                      _TopBar(
                        desktop: desktop,
                        packages: _availablePackagesV318,
                        accent:_bridgePointPageAccentV290(visibleNavigationItems[selectedNavigation].label),
                        package: selectedPackage,
""",'top bar arguments',['desktop: desktop,','packages: _availablePackagesV318,'])

    repair("""  List<DateTime> _cloudFrames=<DateTime>[];
  int _cloudFrameIndex=0;
  bool _showExpansion=!_displayPreferences.value.simplifiedViews;
""","""  List<DateTime> _cloudFrames=<DateTime>[];
  int _cloudFrameIndex=0;
  DateTime? get _cloudFrame=>_cloudFrames.isEmpty?null:_cloudFrames[_cloudFrameIndex.clamp(0,_cloudFrames.length-1)];
  bool _showExpansion=!_displayPreferences.value.simplifiedViews;
""",'cloud frame getter',['DateTime? get _cloudFrame=>'])

    path.write_text(body,encoding='utf-8')
    print(f'BridgePoint v325/V318 evolved-source compatibility repaired semantically: {actual}')
    raise SystemExit(0)

blob='c-rMWYj4}QmVZSv=#3<dtXT3}86}&f>E2+IHb^opcC&%ONVF|P7PXY*#FHAhe`CMyPrJWl4@tfKOxsKs*q|dz6nS`fc-}mkyF0^Zwl#ja`&EKJ`Gk7z7+(=Dh^1394N)+cE!j!$wEql#y}#Gkunrs6)$YV&%Y?^PD}C(rdK$k7ppvwJaT>p0NDhjfiKGlw=_PNKr2T#Ac7mlRLLZ|LIas22io76_k_bKc@WP8HQVcyJG{TZ$HX9LkNZ?8?9-+jK^$fGF0ho1-zCgt^&4I=*87f~W3Kcem7mTf*Mw8$sedub=#PeN>1M4n@W}2`txTFi~8{L7{H+s$NanOgy0Rz5BNAyjzsqqV&@PQCt8a`nJnA2n5Cr{Y@+%o!hOcQ)i4C%2UDaw7b#~`HCn-R~IyugcZViaRVEoc@cA*Ooi)j|GhNb!FqIEw9|Pmo)A6UB(e*T_Zmf{?KMDhbdN@?z{NeAGvR5byVaqA89(n>|BO*LOelN#csGm2N}IU|i!7#nI%}n__D7s}9I}#Pu8nb}@>j_X$O@M*?N)1xbt}tF3ClBQH6PdO&KkU$E3G(Oswox%(W{ASHLNXK4Mt(aIqge~#~kCwPKp9--DLJm@Hhy<^`)kyhf}(g4Ol){XZkc2CH&va*jPO|Unf#8%g6YHNC=aAM><Dix+&)mf50_(>dNdI_ApwvQxDQFuy%m=fQ|)EZVEwGHD)$TlXj0Q@I$yJ;4QbE}8^Qyc(Jme}446kh~mrETgUo{gTV51OjB3zYvLWNLNw*5=N@G`!=sZs?hJ1MRS7ZonKlY^~{vt@EWOW#prAWDU7)bYh^+XVd5(DS6Ks{s296m!k34dSmDX&V=Ez^u{F#=(}4KvbU;Le~o;93*krrs9a;@&Mif?4@+|5@Eu{>7`(?b&jFpW71kArJht4^2@1y8wG;=$iz01;qJISqlTfU_Yy<%+VCLbckbv4LX@Mi%L4kw)vIcs^aG^w$lGgBjPgsQIE$MffR=WcXr)<R)_I{-NG9?L6%2g?b1qKIO$BeuH`BH$N;}aO^Mz$c5KJy|EHd8dd1`ON#49K5wzw6i#bSkxTioI@PHc`6Gwvu7d$boTw)X@Xz_d{E$)3~Xd9jmDurn>8N4;;B{LV>v*B)<Rk>sAPoq!iTFBa+0EFTjnu58MzZE^cseD_(3`K(hr4Xc`^$)d&PYp2-<nMqv5Hn<GGi@fr-WH#?zlu#=#aSY~hUm&%UrEIbiT9T<?#8t2-@5)UeTXlLwsu;l72wxYhR$6}LC+^8^jFxBku*7NZNnuGpIsDF#6AutEFh7X17eS#tkoAL(*{iuQGeUgku%x2g3%QCb_jKejr4a?M$2prEbDE=$(CD0gu1f|0Ld0k8wvgvde#Ry!(#Px{0%`T6WVKgC6+~JG%_J&UG`TfGhSN+8N>3FUX@oVYe3=4;*SooGLdc<?<Gx8JsZ+NcA0r++eK22i=E@0!`OL<bgtov`kuHv(hIFrS;g-FuVG|J5Tm&=<Rxy-&lz$U;BSn?!}!^qm-56F{4m?$xX^f8(3k1+xI&M@645A22;qi8>Z{REt1yicB@BU$qq*eG>{?&Psg9*{pwt;5ip!oJY?a7rTNIr6<WB6NykOXe^3!(c3HF+~9cEx=o`#bO5y=8Rx2OE&bD-jp@MB8)4<C=#=|UgX>J%QM-kP%0*W#EzoE?|DS}-KKF9Q;2*Nb+MIJF;M5d7Xhoz({<byE&2$#_&iYD)Erx@?Q*XPHkbz>pGvGjF_YYzN^{@biqPvBdox6J2fkkp<beN~F!0D@neide_<qLc0aW8%7DzF!Apw&Cnuj|pHuSr>f2-ck#6#e59)XJwdYA=XN4dm6jKRbLT+K*NiB|{@p26<96g=BtKkK#6fr;yo%>ep+<YVUl0!8;hv)u@J1C+(x(eNR(Yt-43t+zs97=z=vf6gRxH%zpxgsf?Y<`2>U0ukmX7maLpvK$V?yln`4+p7ZKO33sPvFJktPG-p(HOscg)P979FuF?`Vz6364En0}GgN>p)^i0sfnhHgSIwBb>cD5rYTv|jAKSK^n*dqeZtgG81NL)!|7Irp@4)_m=HA`}ZY~jh1dh<X=p%{GreQo+MUy~vDqdTquG?ps?gn$Z6TEBBnH<NU&mI!SC|}spV+9p0xyamtGk8N1>flm;MgA1x0Q4co%psB-mg`{e2#sX*e&gi#>tAjdw}XYqqG^c6H%#y2QEY*5#w27v+Z;}drE!oKY_l$$S`<3Q8RbsM^J&ot`|}J`jwe=YYj!3?uFG<!0?rw1&3OQhJj7!2DX1FiIm(1k?@xxAZw;8TiaiHzds_gzpb1hH0oc9IpA?7qB+Dk9vU{cZeAaFD48!=KY7d0Em;#Z#B!Yp(gYJ0LNqj^VqnUL}JFr|z3idb*ZzmWGsWV4`&T`F}E!WMqx=k-+yWl5Nz>|_FI)3(|W8WJGQ>Ly@mzs30<Fp;)1&{^uq_A{21H!V4)@A7d9N=JgP$?fs!>h!P@Ou*1NiYV92~<t=%2Sz7oH4qpwj+2ZlZyQD)A6x%ef<9TTKeZd{ztkv|9mE0pMAJEJH0*se17}yGAMh{mll^`c9$Z<HyG^o1QaM3!yx91?&}@?@I~ZLKjgRi(*Rt{opGxzs=vcPzMNH_&c{z*<kZwcMC3dwCAUmXS65J^yv7R8l@|G3OT6FOqeg->7v0%$+>q-rmXr)Ylg%$M*eR~&lr;9_zR4C~0!iV6w7~}%n4L8~$YyQJyaG@{dwa|liri62!|EfC$#+dd)@Tpj4EC!6-v(NUQK_=wS<?(qs!gsa0Xd1H^S}kQ1~z5orh;ZAk67qbQ}3u7HOX$aA+-sV@7iw0L8ztO^uzEnKNUDh;u!R<2UM`m87Xwo`9sRGG1vv$MEuwbEt&a+k{5vg8Qh}KQq&ib-V@nNyL!x^i`Ii$>y*rJnpoCFl3FVzKYue=R!7@z+m^U`o3YurT8bH3YZgqB_zhRw_&F<{&WE7FxVc?kwh#k}1k!XaISFNfh?I3NXkj0&IA(xw#=$}}yveFodtU0A#TNe9QM%JS)Js>K(qiJdco=b~a)}lt0P^3VpA=H;c%c__T1XrmM4&g&YvrqgaVojb9IE|Gaet6G@4|sBNBy9C@UvZNh;$zZ<9O0A4n*q}L@J;l#c6XjF#YYfgT+FvLEr66^(Sy<m^}ENv&@v7#D4?~Wr-6q+CuOxMsCf12>KOSPkV&GcM>gU&tO9sMYG0rl;3gBN*h#7dAD_QhvfE3JySk{Z4LBJQ)>+RdJ7C40No1m#zCVI@!d<XcYrHEB_jqi28Tw~84Yd%h*VDyO=rp<m!thG&^Nh*88h!#c#41MH~Ol*V+x14jyNN;^nf7Rh$IkD7Y9;AcvXn#3tsg+k{ll+s>`anEziF>22}rV1cAAwe;^<g(;pcSt_|WwluR#fuTLOm(s~+Px<4{%`_Oz%)MmbI)W#yKont4ajD&LH&Lwtl2^fAQw+m&_Ka#Id5@9K225CyTp|oW7zTOH7>WaCOV19-%8IOH@oq>7)S<-S<s8r`jwIiFTX1`dHYKSN$Pr25NSa@OX5JY@ql*Bb5Oq9CHH$Ip~s_^WXRab$!<D+S)G_{qgkeyJx=XDT@szG#XHMJ>vwv_FiT~BDw$Xe0&&^THN!D5kvR;qEBfg4jX1r?oM*7GH$KGQj&6?KKBRo{&0e_>$yozeF<F7Q(l`=H9)RPLB0D223ehm)z+<G`E3>fNHWEwxZubvINYO9B}#Q9@owh=ZXQ3`f8URf#dcO!_QAYn3w_EV-C^7wYce?!fFqxZ8boxVz36l_0aq#6izUi`oXg7JKYukAr~*o7B$d-J-A+a2qJF`_Y<wTP=XTAtUev$_h9gFC9txpetFDp*MF@_k;D?zMK=PDtn`u$`@PfplP%;ekqDF2ThZ;Eu|UiK59$V(%l`6Jja8WZj4Eu>31cT&f5R@<wh!>2<g%l3M9~cynu##BUyM<^=C#N_Fa8l$}6WRW7^9ESh*0rL3w$=LU8F-mQom|nrwVTGjGiD6U=9GRXt=ipKC<G@kwDuDl_(B#>zR-Y8T(AXN|Yzj8=AE1682XZZlL;wuZYNJa*c(ZOsZ61-w$(Vzn}Hr9)gUI|S!gD=G`~;=y(apH2r5=r)(+dG(o3ekjS#%DBpj`1u6*>^h<2{g*!%`!CP%-+ZC-L%(l43KF<=O~8$5gkQh6@Zm2z#-+uv>5n-TU86UbPBp*nC{fV4&vffR@Bk~D7si<T1Wk>XUt|xl=RDfYEGiLokP<skrWzH+joCY1IKHB8T=*X4PRIdzN7pza{;b|f;5T4=Fc9MVFHA90ma|wYEMKlCFVX>`wn{yScPij69q0~t+2v4uDV0@z{rb!D%D#SGf3!-mn}GVg<i2uNS624V7+t~5f;m<>eQIe#l;Zw3L;c%wcLs!k)4k{nIC^idsGli8EbXdN+%t&F-C58M|I!V9RrPzhdN<tyfK_ZPQ-%X!2|gsO7Wa3ytA~>4i=uhp6d8}0&dcc!k+TGp5<j;2Bq<D?-7D2l=q3pf6JuZxh_PX7z*u<f9BY&Wye2w=H#72x6}coYjZ*!}h?Ar-1K(5z6Ypj<0x$I_9O(bVk9u`Z%1Hg5xkb@fKDW`?H1~ZaUy#x#w1*gAen{uKLUT@BLASf+J=X~<1|q@QcF_@#kCW)oHk-}8y?XQSE#4a5@lS1h9Ao+3&c71LKyR*1W^dDJtC_{MdSr#};8SvT<=_`3_%lQ$YBL-KL5E&M<a^1Bqzf;KkCdf1NW4*5ZG@sc13SM5jF<rEz>HUjMzCk^p22|zuMR~1b{^v2vo43cPK}LMRI6ycyFaL*<k;)p)>$bddm+cwd|;Z!-@N6<iY*7%#dh-5muXUIeS3N=s;j5jO1mm-oF1_(DvZyX8(p<VE+-pcs<5JbK-S!-CJVRl7-yw*ELPIIHa#e5P1`vr>1)dLFe@ZEYFe~Nm6r6cQ|jRqJ<6HV1^?tMwL+Qve6N6Hq|SZ|%PJ~Wq=&@wUFC#bPemvyWl7V5?YPV?O|sHLrV?NClJ#gpz2H&FKW`cs&87yI!d)-KfD;y^U|pf^V7XAYT9Eh<Hj*f-NG!Ig@$Q9gD8v29?&hYFy&vUguC2eN8;frL;_ABoQgvOwv%0#j^G#)FdGKMFEeIOn+Dbo_WVbEe&@MiV+{wSqI&E-swbb$UgqwX(AkiAIIol?mlj+VvaY{@^g=)4B8Fv+jT&4Q8qw1To;>~q;K%V&a@@>x5arU~H$37I(-FcM^=%|*?yss>ujrK~3J^PT4KD2AYvO$8mBv$tAJSsU7+>y=>s(oAd)nHDDgV-lnqJ3if`h+C(Z-!~x%_GCK^5@hakmPq0>)ng53qKVgWX!CG$i2X$STQw_A$1|KUTpB8ZJ0;$)un97$CvU#&J}0HW98?K<zvR3oY&NEeN*qW#7*rU=ceLY;^KoXo1&-O>cjopnfS8Zs<<E<zA|3!w8pMg`c_$=e{z$%2c0ASm^lcgcMY?nTI{(BOvvVvoMo1~_M*<!;*S;?^|H@X-l9&EZBb{CYn?9FI(f$R^#N>iWdIwBvw%&8x)PzLf`_7bNpJ;aQmJM=fE=C(C)3a|Uo8FB&!{V(f!0M$EfcWIdA!@t3E1NV?3;N*Uo^DK{>6r<q(lY#aDtH^PwY^*)a7{xeB%aLCXK;d%c~W}PZd*f<S7mo#Amc1_am0km}_Y=F?EE*lZNsV&7v|ht;X4sAYaaZ?{t{i*)6@z655p-wA!hO+0NDjciRfnDn)48iX)!NLHVNMnyz5(|97+(CjuAXq^+z^0Hq%g=6g7P;$oIkli~?9f>+OE;-CNcZ+0K^;lh#n)+2!0E(yVD8%%K8OaJ?Vjb9v9o%(c>8-n_|cVB#I#5LCIKC}ClkBhQ6!24;R63IU)23bjt9~79Zgk6tTDkK*({w_Q_P5d0bEUbD<8sUu6FVNOSIjb;O$uqkLLqFofpHi&SHoBU)-u>94t8Qfy77(?~>Uqpc^}bvxx2d#Zb2PE0l47(|4aKNdJu!M^-9%WanDA<45_Gvhf|IIec7Rm;diN_Q#QwficHCzzvjZ2S-{3{(af9Lzd6bX8|6hMizO('
ops=json.loads(zlib.decompress(base64.b85decode(blob)).decode('utf-8'))
lines=raw.decode('utf-8').splitlines(keepends=True)
for i1,i2,replacement in reversed(ops):
    lines[i1:i2]=replacement
out=''.join(lines)
actual_post=hashlib.sha256(out.encode('utf-8')).hexdigest()
if actual_post!=post:
    raise SystemExit(f'v325/V318 compatibility repair hash mismatch: expected {post}, got {actual_post}')
path.write_text(out,encoding='utf-8')
print('BridgePoint v325/V318 compatibility repair applied.')
