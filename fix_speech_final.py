import re

file_path = r'd:\flutter\readsmart\theapp\lib\screens\story_view_screen.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Fix 1: _startOralReading
old_listen_1 = """      _speech.listen(
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

new_listen_1 = """      _speech.startListening((resultText) {
          if (!mounted) return;
          setState(() {
            _spokenText += " " + resultText;
          });
          _evaluateSpokenStream(_spokenText); // Real-time checking
      });"""

content = content.replace(old_listen_1, new_listen_1)

# Fix 2: Remediation dialog
old_listen_2 = """      widget.speech.listen(
        onResult: (result) {
          if (!mounted) return;
          setState(() {
            _remediationSpokenText = result.recognizedWords;
          });
          List<String> spokenWordsClean = _remediationSpokenText
              .toLowerCase()
              .replaceAll(RegExp(r'[^\w\s]'), '')
              .split(RegExp(r'\s+'));"""

new_listen_2 = """      widget.speech.startListening((resultText) {
          if (!mounted) return;
          setState(() {
            _remediationSpokenText += " " + resultText;
          });
          List<String> spokenWordsClean = _remediationSpokenText
              .toLowerCase()
              .replaceAll(RegExp(r'[^\w\s]'), '')
              .split(RegExp(r'\s+'));"""

content = content.replace(old_listen_2, new_listen_2)

# Fix undefined stt left over
content = content.replace("stt.ListenMode.dictation", "null")
content = re.sub(r'stt\.[a-zA-Z0-9_]+', '', content)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
print("done final fix")
