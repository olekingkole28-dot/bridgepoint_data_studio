from pathlib import Path

path = Path('lib/main.dart')
body = path.read_text(encoding='utf-8')
marker = 'bridgepoint-v257-ai-search-ux'

if marker in body:
    print('BridgePoint AI search UX v257 already applied.')
    raise SystemExit(0)

old_error = "if(snapshot.hasError)return Center(child:_DashboardError(message:snapshot.error.toString(),onRetry:()=>_search(query)));"
new_error = "if(snapshot.hasError)return Center(child:_DashboardError(title:'BridgePoint AI search could not load',message:snapshot.error.toString(),onRetry:()=>_search(query)));"
if body.count(old_error) != 1:
    raise SystemExit(f'v257 AI error anchor count {body.count(old_error)}')
body = body.replace(old_error, new_error, 1)

old_field = """TextField(controller:controller,textInputAction:TextInputAction.search,onSubmitted:_search,decoration:InputDecoration(prefixIcon:const Icon(Icons.search_rounded,color:AppTheme.cyan),suffixIcon:IconButton(icon:const Icon(Icons.arrow_forward_rounded),onPressed:()=>_search(controller.text)),hintText:'Ask about a property, place, event, opportunity or BridgePoint tool',border:const OutlineInputBorder()))"""
new_field = """TextField(
        controller:controller,
        textInputAction:TextInputAction.search,
        onTap:(){
          if(controller.text.isNotEmpty){
            controller.selection=TextSelection(baseOffset:0,extentOffset:controller.text.length);
          }
        },
        onSubmitted:_search,
        decoration:InputDecoration(
          prefixIcon:const Icon(Icons.search_rounded,color:AppTheme.cyan),
          suffixIcon:Row(mainAxisSize:MainAxisSize.min,children:[
            IconButton(
              tooltip:'Clear search',
              icon:const Icon(Icons.close_rounded),
              onPressed:(){controller.clear();setState(()=>query='');},
            ),
            IconButton(
              tooltip:'Search',
              icon:const Icon(Icons.arrow_forward_rounded),
              onPressed:()=>_search(controller.text),
            ),
          ]),
          hintText:'Ask about a property, place, event, opportunity or BridgePoint tool',
          helperText:'Tap the text to select the whole search, or use × to clear it.',
          border:const OutlineInputBorder(),
        ),
      )"""
if body.count(old_field) != 1:
    raise SystemExit(f'v257 AI field anchor count {body.count(old_field)}')
body = body.replace(old_field, new_field, 1)

prompt_old = """TextField(controller:controller,autofocus:true,textInputAction:TextInputAction.search,onSubmitted:(q){Navigator.pop(dialogContext);onSearch(q);},decoration:const InputDecoration(prefixIcon:Icon(Icons.search_rounded),hintText:'Try “best roofing opportunities near Hartford”',border:OutlineInputBorder()))"""
prompt_new = """TextField(controller:controller,autofocus:true,textInputAction:TextInputAction.search,onSubmitted:(q){Navigator.pop(dialogContext);onSearch(q);},decoration:InputDecoration(prefixIcon:const Icon(Icons.search_rounded),suffixIcon:IconButton(tooltip:'Clear search',icon:const Icon(Icons.close_rounded),onPressed:controller.clear),hintText:'Try “best roofing opportunities near Hartford”',border:const OutlineInputBorder()))"""
if body.count(prompt_old) != 1:
    raise SystemExit(f'v257 AI prompt field anchor count {body.count(prompt_old)}')
body = body.replace(prompt_old, prompt_new, 1)

body += "\nconst String _bridgePointAiSearchUxV257='bridgepoint-v257-ai-search-ux | BridgePoint AI search could not load | Clear search';\n"
path.write_text(body, encoding='utf-8')
print('Applied BridgePoint AI section-aware error and clear/replace search UX v257.')
