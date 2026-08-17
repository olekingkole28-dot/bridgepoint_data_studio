from pathlib import Path

main = Path('lib/main.dart')
pubspec = Path('pubspec.yaml')
body = main.read_text(encoding='utf-8')
yaml = pubspec.read_text(encoding='utf-8')
marker = 'bridgepoint-v258-ai-voice-input'

if marker in body:
    print('BridgePoint AI voice input v258 already applied.')
    raise SystemExit(0)

if '  speech_to_text:' not in yaml:
    dep_anchor = '  shared_preferences: ^2.5.5\n'
    if yaml.count(dep_anchor) != 1:
        raise SystemExit(f'v258 dependency anchor count {yaml.count(dep_anchor)}')
    yaml = yaml.replace(dep_anchor, dep_anchor + '  speech_to_text: ^7.4.0\n', 1)
    pubspec.write_text(yaml, encoding='utf-8')

import_anchor = "import 'package:url_launcher/url_launcher.dart';\n"
if body.count(import_anchor) != 1:
    raise SystemExit(f'v258 import anchor count {body.count(import_anchor)}')
body = body.replace(import_anchor, import_anchor + "import 'package:speech_to_text/speech_to_text.dart' as stt;\n", 1)

helper_anchor = 'class _SideNavigation extends StatelessWidget {'
if body.count(helper_anchor) != 1:
    raise SystemExit(f'v258 helper anchor count {body.count(helper_anchor)}')
helper = r'''
final stt.SpeechToText _bridgePointSpeechV258 = stt.SpeechToText();

Future<void> _bridgePointVoiceIntoControllerV258(
  BuildContext context,
  TextEditingController controller,
) async {
  try {
    if (_bridgePointSpeechV258.isListening) {
      await _bridgePointSpeechV258.stop();
      return;
    }
    final available = await _bridgePointSpeechV258.initialize();
    if (!available) {
      if (context.mounted) {
        _showInfoDialog(
          context,
          'Voice search is unavailable',
          'BridgePoint could not start speech recognition on this device or browser. Check microphone permission, or type your question instead.',
        );
      }
      return;
    }
    controller.clear();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          duration: Duration(seconds: 2),
          content: Row(children:[
            Icon(Icons.mic_rounded,color:AppTheme.cyan),
            SizedBox(width:8),
            Expanded(child:Text('Listening… speak your BridgePoint AI question.')),
          ]),
        ),
      );
    }
    await _bridgePointSpeechV258.listen(
      onResult: (result) {
        controller.value = TextEditingValue(
          text: result.recognizedWords,
          selection: TextSelection.collapsed(offset: result.recognizedWords.length),
        );
      },
    );
  } catch (e) {
    if (context.mounted) {
      _showInfoDialog(
        context,
        'Voice search could not start',
        'BridgePoint could not use the microphone right now. You can still type your question.\n\n$e',
      );
    }
  }
}

'''
body = body.replace(helper_anchor, helper + helper_anchor, 1)

prompt_old = """suffixIcon:IconButton(tooltip:'Clear search',icon:const Icon(Icons.close_rounded),onPressed:controller.clear),hintText:'Try “best roofing opportunities near Hartford”'"""
prompt_new = """suffixIcon:Row(mainAxisSize:MainAxisSize.min,children:[IconButton(tooltip:'Talk to BridgePoint AI',icon:const Icon(Icons.mic_rounded,color:AppTheme.cyan),onPressed:()=>_bridgePointVoiceIntoControllerV258(dialogContext,controller)),IconButton(tooltip:'Clear search',icon:const Icon(Icons.close_rounded),onPressed:controller.clear)]),hintText:'Try “best roofing opportunities near Hartford”'"""
if body.count(prompt_old) != 1:
    raise SystemExit(f'v258 prompt voice anchor count {body.count(prompt_old)}')
body = body.replace(prompt_old, prompt_new, 1)

main_old = """suffixIcon:Row(mainAxisSize:MainAxisSize.min,children:[
            IconButton(
              tooltip:'Clear search',
              icon:const Icon(Icons.close_rounded),
              onPressed:(){controller.clear();setState(()=>query='');},
            ),
            IconButton(
              tooltip:'Search',"""
main_new = """suffixIcon:Row(mainAxisSize:MainAxisSize.min,children:[
            IconButton(
              tooltip:'Talk to BridgePoint AI',
              icon:const Icon(Icons.mic_rounded,color:AppTheme.cyan),
              onPressed:()=>_bridgePointVoiceIntoControllerV258(context,controller),
            ),
            IconButton(
              tooltip:'Clear search',
              icon:const Icon(Icons.close_rounded),
              onPressed:(){controller.clear();setState(()=>query='');},
            ),
            IconButton(
              tooltip:'Search',"""
if body.count(main_old) != 1:
    raise SystemExit(f'v258 main AI mic anchor count {body.count(main_old)}')
body = body.replace(main_old, main_new, 1)

helper_old = "helperText:'Tap the text to select the whole search, or use × to clear it.',"
helper_new = "helperText:'Tap the text to select it all, use × to clear, or tap the microphone and speak.',"
if body.count(helper_old) != 1:
    raise SystemExit(f'v258 helper text anchor count {body.count(helper_old)}')
body = body.replace(helper_old, helper_new, 1)

body += "\nconst String _bridgePointAiVoiceV258='bridgepoint-v258-ai-voice-input | Talk to BridgePoint AI | Listening…';\n"
main.write_text(body, encoding='utf-8')
print('Applied customer microphone voice input for BridgePoint AI v258.')
