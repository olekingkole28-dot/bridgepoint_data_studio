from pathlib import Path
p=Path('lib/main.dart')
s=p.read_text(encoding='utf-8')
marker='// bridgepoint-property-national-polish-v730'
if marker not in s:
    s=s.replace('// bridgepoint-visible-national-v728','// bridgepoint-visible-national-v728\n'+marker,1)

s=s.replace("title: 'Connecticut Properties',","title: 'Authorized Properties',")
old="""    final displayAddress = address.trim().isEmpty || address == '${property['postal_code']}, CT'
        ? '$municipality, CT • $parcel'
        : address;"""
new="""    final state=(property['state_code']??'').toString().trim();
    final postal=(property['postal_code']??'').toString().trim();
    final weakAddress=address.trim().isEmpty || (postal.isNotEmpty&&state.isNotEmpty&&address.trim()=='$postal, $state');
    final displayAddress = weakAddress
        ? [municipality,state].where((v)=>v.isNotEmpty).join(', ')+' • $parcel'
        : address;"""
if old in s:
    s=s.replace(old,new,1)
elif "final state=(property['state_code']??'').toString().trim();" not in s:
    raise SystemExit('V730 dynamic-state address anchor missing')

old_url="String _url(Map<String,dynamic> item)=>'${item['media_url']??item['thumbnail_url']??''}'.trim();"
new_url="""String _url(Map<String,dynamic> item){
    final thumb='${item['thumbnail_url']??''}'.trim();
    final media='${item['media_url']??''}'.trim();
    if(thumb.isNotEmpty)return thumb;
    if(media.contains('{{sizeprefix}}'))return media.replaceAll('{{sizeprefix}}','th');
    return media;
  }"""
if old_url in s:
    s=s.replace(old_url,new_url,1)
elif 'media.contains(\'{{sizeprefix}}\')' not in s:
    # V729 may not have been applied yet; its first workflow step will add the old helper before this runs.
    pass

for needle in [marker,"title: 'Authorized Properties',","final state=(property['state_code']??'').toString().trim();"]:
    if needle not in s: raise SystemExit('V730 missing '+needle)
p.write_text(s,encoding='utf-8')
print('Applied V730 national property list polish')
