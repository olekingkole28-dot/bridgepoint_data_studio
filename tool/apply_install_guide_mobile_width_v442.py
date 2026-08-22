from pathlib import Path

web_path=Path('web/index.html')
web=web_path.read_text(encoding='utf-8')
marker='bridgepoint-v442-install-guide-mobile-width'
if marker in web:
    print('V442 install guide mobile width repair already applied.')
    raise SystemExit(0)

if 'bridgepoint-v441-mobile-install-fallback' not in web:
    raise SystemExit('V442 requires V441 mobile install fallback')
if 'id="bp-install-fallback-v441"' not in web:
    raise SystemExit('V442 requires the V441 direct fallback')

# Live 390px real-touch verification proved the V441 floating CTA itself is healthy but
# the install-guide action row can render 420px wide. Clamp the guide actions and every
# mobile action control to the viewport, with border-box sizing, so the fallback remains
# fully visible and its center point is actually tappable on narrow mobile browsers.
style='''  <style id="bridgepoint-v442-install-guide-mobile-width">
    #bp-install-fallback-v441{box-sizing:border-box!important;max-width:100%!important}
    @media(max-width:620px){
      .bp-install-actions{box-sizing:border-box!important;width:min(100%,calc(100vw - 24px))!important;max-width:calc(100vw - 24px)!important;margin-left:auto!important;margin-right:auto!important;overflow:visible!important}
      .bp-install-actions>*{box-sizing:border-box!important;max-width:100%!important;min-width:0!important}
      .bp-install-primary,.bp-install-secondary,#bp-install-fallback-v441{box-sizing:border-box!important;width:100%!important;max-width:100%!important;min-width:0!important}
    }
  </style>
'''
if '</head>' not in web:
    raise SystemExit('V442 head anchor missing')
web=web.replace('</head>',style+'</head>',1)

checks=[
    marker,
    'width:min(100%,calc(100vw - 24px))!important',
    'max-width:calc(100vw - 24px)!important',
    '#bp-install-fallback-v441{box-sizing:border-box!important;max-width:100%!important}',
]
missing=[item for item in checks if item not in web]
if missing:
    raise SystemExit(f'V442 invariant failure: {missing}')

web_path.write_text(web,encoding='utf-8')
print('Applied V442 mobile install-guide viewport clamp: action row and fallback stay fully inside narrow screens.')
