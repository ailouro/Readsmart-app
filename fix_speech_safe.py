import re

file_path = r'd:\flutter\readsmart\theapp\lib\screens\story_view_screen.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Imports
content = re.sub(
    r"import 'package:speech_to_text/speech_to_text\.dart' as stt;",
    r"import '../services/speech_services.dart';",
    content
)

# 2. Variable declarations
content = re.sub(
    r"late stt\.SpeechToText _speech;",
    r"final SpeechService _speech = SpeechService();",
    content
)
content = re.sub(
    r"final stt\.SpeechToText speech;",
    r"final SpeechService speech;",
    content
)
content = re.sub(
    r"stt\.SpeechToText speech;",
    r"SpeechService speech;",
    content
)

# 3. Initialization removals
content = re.sub(
    r"_speech = stt\.SpeechToText\(\);",
    r"// _speech initialization removed",
    content
)

# 4. Stop calls
content = re.sub(
    r"_speech\.stop\(\);",
    r"_speech.stopListening();",
    content
)
content = re.sub(
    r"widget\.speech\.stop\(\);",
    r"widget.speech.stopListening();",
    content
)

# 5. _startOralReading initialize replacement
# We need to replace the initialize call block that spans multiple lines
init1_pattern = r"bool available = await _speech\.initialize\([\s\S]*?onStatus: \(status\) \{[\s\S]*?\}\s*,\s*\);"
content = re.sub(init1_pattern, r"bool available = await _speech.initSpeech();", content)

# 6. _startOralReading listen replacement
listen1_pattern = r"_speech\.listen\([\s\S]*?listenOptions: stt\.SpeechListenOptions\([\s\S]*?\),[\s\S]*?onResult: \(result\) \{[\s\S]*?_evaluateSpokenStream\(_spokenText, isFinal: result\.finalResult\);[\s\S]*?\},[\s\S]*?\);"
listen1_repl = """_speech.startListening((resultText) {
        if (!mounted) return;
        setState(() {
          _spokenText += " " + resultText;
        });
        _evaluateSpokenStream(_spokenText, isFinal: false);
      });"""
content = re.sub(listen1_pattern, listen1_repl, content)

# 7. RemediationDialog initialize replacement
content = re.sub(
    r"bool available = await widget\.speech\.initialize\(\);",
    r"bool available = await widget.speech.initSpeech();",
    content
)

# 8. RemediationDialog listen replacement
listen2_pattern = r"widget\.speech\.listen\([\s\S]*?listenOptions: stt\.SpeechListenOptions\([\s\S]*?\),[\s\S]*?onResult: \(result\) \{[\s\S]*?if \(result\.finalResult\) \{[\s\S]*?_evaluateRemediation\(_spokenText\);[\s\S]*?\}[\s\S]*?\}[\s\S]*?\},[\s\S]*?\);"
listen2_repl = """widget.speech.startListening((resultText) {
        if (mounted) {
          setState(() {
            _spokenText += " " + resultText;
          });
          _evaluateRemediation(_spokenText);
        }
      });"""
content = re.sub(listen2_pattern, listen2_repl, content)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
print("done")
