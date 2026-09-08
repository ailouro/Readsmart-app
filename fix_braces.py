import re

with open('lib/screens/story_view_screen.dart', 'r', encoding='utf-8') as f:
    text = f.read()

start_marker = "  // \U0001f399\ufe0f START REAL-TIME ORAL READING"
end_marker = "  // \u26A1 INSTANT REAL-TIME EVALUATION"

# if emojis are messed up by encoding, let's just search for the strings:
start_idx = text.find('void _startOralReading() async {')
end_idx = text.find('void _evaluateSpokenStream(String spoken')

if start_idx == -1 or end_idx == -1:
    print("Could not find boundaries")
    exit(1)

# Backtrack start_idx to the comment before it if needed, but we can just replace from start_idx
# to end_idx-1. We need to find the exact comment above _evaluateSpokenStream
# Let's search for "INSTANT REAL-TIME EVALUATION"
end_comment_idx = text.rfind('//', start_idx, end_idx)

new_code = '''void _startOralReading() async {
    await _stopAllAudio();
    if (_isListening) {
      setState(() => _isListening = false);
      await _speech.stop();
      _evaluateSpokenStream(_spokenText, isFinal: true);
      return;
    }

    if (_currentWordIndex >= _targetWords.length) {
      _finishSlideAssessment();
      return;
    }

    setState(() {
      _isListening = true;
      _spokenText = "";
      _processedSpokenWordCount = 0;
    });

    _startListeningLoop();
  }

  void _startListeningLoop() async {
    if (!mounted || !_isListening) return;

    bool available = await _speech.initialize(
      onError: (error) {
        if (mounted && _isListening) {
          Future.delayed(const Duration(seconds: 1), () {
             if (_isListening) _startListeningLoop();
          });
        }
      },
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          if (mounted && _isListening) {
             _evaluateSpokenStream(_spokenText, isFinal: false);
             Future.delayed(const Duration(milliseconds: 500), () {
               if (_isListening) _startListeningLoop();
             });
          }
        }
      },
    );

    if (available && mounted && _isListening) {
      _speech.listen(
        listenFor: const Duration(seconds: 90),
        listenOptions: stt.SpeechListenOptions(pauseFor: const Duration(seconds: 5)),
        partialResults: true,
        listenMode: stt.ListenMode.dictation,
        onResult: (result) {
          if (!mounted || !_isListening) return;
          setState(() {
            _spokenText = result.recognizedWords;
          });
          _evaluateSpokenStream(_spokenText, isFinal: false);
        },
      );
    } else if (!available) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Speech mic error or permission denied.")),
        );
      }
    }
  }

  '''

text = text[:start_idx] + new_code + text[end_comment_idx:]

with open('lib/screens/story_view_screen.dart', 'w', encoding='utf-8') as f:
    f.write(text)

print("Fixed braces")
