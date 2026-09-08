import re

file_path = r'd:\flutter\readsmart\theapp\lib\screens\story_view_screen.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

old_rem_start = """      widget.speech.listen(
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.dictation,
          partialResults: true,
          listenFor: const Duration(seconds: 15),
          pauseFor: const Duration(seconds: 3),
        ),
        onResult: (result) {
          if (mounted) {
            setState(() {
              _spokenText = result.recognizedWords;
            });
            if (result.finalResult) {
              _evaluateRemediation(_spokenText);
            }
          }
        },
      );"""

new_rem_start = """      widget.speech.startListening((resultText) {
        if (mounted) {
          setState(() {
            _spokenText += " " + resultText;
          });
          _evaluateRemediation(_spokenText);
        }
      });"""

content = content.replace(old_rem_start, new_rem_start)

# In case there's another variation, let's just do a regex replace for widget.speech.listen
content = re.sub(r'widget\.speech\.listen\([^;]+;', new_rem_start + ';', content)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
print("done")
