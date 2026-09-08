import re

file_path = r'd:\flutter\readsmart\theapp\lib\screens\story_view_screen.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

old_1 = """      _speech.listen(
        listenFor: const Duration(seconds: 90),
        pauseFor: const Duration(seconds: 5),
        partialResults: true, // Live streaming ng recognized words
        listenMode: stt.ListenMode.dictation,
        onResult: (result) {
          if (!mounted) return;
          setState(() {
            _spokenText = result.recognizedWords;
          });
          _evaluateSpokenStream(_spokenText); // Real-time checking
        },
      );"""

new_1 = """      _speech.startListening((resultText) {
          if (!mounted) return;
          setState(() {
            _spokenText += " " + resultText;
          });
          _evaluateSpokenStream(_spokenText); // Real-time checking
      });"""

content = content.replace(old_1, new_1)

old_2 = """      widget.speech.listen(
        onResult: (result) {
          if (!mounted) return;
          setState(() {
            _remediationSpokenText = result.recognizedWords;
          });
          List<String> spokenWordsClean = _remediationSpokenText
              .toLowerCase()
              .replaceAll(RegExp(r'[^\w\s]'), '')
              .split(RegExp(r'\s+'));
          if (spokenWordsClean.contains(word.cleanWord)) {
            word.isCorrect = true;
            widget.speech.stopListening();
            setState(() {
              _isListeningRemediation = false;
              _statusMessage = "Great job! You pronounced it correctly! A,?";
            });
          }
        },
      );"""

# We'll just replace the start and the result body directly
content = re.sub(r'widget\.speech\.listen\([\s\S]*?onResult: \(result\) \{', r'widget.speech.startListening((resultText) {\n          if (!mounted) return;\n          setState(() {\n            _remediationSpokenText += " " + resultText;\n          });', content)
content = content.replace("result.recognizedWords", "_remediationSpokenText")
content = content.replace("stt.ListenMode.dictation,", "")
content = content.replace("stt.", "")

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
print("done replacing really")
