import re

file_path = r'd:\flutter\readsmart\theapp\lib\screens\story_view_screen.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Replace _speech.listen block
p1 = r"_speech\.listen\([\s\S]*?onResult: \(result\) \{[\s\S]*?_evaluateSpokenStream\(_spokenText\); // Real-time checking\s*\},\s*\);"
r1 = """_speech.startListening((resultText) {
          if (!mounted) return;
          setState(() {
            _spokenText += " " + resultText;
          });
          _evaluateSpokenStream(_spokenText); // Real-time checking
      });"""
content = re.sub(p1, r1, content)

# Replace widget.speech.listen block
p2 = r"widget\.speech\.listen\([\s\S]*?onResult: \(result\) \{[\s\S]*?_remediationSpokenText = result\.recognizedWords;[\s\S]*?setState\(\{\s*_isListeningRemediation = false;[\s\S]*?\}\);\s*\}\s*\}\s*\},[\s\S]*?\);"

r2 = """widget.speech.startListening((resultText) {
        if (!mounted) return;
        setState(() {
          _remediationSpokenText += " " + resultText;
        });
        List<String> spokenWordsClean = _remediationSpokenText
            .toLowerCase()
            .replaceAll(RegExp(r'[^\\w\\s]'), '')
            .split(RegExp(r'\\s+'));
        if (spokenWordsClean.contains(word.cleanWord)) {
          word.isCorrect = true;
          widget.speech.stopListening();
          setState(() {
            _isListeningRemediation = false;
            _statusMessage = "Great job! You pronounced it correctly!";
          });
        }
      });"""
content = re.sub(p2, r2, content)

# Clean up any leftover stt.ListenMode.dictation just in case
content = content.replace("listenMode: stt.ListenMode.dictation,", "")
content = content.replace("listenMode: .dictation,", "")

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
print("done replacing thoroughly")
