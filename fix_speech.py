import re

file_path = r'd:\flutter\readsmart\theapp\lib\screens\story_view_screen.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Replace import
content = content.replace("import 'package:speech_to_text/speech_to_text.dart' as stt;", 
                          "import '../services/speech_services.dart';")

# Replace variable declaration
content = content.replace("late stt.SpeechToText _speech;", "final SpeechService _speech = SpeechService();")

# Remove initialization
content = content.replace("_speech = stt.SpeechToText();", "// _speech initialized in declaration")

# Replace stop calls
content = content.replace("_speech.stop()", "_speech.stopListening()")

# Replace RemediationDialog param
content = content.replace("final stt.SpeechToText speech;", "final SpeechService speech;")
content = content.replace("stt.SpeechToText speech;", "SpeechService speech;")

# Rewrite _startOralReading section
old_start = """    bool available = await _speech.initialize(
      onError: (error) {
        if (mounted && _isListening) {
          // If error is timeout, just silently restart
          setState(() => _isListening = false);
          if (_currentWordIndex < _targetWords.length) {
            Future.delayed(const Duration(milliseconds: 100), () {
              if (mounted &&
                  !_isListening &&
                  _currentWordIndex < _targetWords.length) {
                _startOralReading();
              }
            });
          }
        }
      },
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          if (mounted && _isListening) {
            _evaluateSpokenStream(_spokenText, isFinal: true);
            setState(() => _isListening = false);
            if (_currentWordIndex < _targetWords.length) {
              // Auto-restart to make it continuous for the student!
              Future.delayed(const Duration(milliseconds: 100), () {
                if (mounted &&
                    !_isListening &&
                    _currentWordIndex < _targetWords.length) {
                  _startOralReading();
                }
              });
            }
          }
        }
      },
    );
    if (available) {
      setState(() {
        _isListening = true;
        _spokenText = "";
        _processedSpokenWordCount = 0;
      });
      _speech.listen(
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.dictation,
          partialResults: true,
          listenFor: const Duration(minutes: 5),
          pauseFor: const Duration(
            seconds: 4,
          ), // 4 seconds of silence triggers 1 attempt
        ),
        onResult: (result) {
          if (!mounted) return;
          setState(() {
            _spokenText = result.recognizedWords;
          });
          _evaluateSpokenStream(_spokenText, isFinal: result.finalResult);
        },
      );
    } else {"""

new_start = """    bool available = await _speech.initSpeech();
    if (available) {
      setState(() {
        _isListening = true;
        _spokenText = "";
        _processedSpokenWordCount = 0;
      });
      _speech.startListening((resultText) {
          if (!mounted) return;
          setState(() {
            _spokenText += " " + resultText;
          });
          _evaluateSpokenStream(_spokenText, isFinal: false);
      });
    } else {"""

content = content.replace(old_start, new_start)

# Remediation start Listening fix
old_rem_start = """    bool available = await widget.speech.initialize();
    if (available) {
      setState(() {
        _isListening = true;
        _spokenText = "";
      });
      widget.speech.listen(
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.dictation,
          partialResults: true,
          listenFor: const Duration(minutes: 2),
          pauseFor: const Duration(seconds: 4),
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
      );
    }"""

new_rem_start = """    bool available = await widget.speech.initSpeech();
    if (available) {
      setState(() {
        _isListening = true;
        _spokenText = "";
      });
      widget.speech.startListening((resultText) {
        if (mounted) {
          setState(() {
            _spokenText += " " + resultText;
          });
          _evaluateRemediation(_spokenText);
        }
      });
    }"""

content = content.replace(old_rem_start, new_rem_start)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
print("done")
