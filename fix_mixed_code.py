import re

user_content = """import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Para sa Vibration / Haptic Feedback
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../widgets/story_comic_background.dart';
import 'package:theapp/screens/quiz_screen.dart';

class WordStatus {
  final String originalWord;
  final String cleanWord;
  bool isCorrect;
  bool isFailed;

  WordStatus({
    required this.originalWord,
    required this.cleanWord,
    this.isCorrect = false,
    this.isFailed = false,
  });
}

class StoryViewerScreen extends StatefulWidget {
  final dynamic story;
  final String baseUrl;
  final int studentId;

  const StoryViewerScreen({
    super.key,
    required this.story,
    required this.baseUrl,
    this.studentId = 1, // Default ID kung hindi ipinasa
  });

  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Audio & Speech Engines
  final AudioPlayer _audioPlayer = AudioPlayer();
  final FlutterTts _flutterTts = FlutterTts();
  late stt.SpeechToText _speech;

  // General State
  bool _isPlayingServerAudio = false;
  bool _isPlayingTts = false;
  int? _playingIndex;
  bool _isGenerating = false;
  DateTime? _readingStartTime;
  int _totalWordsInStory = 0;

  // ðŸŽ™ï¸ Real-Time Assessment Tracking
  bool _isListening = false;
  String _spokenText = "";
  List<WordStatus> _targetWords = [];
  int _currentWordIndex = 0;
  int _currentWordAttempts = 0;
  int _processedSpokenWordCount =
      0; // Taga-subaybay sa bawat salitang binabanggit sa live mic
  final int _maxWordAttempts = 3;
  bool _isAssessmentPassed = false;

  // Page State Caching
  final Map<int, List<WordStatus>> _pageTargetWords = {};
  final Map<int, int> _pageCurrentWordIndex = {};
  final Map<int, bool> _pageAssessmentPassed = {};

  // Image Future Caching
  final Map<int, Future<http.Response>> _imageFutures = {};

  @override
  void initState() {
    super.initState();
    _readingStartTime = DateTime.now();
    _speech = stt.SpeechToText();
    _initTtsEngine();
    _initAudioPlayerListeners();
    _loadSavedPage();
  }

  Future<void> _loadSavedPage() async {
    final prefs = await SharedPreferences.getInstance();
    int? savedPage = prefs.getInt('story_${widget.story['id']}_page');
    if (savedPage != null && savedPage > 0) {
      List<dynamic> pages = widget.story['pages'] ?? [];
      if (savedPage < pages.length) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_pageController.hasClients) {
            _pageController.jumpToPage(savedPage);
          }
        });
      }
    }
  }

  Future<http.Response> _getImageFuture(int index, String imageUrl) {
    return _imageFutures.putIfAbsent(
      index,
      () => http.get(
        Uri.parse(imageUrl),
        headers: const {"ngrok-skip-browser-warning": "69420"},
      ),
    );
  }

  void _setupTargetWords(String fullScriptText) {
    if (fullScriptText.trim().isEmpty) {
      _targetWords = [];
      return;
    }
    List<String> rawWords = fullScriptText.split(RegExp(r'\s+'));
    _targetWords = rawWords.map((word) {
      String cleaned = word.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '');
      return WordStatus(originalWord: word, cleanWord: cleaned);
    }).toList();
    _currentWordIndex = 0;
    _currentWordAttempts = 0;
    _processedSpokenWordCount = 0;
    _isAssessmentPassed = false;
    _spokenText = "";
  }

  void _initTtsEngine() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.45);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
    await _flutterTts.awaitSpeakCompletion(true);
    _flutterTts.setStartHandler(() {
      if (mounted) setState(() => _isPlayingTts = true);
    });
    _flutterTts.setCompletionHandler(() {
      if (mounted) {
        setState(() {
          _isPlayingTts = false;
          _playingIndex = null;
        });
      }
    });
  }

  Future<void> _showWordDefinition(String originalWord) async {
    String cleanWord = originalWord.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '');
    if (cleanWord.isEmpty) return;

    // Read it aloud automatically
    await _flutterTts.speak(originalWord);

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _DefinitionSheet(
          originalWord: originalWord,
          cleanWord: cleanWord,
          flutterTts: _flutterTts,
        );
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    List<dynamic> pages = widget.story['pages'] ?? [];
    for (var page in pages) {
      if (page['image_path'] != null) {
        String url = widget.baseUrl + "/storage/" + page['image_path'];
        precacheImage(
          NetworkImage(
            url,
            headers: const {"ngrok-skip-browser-warning": "69420"},
          ),
          context,
        );
      }
    }
  }

  void _initAudioPlayerListeners() {
    _audioPlayer.onPlayerStateChanged.listen((PlayerState state) {
      if (mounted) {
        setState(() {
          _isPlayingServerAudio = state == PlayerState.playing;
          if (!_isPlayingServerAudio && !_isPlayingTts) {
            _playingIndex = null;
          }
        });
      }
    });
  }

  Future<void> _stopAllAudio() async {
    await _flutterTts.stop();
    await _audioPlayer.stop();
    if (_isListening) {
      await _speech.stop();
    }
    if (mounted) {
      setState(() {
        _isPlayingTts = false;
        _isPlayingServerAudio = false;
        _isListening = false;
        _playingIndex = null;
      });
    }
  }

  Future<void> _speakWebSpeech(int sIndex, String text) async {
    if (text.trim().isEmpty) return;
    if (_isPlayingTts && _playingIndex == sIndex) {
      await _stopAllAudio();
      return;
    }
    await _stopAllAudio();
    setState(() => _playingIndex = sIndex);
    await _flutterTts.speak(text);
  }

  Future<void> _playServerAudio(int sIndex, String cleanBaseUrl) async {
    if (_isPlayingServerAudio && _playingIndex == sIndex) {
      await _stopAllAudio();
      return;
    }
    await _stopAllAudio();
    setState(() => _playingIndex = sIndex);
    String audioUrl =
        "$cleanBaseUrl/api/get-audio?story_id=${widget.story['id']}&page_index=$_currentPage&script_index=$sIndex";
    try {
      final response = await http.get(
        Uri.parse(audioUrl),
        headers: const {"ngrok-skip-browser-warning": "69420"},
      );
      if (response.statusCode == 200) {
        await _audioPlayer.play(BytesSource(response.bodyBytes));
      } else {
        throw Exception("Audio not found");
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _playingIndex = null);
      _speakWebSpeech(
        sIndex,
        widget.story['pages'][_currentPage]['audio_scripts'][sIndex],
      );
    }
  }

  Future<void> _generateAIVoice(int sIndex, String text) async {
    if (text.trim().isEmpty) return;
    setState(() => _isGenerating = true);
    try {
      final url = Uri.parse(
        "${widget.baseUrl}/api/stories/${widget.story['id']}/slides/$_currentPage/generate-tts",
      );
      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "ngrok-skip-browser-warning": "69420",
        },
        body: jsonEncode({"text": text, "script_index": sIndex, "lang": "en"}),
      );
      if (!mounted) return;
      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("AI Voice Generated Successfully!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error generating voice: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  //  // START REAL-TIME ORAL READING
  void _startOralReading() async {
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
    bool available = await _speech.initialize(
      onError: (error) {
        if (mounted && _isListening) {
          // If error is timeout, just silently restart
          setState(() => _isListening = false);
          if (_currentWordIndex < _targetWords.length) {
            Future.delayed(const Duration(milliseconds: 100), () {
              if (mounted && !_isListening && _currentWordIndex < _targetWords.length) {
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
                if (mounted && !_isListening && _currentWordIndex < _targetWords.length) {
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
          pauseFor: const Duration(seconds: 4), // 4 seconds of silence triggers 1 attempt
        ),
        onResult: (result) {
          if (!mounted) return;
          setState(() {
            _spokenText = result.recognizedWords;
          });
          _evaluateSpokenStream(_spokenText, isFinal: result.finalResult); 
        },
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Speech mic error or permission denied.")),
      );
    }
  }

  // INSTANT REAL-TIME EVALUATION
  void _evaluateSpokenStream(String spoken, {bool isFinal = false}) {
    if (spoken.trim().isEmpty || _currentWordIndex >= _targetWords.length) {
      return;
    }
    List<String> spokenWordsList = spoken
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();

    if (spokenWordsList.length < _processedSpokenWordCount) {
      _processedSpokenWordCount = 0;
    }

    bool advanced = false;

    // Look for target words anywhere in the NEW unconsumed STT words
    while (_currentWordIndex < _targetWords.length) {
      WordStatus currentTarget = _targetWords[_currentWordIndex];
      bool found = false;

      for (int i = _processedSpokenWordCount; i < spokenWordsList.length; i++) {
        if (spokenWordsList[i] == currentTarget.cleanWord) {
          found = true;
          _processedSpokenWordCount = i + 1;
          break;
        }
      }

      if (found) {
        setState(() {
          currentTarget.isCorrect = true;
          currentTarget.isFailed = false;
          _currentWordAttempts = 0;
          _currentWordIndex++;
        });
        advanced = true;
      } else {
        break; 
      }
    }

    // If STT finalized (due to 4s pause), and they didn't get the word right, count as 1 attempt!
    if (isFinal && !advanced && _currentWordIndex < _targetWords.length) {
      WordStatus currentTarget = _targetWords[_currentWordIndex];
      
      HapticFeedback.vibrate();
      setState(() {
        _currentWordAttempts++;
        if (_currentWordAttempts >= _maxWordAttempts) {
          currentTarget.isFailed = true;
          currentTarget.isCorrect = false;
          _currentWordAttempts = 0;
          _currentWordIndex++;
        }
      });
      _processedSpokenWordCount = spokenWordsList.length;
    }

    if (_currentWordIndex >= _targetWords.length) {
      _stopAllAudio();
      _finishSlideAssessment();
    }
  }

  // PAGKATAPOS BASAHIN ANG SLIDE
  void _finishSlideAssessment() async {
    await _stopAllAudio();
    List<WordStatus> failedWords = _targetWords
        .where((w) => w.isFailed && !w.isCorrect)
        .toList();

    if (failedWords.isEmpty) {
      setState(() => _isAssessmentPassed = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("ðŸŽ‰ Excellent! Moving to the next slide..."),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
      // ðŸš€ AUTOMATIC NA LILIPAT SA SUSUNOD NA SLIDE
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          _advanceToNextSlide();
        }
      });
    } else {
      // Magpapakita ng Popup para sa remediation ng maling salita
      _triggerRemediationPopup(failedWords);
    }
  }

  // âž¡ï¸ AUTOMATIC NEXT SLIDE LOGIC
  void _advanceToNextSlide() async {
    List<dynamic> pages = widget.story['pages'] ?? [];
    if (_currentPage < pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    } else {
      int elapsedSeconds = 120;
      if (_readingStartTime != null) {
        elapsedSeconds = DateTime.now()
            .difference(_readingStartTime!)
            .inSeconds;
      }

      double accuracy = 100.0;
      if (_processedSpokenWordCount > 0) accuracy = 92.0;

      try {
        await http.post(
          Uri.parse("${widget.baseUrl}/api/student/progress"),
          headers: {
            "Content-Type": "application/json",
            "ngrok-skip-browser-warning": "69420",
          },
          body: jsonEncode({
            "user_id": widget.studentId,
            "story_id": widget.story['id'] ?? widget.story['_id'],
            "quiz_score": 0,
            "total_questions": 0,
            "oral_fluency_accuracy": accuracy,
            "time_on_task": elapsedSeconds > 0 ? elapsedSeconds : 1,
            "test_type": "post_test",
          }),
        );
      } catch (e) {}

      // Save locally so the Dashboard shows "Done Reading" immediately!
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('story_${widget.story['id']}_reading_completed', true);

      bool hasQuiz =
          widget.story['quiz'] != null &&
          (widget.story['quiz'] is List
              ? (widget.story['quiz'] as List).isNotEmpty
              : true);

      if (hasQuiz) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => QuizScreen(
              storyId: widget.story['id'] ?? widget.story['_id'],
              studentId: widget.studentId,
              baseUrl: widget.baseUrl,
              oralAccuracy: accuracy,
              totalWords: _totalWordsInStory,
              readingTimeSeconds: elapsedSeconds > 0 ? elapsedSeconds : 1,
            ),
          ),
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Reading Completed!"),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      }
    }
  }

  //
  void _triggerRemediationPopup(List<WordStatus> failedWords) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return RemediationDialog(
          failedWords: failedWords,
          flutterTts: _flutterTts,
          speech: _speech,
          onCompleted: (remainingUncorrectedWords) async {
            Navigator.of(context).pop();
            if (remainingUncorrectedWords.isNotEmpty) {
              List<String> failedStrings = remainingUncorrectedWords
                  .map((w) => w.originalWord)
                  .toList();
              await _notifyTeacherOfFailedWords(failedStrings);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    "Report sent to teacher. Moving to the next slide!",
                  ),
                  backgroundColor: Colors.deepOrange,
                  duration: Duration(seconds: 3),
                ),
              );
            }
            setState(() => _isAssessmentPassed = true);
            // ðŸš€ DERECHO DIN SA NEXT SLIDE PAGKATAPOS NG REMEDIATION
            Future.delayed(const Duration(milliseconds: 1000), () {
              if (mounted) {
                _advanceToNextSlide();
              }
            });
          },
        );
      },
    );
  }

  // ðŸ“¡ IPAPADALA SA LARAVEL BACKEND
  Future<void> _notifyTeacherOfFailedWords(List<String> failedWords) async {
    if (failedWords.isEmpty) return;
    try {
      final url = Uri.parse("${widget.baseUrl}/api/student-mispronunciations");
      await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "ngrok-skip-browser-warning": "69420",
        },
        body: jsonEncode({
          "student_id": widget.studentId,
          "story_id": widget.story['id'],
          "words": failedWords, // Updated key from "failed_words" to "words"
        }),
      );
    } catch (e) {
      debugPrint("Failed sending notification to teacher: $e");
    }
  }

  Future<void> _saveFinalProgress() async {
    try {
      final url = Uri.parse("${widget.baseUrl}/api/student/progress");
      await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "ngrok-skip-browser-warning": "69420",
        },
        body: jsonEncode({
          "user_id": widget.studentId,
          "story_id": widget.story['id'],
          "quiz_score": 0, // Updated later after student takes the quiz
          "total_questions": 5,
          "oral_fluency_accuracy": 92.0, // Calculated oral accuracy percentage
          "time_on_task": 120, // Reading time in seconds
          "test_type": "post_test",
        }),
      );
    } catch (e) {
      debugPrint("Error saving final progress: $e");
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _flutterTts.stop();
    _audioPlayer.dispose();
    _speech.stopListening();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    List<dynamic> pages = widget.story['pages'] ?? [];
    String cleanBaseUrl = widget.baseUrl.endsWith('/api')
        ? widget.baseUrl.substring(0, widget.baseUrl.length - 4)
        : widget.baseUrl;
    List<String> currentScripts = [];
    if (pages.isNotEmpty && _currentPage < pages.length) {
      var rawScripts = pages[_currentPage]['audio_scripts'];
      if (rawScripts is List) {
        currentScripts = rawScripts.map((e) => e.toString()).toList();
      } else if (rawScripts is String && rawScripts.isNotEmpty) {
        currentScripts = [rawScripts];
      }
    }
    String fullTargetText = currentScripts.join(" ");
    if (_targetWords.isEmpty && fullTargetText.isNotEmpty) {
      _setupTargetWords(fullTargetText);
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          widget.story['title'] ?? "Story Preview",
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 24,
            shadows: [Shadow(color: Colors.black, offset: Offset(2, 2))],
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          if (_isGenerating)
            const Padding(
              padding: EdgeInsets.only(right: 16.0),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: StoryComicBackground(
        child: SafeArea(
          child: pages.isEmpty
              ? const Center(
                  child: Text(
                    "No pages found.",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              : Column(
                  children: [
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        physics: const NeverScrollableScrollPhysics(),
                        onPageChanged: (index) async {
                          // Save current page state before switching
                          _pageTargetWords[_currentPage] = List.from(_targetWords);
                          _pageCurrentWordIndex[_currentPage] = _currentWordIndex;
                          _pageAssessmentPassed[_currentPage] = _isAssessmentPassed;

                          setState(() {
                            _currentPage = index;
                            if (_pageTargetWords.containsKey(index)) {
                              _targetWords = List.from(_pageTargetWords[index]!);
                              _currentWordIndex = _pageCurrentWordIndex[index]!;
                              _isAssessmentPassed = _pageAssessmentPassed[index]!;
                            } else {
                              _targetWords = [];
                              _currentWordIndex = 0;
                              _isAssessmentPassed = false;
                            }
                            _currentWordAttempts = 0;
                            _spokenText = "";
                            _isListening = false;
                          });

                          if (!_pageTargetWords.containsKey(index)) {
                            _setupTargetWords(
                              pages[index]['audio_scripts']?.toString() ?? "",
                            );
                          }
                          final prefs = await SharedPreferences.getInstance();
                          prefs.setInt('story_${widget.story['id']}_page', index);
                        },
                        itemCount: pages.length,
                        itemBuilder: (context, index) {
                          var page = pages[index];
                          String pageImagePath = page['image_path'] ?? "";
                          if (pageImagePath.startsWith('public/')) {
                            pageImagePath = pageImagePath.replaceFirst(
                              'public/',
                              '',
                            );
                          }
                          String imageUrl =
                              "$cleanBaseUrl/api/get-image?path=$pageImagePath";

                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 10,
                            ),
                            child: Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8.0),
                                  child: Text(
                                    "Slide ${index + 1} of ${pages.length}",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black,
                                          offset: Offset(2, 2),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                if (pageImagePath.isNotEmpty)
                                  Expanded(
                                    child: Container(
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: Colors.black,
                                          width: 4,
                                        ),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Colors.black,
                                            offset: Offset(6, 6),
                                          ),
                                        ],
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.network(
                                          imageUrl,
                                          fit: BoxFit.contain,
                                          headers: const {
                                            "ngrok-skip-browser-warning":
                                                "69420",
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 20),
                                if (currentScripts.isNotEmpty)
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.amberAccent,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: Colors.black,
                                        width: 3,
                                      ),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Colors.black,
                                          offset: Offset(4, 4),
                                        ),
                                      ],
                                    ),
                                    child: Wrap(
                                      alignment: WrapAlignment.center,
                                      spacing: 4.0,
                                      runSpacing: 4.0,
                                      children: currentScripts.join(" ").split(RegExp(r'\s+')).map((word) {
                                        return GestureDetector(
                                          onTap: () {
                                            _showWordDefinition(word);
                                          },
                                          child: Text(
                                            word,
                                            style: const TextStyle(
                                              color: Colors.black,
                                              fontSize: 18,
                                              fontWeight: FontWeight.w900,
                                              decoration: TextDecoration.underline,
                                              decorationStyle: TextDecorationStyle.dotted,
                                              decorationColor: Colors.black54,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    // CONTROLS PANEL
                    Container(
                      width: double.infinity,
                      color: Colors.transparent,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              ElevatedButton.icon(
                                onPressed: _currentPage > 0
                                    ? () {
                                        _pageController.previousPage(
                                          duration: const Duration(milliseconds: 300),
                                          curve: Curves.easeInOut,
                                        );
                                      }
                                    : null,
                                icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                                label: const Text(
                                  "Prev",
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blueAccent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: const BorderSide(color: Colors.black, width: 2),
                                  ),
                                ),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  _advanceToNextSlide();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: const BorderSide(color: Colors.black, width: 2),
                                  ),
                                ),
                                child: Row(
                                  children: const [
                                    Text(
                                      "Next",
                                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                                    ),
                                    SizedBox(width: 4),
                                    Icon(Icons.arrow_forward, color: Colors.white, size: 20),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(15),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black,
                                  offset: Offset(4, 4),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(15),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(15),
                                onTap: _currentWordIndex < _targetWords.length
                                    ? _startOralReading
                                    : null,
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _isListening
                                        ? Colors.redAccent
                                        : (_currentWordIndex >=
                                                  _targetWords.length
                                              ? Colors.grey
                                              : Colors.tealAccent[400]),
                                    borderRadius: BorderRadius.circular(15),
                                    border: Border.all(
                                      color: Colors.black,
                                      width: 3,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        _isListening ? Icons.stop : Icons.mic,
                                        color: Colors.black,
                                        size: 24,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _isListening
                                            ? "Stop Oral Reading"
                                            : (_currentWordIndex <
                                                      _targetWords.length
                                                  ? "Start Oral Reading 🎙️"
                                                  : "Completed!"),
                                        style: const TextStyle(
                                          color: Colors.black,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (_targetWords.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              "Attempt: $_currentWordAttempts / $_maxWordAttempts",
                              style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                                shadows: [
                                  Shadow(
                                    color: Colors.white,
                                    offset: Offset(1, 1),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: _targetWords.asMap().entries.map((
                                entry,
                              ) {
                                int wIndex = entry.key;
                                WordStatus wStatus = entry.value;

                                Color chipColor = Colors.white;
                                Color borderColor = Colors.black;
                                Color textColor = Colors.black;

                                if (wStatus.isCorrect) {
                                  chipColor = Colors.greenAccent;
                                } else if (wIndex == _currentWordIndex &&
                                    _isListening) {
                                  chipColor = Colors.amberAccent;
                                  borderColor = Colors.redAccent;
                                }

                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: chipColor,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: borderColor,
                                      width: 2,
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Colors.black,
                                        offset: Offset(2, 2),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    wStatus.originalWord,
                                    style: TextStyle(
                                      color: textColor,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 13,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                          const SizedBox(height: 12),
                          Column(
                            children: currentScripts.asMap().entries.map((
                              entry,
                            ) {
                              int sIndex = entry.key;
                              String currentText = entry.value;

                              bool isThisTtsPlaying =
                                  _isPlayingTts && _playingIndex == sIndex;
                              bool isThisServerPlaying =
                                  _isPlayingServerAudio &&
                                  _playingIndex == sIndex;

                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4.0,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          boxShadow: const [
                                            BoxShadow(
                                              color: Colors.black,
                                              offset: Offset(3, 3),
                                            ),
                                          ],
                                        ),
                                        child: ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: isThisTtsPlaying
                                                ? Colors.redAccent
                                                : const Color(0xFF9B0505),
                                            foregroundColor: Colors.white,
                                            elevation: 0,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 10,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              side: const BorderSide(
                                                color: Colors.black,
                                                width: 2.5,
                                              ),
                                            ),
                                          ),
                                          icon: Icon(
                                            isThisTtsPlaying
                                                ? Icons.stop
                                                : Icons.record_voice_over,
                                            size: 18,
                                          ),
                                          label: Text(
                                            isThisTtsPlaying
                                                ? "Stop TTS"
                                                : "Listen",
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                          onPressed: _isGenerating
                                              ? null
                                              : () => _speakWebSpeech(
                                                  sIndex,
                                                  currentText,
                                                ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black,
                                            offset: Offset(2, 2),
                                          ),
                                        ],
                                      ),
                                      child: IconButton(
                                        style: IconButton.styleFrom(
                                          backgroundColor: isThisServerPlaying
                                              ? Colors.amber[800]
                                              : Colors.blueAccent,
                                          foregroundColor: Colors.white,
                                          shape: const CircleBorder(
                                            side: BorderSide(
                                              color: Colors.black,
                                              width: 2.5,
                                            ),
                                          ),
                                        ),
                                        icon: Icon(
                                          isThisServerPlaying
                                              ? Icons.stop
                                              : Icons.volume_up,
                                          size: 20,
                                        ),
                                        onPressed: _isGenerating
                                            ? null
                                            : () => _playServerAudio(
                                                sIndex,
                                                cleanBaseUrl,
                                              ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black,
                                            offset: Offset(2, 2),
                                          ),
                                        ],
                                      ),
                                      child: IconButton(
                                        style: IconButton.styleFrom(
                                          backgroundColor: const Color(
                                            0xFF2D3142,
                                          ),
                                          foregroundColor: Colors.white,
                                          shape: const CircleBorder(
                                            side: BorderSide(
                                              color: Colors.black,
                                              width: 2.5,
                                            ),
                                          ),
                                        ),
                                        icon: const Icon(
                                          Icons.auto_awesome,
                                          color: Colors.amberAccent,
                                          size: 20,
                                        ),
                                        onPressed: _isGenerating
                                            ? null
                                            : () => _generateAIVoice(
                                                sIndex,
                                                currentText,
                                              ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// 🔊 REMEDIATION POPUP DIALOG COMPONENT
class RemediationDialog extends StatefulWidget {
  final List<WordStatus> failedWords;
  final FlutterTts flutterTts;
  final SpeechService speech;
  final Function(List<WordStatus> remainingUncorrected) onCompleted;

  const RemediationDialog({
    super.key,
    required this.failedWords,
    required this.flutterTts,
    required this.speech,
    required this.onCompleted,
  });

  @override
  State<RemediationDialog> createState() => _RemediationDialogState();
}

class _RemediationDialogState extends State<RemediationDialog> {
  int _currentIndex = 0;
  bool _isPlayingAudio3Times = false;
  bool _isListeningRemediation = false;
  String _remediationSpokenText = "";
  String _statusMessage = "Listen closely to the correct pronunciation!";

  @override
  void initState() {
    super.initState();
    _startWordTutoring();
  }

  Future<void> _startWordTutoring() async {
    if (_currentIndex >= widget.failedWords.length) {
      List<WordStatus> stillFailed = widget.failedWords
          .where((w) => !w.isCorrect)
          .toList();
      widget.onCompleted(stillFailed);
      return;
    }
    WordStatus currentWord = widget.failedWords[_currentIndex];
    setState(() {
      _isPlayingAudio3Times = true;
      _statusMessage = "Listen 3 times: \\"${currentWord.originalWord}\\"";
    });

    for (int i = 0; i < 3; i++) {
      if (!mounted) return;
      await widget.flutterTts.speak(currentWord.originalWord);
      await Future.delayed(const Duration(milliseconds: 1200));
    }

    if (!mounted) return;
    setState(() {
      _statusMessage = "It's your turn! Speak now 🎙️";
    });
    await widget.flutterTts.speak("It's your turn!");
    await Future.delayed(const Duration(milliseconds: 1400));
    setState(() => _isPlayingAudio3Times = false);
    _listenStudentRetry(currentWord);
  }

  void _listenStudentRetry(WordStatus word) async {
    bool available = await widget.speech.initSpeech();
    if (available) {
      setState(() {
        _isListeningRemediation = true;
        _remediationSpokenText = "";
      });
      widget.speech.startListening((resultText) {
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
            _statusMessage = "Great job! You pronounced it correctly! 🎉";
          });
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted) {
              setState(() => _currentIndex++);
              _startWordTutoring();
            }
          });
        }
      });
    }
  }

  void _skipToNextWord() {
    widget.speech.stopListening();
    setState(() {
      _isListeningRemediation = false;
      _currentIndex++;
    });
    _startWordTutoring();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentIndex >= widget.failedWords.length) {
      return const SizedBox.shrink();
    }
    WordStatus currentWord = widget.failedWords[_currentIndex];
    return AlertDialog(
      backgroundColor: Colors.grey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(
            _isListeningRemediation ? Icons.mic : Icons.record_voice_over,
            color: _isListeningRemediation ? Colors.redAccent : Colors.amber,
          ),
          const SizedBox(width: 8),
          const Text(
            "Let's Practice!",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "Word ${_currentIndex + 1} of ${widget.failedWords.length}",
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.red[900],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              currentWord.originalWord,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isListeningRemediation)
                const Padding(
                  padding: EdgeInsets.only(right: 6.0),
                  child: Icon(Icons.circle, color: Colors.redAccent, size: 10),
                ),
              Flexible(
                child: Text(
                  _statusMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _isListeningRemediation
                        ? Colors.redAccent
                        : Colors.amberAccent,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          if (_remediationSpokenText.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              "Heard: \\"$_remediationSpokenText\\"",
              style: const TextStyle(
                color: Colors.white70,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
      actions: [
        if (!_isPlayingAudio3Times)
          TextButton(
            onPressed: _skipToNextWord,
            child: const Text(
              "Next Word / Continue",
              style: TextStyle(color: Colors.grey),
            ),
          ),
      ],
    );
  }
}

class _DefinitionSheet extends StatefulWidget {
  final String originalWord;
  final String cleanWord;
  final FlutterTts flutterTts;

  const _DefinitionSheet({
    required this.originalWord,
    required this.cleanWord,
    required this.flutterTts,
  });

  @override
  State<_DefinitionSheet> createState() => _DefinitionSheetState();
}

class _DefinitionSheetState extends State<_DefinitionSheet> {
  bool _isLoading = true;
  String _definition = '';
  String _partOfSpeech = '';

  @override
  void initState() {
    super.initState();
    _fetchDefinition();
  }

  Future<void> _fetchDefinition() async {
    try {
      final response = await http.get(Uri.parse('https://api.dictionaryapi.dev/api/v2/entries/en/${widget.cleanWord}'));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (data.isNotEmpty && data[0]['meanings'].isNotEmpty) {
          final firstMeaning = data[0]['meanings'][0];
          final pos = firstMeaning['partOfSpeech'] ?? '';
          if (firstMeaning['definitions'].isNotEmpty) {
            final def = firstMeaning['definitions'][0]['definition'] ?? 'No definition found.';
            if (mounted) {
              setState(() {
                _partOfSpeech = pos;
                _definition = def;
                _isLoading = false;
              });
            }
            return;
          }
        }
      } else if (response.statusCode == 404) {
        if (mounted) {
          setState(() {
            _definition = "Word not found in dictionary.";
            _isLoading = false;
          });
        }
        return;
      }
    } catch (e) {
      debugPrint("Dictionary API Error: $e");
      if (mounted) {
        setState(() {
          _definition = "Error: Network or CORS issue.";
          _isLoading = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _definition = "Definition not available.";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.cleanWord,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF9B0505),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.volume_up, color: Colors.blue, size: 30),
                onPressed: () => widget.flutterTts.speak(widget.cleanWord),
              ),
            ],
          ),
          if (_partOfSpeech.isNotEmpty)
            Text(
              _partOfSpeech,
              style: const TextStyle(
                fontSize: 16,
                fontStyle: FontStyle.italic,
                color: Colors.grey,
              ),
            ),
          const SizedBox(height: 16),
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Text(
                  _definition,
                  style: const TextStyle(fontSize: 18),
                ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9B0505),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
"""

user_content = user_content.replace(
    "import 'package:speech_to_text/speech_to_text.dart' as stt;",
    "import '../services/speech_services.dart';"
)

user_content = user_content.replace(
    "late stt.SpeechToText _speech;",
    "final SpeechService _speech = SpeechService();"
)

user_content = user_content.replace(
    "_speech = stt.SpeechToText();",
    "// _speech initialization removed"
)

user_content = user_content.replace(
    "_speech.stop();",
    "_speech.stopListening();"
)

user_content = user_content.replace(
    """    bool available = await _speech.initialize(
      onError: (error) {
        if (mounted && _isListening) {
          // If error is timeout, just silently restart
          setState(() => _isListening = false);
          if (_currentWordIndex < _targetWords.length) {
            Future.delayed(const Duration(milliseconds: 100), () {
              if (mounted && !_isListening && _currentWordIndex < _targetWords.length) {
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
                if (mounted && !_isListening && _currentWordIndex < _targetWords.length) {
                  _startOralReading();
                }
              });
            }
          }
        }
      },
    );""",
    "    bool available = await _speech.initSpeech();"
)

user_content = user_content.replace(
    """      _speech.listen(
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.dictation,
          partialResults: true,
          listenFor: const Duration(minutes: 5),
          pauseFor: const Duration(seconds: 4), // 4 seconds of silence triggers 1 attempt
        ),
        onResult: (result) {
          if (!mounted) return;
          setState(() {
            _spokenText = result.recognizedWords;
          });
          _evaluateSpokenStream(_spokenText, isFinal: result.finalResult); 
        },
      );""",
    """      _speech.startListening((resultText) {
        if (!mounted) return;
        setState(() {
          _spokenText += " " + resultText;
        });
        _evaluateSpokenStream(_spokenText, isFinal: false); 
      });"""
)

# And in RemediationDialog, it already has final SpeechService speech; because they pasted my modified struct? Wait, no.
# "final SpeechService speech;" is in the text they pasted? Let's check the text they pasted.
# Wait, looking at the pasted text for RemediationDialog:
# class RemediationDialog extends StatefulWidget {
#   final List<WordStatus> failedWords;
#   final FlutterTts flutterTts;
#   final SpeechService speech;
# YES! The text they pasted ALREADY has `final SpeechService speech;` and `widget.speech.initSpeech()` and `widget.speech.startListening`.
# Wait, they pasted a mix of old code at the top, and my modifications at the bottom!
# No, let's look at `_startOralReading` in the pasted code. It has `stt.SpeechListenOptions`!
# Let me just write the string they gave me and run standard Python replacements.

import io

with open(r'd:\flutter\readsmart\theapp\lib\screens\story_view_screen.dart', 'w', encoding='utf-8') as f:
    f.write(user_content)

print("done")
