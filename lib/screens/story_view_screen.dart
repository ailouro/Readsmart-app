import 'dart:convert';
import 'dart:io' show Platform;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import '../services/bgm_service.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:confetti/confetti.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/story_comic_background.dart';
import 'package:theapp/screens/quiz_screen.dart';
import '../services/deepgram_service.dart';
import '../services/assessment_score.dart';

class WordStatus {
  final String originalWord;
  final String cleanWord;
  bool isCorrect;
  bool isFailed;
  String? audioPath;
  int totalAttempts;
  bool isProperNoun;
  String miscueType;

  WordStatus({
    required this.originalWord,
    required this.cleanWord,
    this.isCorrect = false,
    this.isFailed = false,
    this.audioPath,
    this.totalAttempts = 0,
    this.isProperNoun = false,
    this.miscueType = 'none',
  });
}

// ==============================================================
// 🛠️ NUMBER NORMALIZATION HELPERS TO FIX AI STT ISSUES
// ==============================================================
String _numberToWords(int number) {
  if (number == 0) return "zero";
  if (number < 0) return number.toString();

  const units = [
    "",
    "one",
    "two",
    "three",
    "four",
    "five",
    "six",
    "seven",
    "eight",
    "nine",
    "ten",
    "eleven",
    "twelve",
    "thirteen",
    "fourteen",
    "fifteen",
    "sixteen",
    "seventeen",
    "eighteen",
    "nineteen",
  ];
  const tens = [
    "",
    "",
    "twenty",
    "thirty",
    "forty",
    "fifty",
    "sixty",
    "seventy",
    "eighty",
    "ninety",
  ];

  if (number < 20) return units[number];
  if (number < 100) {
    return tens[number ~/ 10] +
        ((number % 10 != 0) ? " ${units[number % 10]}" : "");
  }
  if (number < 1000) {
    return "${units[number ~/ 100]} hundred${((number % 100 != 0) ? " ${_numberToWords(number % 100)}" : "")}";
  }
  return number.toString();
}

String _normalizeNumbers(String text) {
  return text.replaceAllMapped(RegExp(r'\b\d+\b'), (match) {
    int? val = int.tryParse(match.group(0)!);
    if (val != null && val < 1000) {
      return _numberToWords(val);
    }
    return match.group(0)!;
  });
}

bool isWordMatch(String targetClean, String spokenClean) {
  if (targetClean == spokenClean) return true;

  if (int.tryParse(targetClean) != null) {
    String words = _normalizeNumbers(targetClean).replaceAll(' ', '');
    if (words == spokenClean.replaceAll(' ', '')) return true;
  }

  if (int.tryParse(spokenClean) != null) {
    String words = _normalizeNumbers(spokenClean).replaceAll(' ', '');
    if (words == targetClean.replaceAll(' ', '')) return true;
  }

  if (_isCloseEnoughForChild(targetClean, spokenClean)) return true;

  return false;
}

int _levenshteinDistance(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;

  List<int> previousRow = List.generate(b.length + 1, (i) => i);
  List<int> currentRow = List.filled(b.length + 1, 0);

  for (int i = 1; i <= a.length; i++) {
    currentRow[0] = i;
    for (int j = 1; j <= b.length; j++) {
      final int cost = a[i - 1] == b[j - 1] ? 0 : 1;
      final int deletion = previousRow[j] + 1;
      final int insertion = currentRow[j - 1] + 1;
      final int substitution = previousRow[j - 1] + cost;
      currentRow[j] = [
        deletion,
        insertion,
        substitution,
      ].reduce((x, y) => x < y ? x : y);
    }
    final List<int> temp = previousRow;
    previousRow = currentRow;
    currentRow = temp;
  }
  return previousRow[b.length];
}

bool _isCloseEnoughForChild(String targetClean, String spokenClean) {
  if (targetClean.isEmpty || spokenClean.isEmpty) return false;

  final int lengthDiff = (targetClean.length - spokenClean.length).abs();
  if (lengthDiff > 2) return false;

  final int allowedDistance = targetClean.length <= 3
      ? 0
      : targetClean.length <= 6
      ? 1
      : 2;

  if (allowedDistance == 0) return false;
  return _levenshteinDistance(targetClean, spokenClean) <= allowedDistance;
}

// ==============================================================

class StoryViewerScreen extends StatefulWidget {
  final dynamic story;
  final String baseUrl;
  final int studentId;
  final String testType;

  /// Phil-IRI assessment mode. The screen does not save progress or mark the
  /// story as recorded. It pops with a [PassageScore] after the quiz so
  /// AssessmentFlowScreen can score the passage.
  final bool assessmentMode;

  /// Practice mode flag for My Library / Activity.
  /// When true, reading progress and test results will not be saved to backend.
  final bool isPracticeOnly;

  const StoryViewerScreen({
    super.key,
    required this.story,
    required this.baseUrl,
    this.studentId = 1,
    this.testType = "post_test",
    this.assessmentMode = false,
    this.isPracticeOnly = false,
  });

  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final Map<String, Uint8List> _audioCache = {};

  final AudioPlayer _audioPlayer = AudioPlayer();
  final FlutterTts _flutterTts = FlutterTts();
  final DeepgramService _deepgramService = DeepgramService();

  bool _isPlayingServerAudio = false;
  bool _isPlayingTts = false;
  int? _playingIndex;
  bool _isGenerating = false;
  DateTime? _readingStartTime;

  Duration _activeReadingDuration = Duration.zero;
  DateTime? _activeSegmentStart;

  bool _isListening = false;
  String _spokenText = "";
  String _finalSpokenText = "";
  List<WordStatus> _targetWords = [];

  final Set<int> _pagesWithOralReadingStarted = {};

  final ScrollController _scriptScrollController = ScrollController();
  List<GlobalKey> _wordKeys = [];

  int _currentWordIndex = 0;
  int _currentWordAttempts = 0;
  int _processedSpokenWordCount = 0;
  final int _maxWordAttempts = 3;
  bool _isAssessmentPassed = false;

  final Map<int, List<WordStatus>> _pageTargetWords = {};
  final Map<int, int> _pageCurrentWordIndex = {};
  final Map<int, bool> _pageAssessmentPassed = {};

  final List<WordStatus> _allFailedWords = [];

  bool _isStoryAlreadyRecorded = false;

  @override
  void initState() {
    super.initState();
    BgmService().stopBgm();
    _readingStartTime = DateTime.now();
    _configureAudioSession();
    _checkIfStoryRecorded();
    _initTtsEngine();
    _initAudioPlayerListeners();
    _loadSavedPage();
  }

  /// 🔊 MOBILE AUDIO FIX
  Future<void> _configureAudioSession() async {
    try {
      await AudioPlayer.global.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            isSpeakerphoneOn: true,
            stayAwake: true,
            contentType: AndroidContentType.music,
            usageType: AndroidUsageType.media,
            audioFocus: AndroidAudioFocus.gainTransientMayDuck,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: const {
              AVAudioSessionOptions.mixWithOthers,
              AVAudioSessionOptions.defaultToSpeaker,
            },
          ),
        ),
      );
    } catch (e) {
      debugPrint("Failed to configure audio session: $e");
    }
  }

  Future<void> _checkIfStoryRecorded() async {
    if (widget.assessmentMode || widget.isPracticeOnly) return;
    final prefs = await SharedPreferences.getInstance();
    bool recorded =
        prefs.getBool(
          'story_${widget.story['id'] ?? widget.story['_id']}_${widget.testType}_reading_completed',
        ) ??
        false;
    if (mounted && recorded) {
      setState(() => _isStoryAlreadyRecorded = true);
    }
  }

  Future<void> _loadSavedPage() async {
    final prefs = await SharedPreferences.getInstance();

    final bool alreadyCompleted =
        prefs.getBool(
          'story_${widget.story['id'] ?? widget.story['_id']}_reading_completed',
        ) ??
        false;
    if (alreadyCompleted && !widget.isPracticeOnly) {
      await _clearSavedStoryProgress();
    }

    final String? savedStates = prefs.getString(
      'story_${widget.story['id']}_word_states',
    );
    if (savedStates != null && !widget.isPracticeOnly) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(savedStates);
        final List<dynamic> pages = widget.story['pages'] ?? [];
        decoded.forEach((pageKeyStr, wordStatesRaw) {
          final int? pageIdx = int.tryParse(pageKeyStr);
          if (pageIdx == null ||
              pageIdx < 0 ||
              pageIdx >= pages.length ||
              wordStatesRaw is! List) {
            return;
          }

          final pageData = pages[pageIdx];
          var rawScripts = pageData['audio_scripts'];
          String scriptText = '';
          if (rawScripts is List) {
            scriptText = rawScripts.join(' ');
          } else if (rawScripts is String) {
            scriptText = rawScripts;
          }
          if (scriptText.trim().isEmpty) return;

          final List<String> rawWords = scriptText
              .split(RegExp(r'\s+'))
              .where((w) => w.isNotEmpty)
              .toList();
          if (rawWords.length != (wordStatesRaw as List).length) return;

          final List<WordStatus> restored = [];
          for (int i = 0; i < rawWords.length; i++) {
            final String cleaned = rawWords[i].toLowerCase().replaceAll(
              RegExp(r'[^\w\s]'),
              '',
            );
            final Map<String, dynamic> state = Map<String, dynamic>.from(
              wordStatesRaw[i],
            );
            restored.add(
              WordStatus(
                originalWord: rawWords[i],
                cleanWord: cleaned,
                isCorrect: state['isCorrect'] == true,
                isFailed: state['isFailed'] == true,
                miscueType: state['miscueType'] ?? 'none',
              ),
            );
          }

          int wordIdx = restored.length;
          for (int i = 0; i < restored.length; i++) {
            if (!restored[i].isCorrect && !restored[i].isFailed) {
              wordIdx = i;
              break;
            }
          }

          _pageTargetWords[pageIdx] = restored;
          _pageCurrentWordIndex[pageIdx] = wordIdx;
          _pageAssessmentPassed[pageIdx] = wordIdx >= restored.length;
          if (restored.any((w) => w.isCorrect || w.isFailed)) {
            _pagesWithOralReadingStarted.add(pageIdx);
          }
        });
      } catch (_) {}
    }

    if (!widget.isPracticeOnly) {
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
  }

  Future<void> _savePageWordStates(int pageIdx, List<WordStatus> words) async {
    if (widget.isPracticeOnly) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final String key = 'story_${widget.story['id']}_word_states';
      final String? existing = prefs.getString(key);
      Map<String, dynamic> allStates = {};
      if (existing != null) {
        try {
          allStates = Map<String, dynamic>.from(jsonDecode(existing));
        } catch (_) {}
      }
      allStates['$pageIdx'] = words
          .map(
            (w) => {
              'isCorrect': w.isCorrect,
              'isFailed': w.isFailed,
              'miscueType': w.miscueType,
            },
          )
          .toList();
      await prefs.setString(key, jsonEncode(allStates));
    } catch (_) {}
  }

  String _firstReadingScript(dynamic rawScripts) {
    if (rawScripts is List && rawScripts.isNotEmpty) {
      return rawScripts.first.toString();
    } else if (rawScripts is String) {
      return rawScripts;
    }
    return "";
  }

  void _setupTargetWords(String fullScriptText) {
    if (fullScriptText.trim().isEmpty) {
      _targetWords = [];
      _wordKeys = [];
      return;
    }
    List<String> rawWords = fullScriptText.split(RegExp(r'\s+'));
    bool prevEndedSentence = true;
    _targetWords = rawWords.map((word) {
      String cleaned = word.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '');
      final bool startsUpper = RegExp(r'^[A-Z]').hasMatch(word);
      final bool likelyProperNoun = startsUpper && !prevEndedSentence;
      prevEndedSentence = RegExp(r'[.!?]$').hasMatch(word.trim());
      return WordStatus(
        originalWord: word,
        cleanWord: cleaned,
        isProperNoun: likelyProperNoun,
      );
    }).toList();
    _wordKeys = List.generate(_targetWords.length, (_) => GlobalKey());
    _currentWordIndex = 0;
    _currentWordAttempts = 0;
    _processedSpokenWordCount = 0;
    _isAssessmentPassed = false;
    _spokenText = "";
  }

  void _scrollToActiveWord() {
    if (_currentWordIndex < 0 || _currentWordIndex >= _wordKeys.length) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _wordKeys[_currentWordIndex].currentContext;
      if (ctx == null || !_scriptScrollController.hasClients) return;
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
        alignment: 0.5,
      );
    });
  }

  void _initTtsEngine() async {
    if (Platform.isIOS) {
      try {
        await _flutterTts.setSharedInstance(true);
        await _flutterTts.setIosAudioCategory(
          IosTextToSpeechAudioCategory.playback,
          [
            IosTextToSpeechAudioCategoryOptions.mixWithOthers,
            IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
          ],
          IosTextToSpeechAudioMode.defaultMode,
        );
      } catch (e) {
        debugPrint("Failed to configure iOS TTS audio session: $e");
      }
    }
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
    // Tapping a word plays it out loud via TTS. If oral-reading assessment is
    // still actively listening, that TTS audio can bleed into the live mic
    // stream (no hardware echo-cancel on a lot of budget Android tablets) and
    // Deepgram ends up "hearing" the app's own voice, corrupting the word
    // matching / highlighting. So block taps while the mic is live, same as
    // the other audio actions already do.
    if (_isListening) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please stop oral reading first to check a word."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    String cleanWord = originalWord.toLowerCase().replaceAll(
      RegExp(r'[^\w\s]'),
      '',
    );
    if (cleanWord.isEmpty) return;

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

  void _startActiveReadingSegment() {
    if (_activeSegmentStart == null) {
      _activeSegmentStart = DateTime.now();
    }
  }

  void _endActiveReadingSegment() {
    if (_activeSegmentStart != null) {
      _activeReadingDuration += DateTime.now().difference(_activeSegmentStart!);
      _activeSegmentStart = null;
    }
  }

  Future<void> _stopAllAudio() async {
    await _flutterTts.stop();
    await _audioPlayer.stop();
    if (_isListening) {
      _endActiveReadingSegment();
      await _deepgramService.stopListening();
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
    if (_isListening) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please stop oral reading first to listen."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (_isPlayingTts && _playingIndex == sIndex) {
      await _stopAllAudio();
      return;
    }
    await _stopAllAudio();
    setState(() => _playingIndex = sIndex);
    await _flutterTts.speak(text);
  }

  Future<void> _playServerAudio(int sIndex, String cleanBaseUrl) async {
    if (_isListening) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please stop oral reading first to listen."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (_isPlayingServerAudio && _playingIndex == sIndex) {
      await _stopAllAudio();
      return;
    }
    await _stopAllAudio();
    setState(() => _playingIndex = sIndex);
    String audioUrl =
        "$cleanBaseUrl/api/get-audio?story_id=${widget.story['id']}&page_index=$_currentPage&script_index=$sIndex";
    try {
      if (_audioCache.containsKey(audioUrl)) {
        await _audioPlayer.play(BytesSource(_audioCache[audioUrl]!));
        return;
      }

      final response = await http.get(
        Uri.parse(audioUrl),
        headers: const {"ngrok-skip-browser-warning": "69420"},
      );
      if (response.statusCode == 200) {
        _audioCache[audioUrl] = response.bodyBytes;
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

  void _startOralReading() async {
    if (_isPlayingTts || _isPlayingServerAudio) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Please wait for the speaker to finish before reading.",
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_isListening) {
      await _stopAllAudio();
      return;
    }

    await _stopAllAudio();

    if (_isListening) {
      _endActiveReadingSegment();
      setState(() => _isListening = false);
      await _deepgramService.stopListening();
      return;
    }

    if (_currentWordIndex >= _targetWords.length) {
      _finishSlideAssessment();
      return;
    }

    if (_isPlayingTts || _isPlayingServerAudio) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Please wait for the speaker to finish before reading.",
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    List<String> keywords = _targetWords.map((w) => w.cleanWord).toList();

    setState(() {
      _isListening = true;
      _spokenText = "";
      _finalSpokenText = "";
      _processedSpokenWordCount = 0;
      _pagesWithOralReadingStarted.add(_currentPage);
    });
    _startActiveReadingSegment();

    await _deepgramService.startListening(
      targetKeywords: keywords,
      onResult: (transcript, isFinal) {
        if (!mounted) return;
        setState(() {
          if (isFinal) {
            _finalSpokenText += " $transcript";
            _spokenText = _finalSpokenText;
          } else {
            _spokenText = _finalSpokenText + " " + transcript;
          }
        });

        _evaluateSpokenStream(_spokenText, isFinal: isFinal);
      },
    );
  }

  Future<void> _evaluateSpokenStream(
    String spoken, {
    bool isFinal = false,
  }) async {
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

    while (_currentWordIndex < _targetWords.length) {
      WordStatus currentTarget = _targetWords[_currentWordIndex];
      bool found = false;

      for (int i = _processedSpokenWordCount; i < spokenWordsList.length; i++) {
        if (isWordMatch(currentTarget.cleanWord, spokenWordsList[i])) {
          found = true;
          _processedSpokenWordCount = i + 1;
          break;
        }
      }

      if (found) {
        _deepgramService.clearAudioBuffer();

        if (_currentWordAttempts > 0) {
          _notifyTeacherOfSelfCorrection(
            currentTarget,
            _currentWordAttempts + 1,
          );
        }

        setState(() {
          currentTarget.isCorrect = true;
          currentTarget.isFailed = false;
          _currentWordAttempts = 0;
          _currentWordIndex++;
        });
        _scrollToActiveWord();
        advanced = true;
        _savePageWordStates(_currentPage, _targetWords);
      } else {
        break;
      }
    }

    if (isFinal && !advanced && _currentWordIndex < _targetWords.length) {
      WordStatus currentTarget = _targetWords[_currentWordIndex];

      HapticFeedback.vibrate();
      bool justFailed = false;
      setState(() {
        _currentWordAttempts++;
        if (_currentWordAttempts >= _maxWordAttempts) {
          currentTarget.isFailed = true;
          currentTarget.isCorrect = false;
          currentTarget.miscueType = 'mispronunciation';
          currentTarget.totalAttempts = _currentWordAttempts;
          _currentWordAttempts = 0;
          _currentWordIndex++;
          _savePageWordStates(_currentPage, _targetWords);
          justFailed = true;
        }
      });
      if (justFailed) _scrollToActiveWord();

      if (justFailed) {
        String? savedPath = await _deepgramService.saveFailedWordAudio(
          currentTarget.cleanWord,
        );
        currentTarget.audioPath = savedPath;
        _deepgramService.clearAudioBuffer();
      }

      _processedSpokenWordCount = spokenWordsList.length;
    }

    if (_currentWordIndex >= _targetWords.length) {
      _stopAllAudio();
      _finishSlideAssessment();
    }
  }

  void _finishSlideAssessment() async {
    await _stopAllAudio();
    List<WordStatus> failedWords = _targetWords
        .where((w) => w.isFailed && !w.isCorrect)
        .toList();

    for (var w in failedWords) {
      if (!_allFailedWords.any((e) => e.originalWord == w.originalWord)) {
        _allFailedWords.add(w);
      }
    }

    if (failedWords.isEmpty) {
      setState(() => _isAssessmentPassed = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("🎉 Excellent! Moving to the next slide..."),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          _advanceToNextSlide();
        }
      });
    } else {
      _triggerRemediationPopup(failedWords);
    }
  }

  void _flushUnreadWordsAsFailed() {
    if (_targetWords.isEmpty) return;
    setState(() {
      for (int i = _currentWordIndex; i < _targetWords.length; i++) {
        final w = _targetWords[i];
        if (!w.isCorrect && !w.isFailed) {
          w.isFailed = true;
          w.miscueType = 'omission';
          w.totalAttempts = 0;
        }
      }
    });
    for (final w in _targetWords) {
      if (w.isFailed && !w.isCorrect) {
        if (!_allFailedWords.any((e) => e.originalWord == w.originalWord)) {
          _allFailedWords.add(w);
        }
      }
    }
    _savePageWordStates(_currentPage, _targetWords);
  }

  Future<void> _clearSavedStoryProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String storyId = (widget.story['id'] ?? widget.story['_id'])
          .toString();
      await prefs.remove('story_${storyId}_word_states');
      await prefs.remove('story_${storyId}_page');
    } catch (_) {}
  }

  void _advanceToNextSlide() async {
    await _stopAllAudio();

    if (_pagesWithOralReadingStarted.contains(_currentPage)) {
      _flushUnreadWordsAsFailed();
    }

    List<dynamic> pages = widget.story['pages'] ?? [];
    if (_currentPage < pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    } else {
      if (_isStoryAlreadyRecorded && !widget.isPracticeOnly) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => QuizScreen(
              testType: widget.testType,
              storyId: widget.story['id'] ?? widget.story['_id'],
              studentId: widget.studentId,
              baseUrl: widget.baseUrl,
              oralAccuracy: 0,
              totalWords: 0,
              readingTimeSeconds: 0,
            ),
          ),
        );
        return;
      }

      _pageTargetWords[_currentPage] = List.from(_targetWords);

      int totalWordsCount = 0;
      int failedWordsCount = 0;

      List<dynamic> allPages = widget.story['pages'] ?? [];
      for (int i = 0; i < allPages.length; i++) {
        if (_pageTargetWords.containsKey(i)) {
          var list = _pageTargetWords[i]!.where((w) => !w.isProperNoun);
          totalWordsCount += list.length;
          failedWordsCount += list
              .where(
                (w) =>
                    (w.isFailed && !w.isCorrect) ||
                    (widget.assessmentMode && !w.isCorrect && !w.isFailed),
              )
              .length;
        } else {
          var rawScripts = allPages[i]['audio_scripts'];
          String pageText = rawScripts is List
              ? rawScripts.join(" ")
              : (rawScripts is String ? rawScripts : "");
          if (pageText.trim().isNotEmpty) {
            final int unseenWords = pageText
                .split(RegExp(r'\s+'))
                .where((w) => w.isNotEmpty)
                .length;
            totalWordsCount += unseenWords;
            if (widget.assessmentMode) failedWordsCount += unseenWords;
          }
        }
      }

      int correctWordsCount = totalWordsCount - failedWordsCount;
      if (correctWordsCount < 0) correctWordsCount = 0;

      int activeSeconds = _activeReadingDuration.inSeconds;
      if (activeSeconds <= 0 && _readingStartTime != null) {
        activeSeconds = DateTime.now().difference(_readingStartTime!).inSeconds;
      }
      if (activeSeconds <= 0) activeSeconds = 1;

      double timeInMinutes = activeSeconds / 60.0;
      int computedWpm = (timeInMinutes > 0 && correctWordsCount > 0)
          ? (correctWordsCount / timeInMinutes).round()
          : 0;

      double wrPct = totalWordsCount > 0
          ? (correctWordsCount / totalWordsCount) * 100.0
          : 0.0;
      wrPct = double.parse(wrPct.toStringAsFixed(2));

      String wrLevel;
      if (wrPct >= 97) {
        wrLevel = 'Independent';
      } else if (wrPct >= 90) {
        wrLevel = 'Instructional';
      } else if (totalWordsCount < 15 && failedWordsCount <= 1) {
        wrLevel = 'Instructional';
      } else {
        wrLevel = 'Frustration';
      }

      // KUNG HINDI PRACTICE MODE AT HINDI ASSESSMENT MODE, MAG-SAVE SA BACKEND
      if (!widget.assessmentMode && !widget.isPracticeOnly) {
        try {
          await http.post(
            Uri.parse("${widget.baseUrl}/api/student/progress"),
            headers: {
              "Content-Type": "application/json",
              "ngrok-skip-browser-warning": "69420",
            },
            body: jsonEncode({
              "student_id": widget.studentId,
              "user_id": widget.studentId,
              "story_id": widget.story['id'] ?? widget.story['_id'],
              "quiz_score": 0,
              "total_questions": 0,
              "oral_fluency_accuracy": wrPct,
              "total_words": totalWordsCount,
              "correct_words": correctWordsCount,
              "time_on_task": activeSeconds,
              "wpm": computedWpm,
              "struggled_words": _allFailedWords
                  .map((w) => w.cleanWord)
                  .join(", "),
              "test_type": widget.testType,
            }),
          );
        } catch (e) {
          debugPrint("Progress save error: $e");
        }
      }

      if (_allFailedWords.isNotEmpty && !widget.isPracticeOnly) {
        await _notifyTeacherOfFailedWords(_allFailedWords);
      }

      if (!widget.assessmentMode && !widget.isPracticeOnly) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(
          'story_${widget.story['id'] ?? widget.story['_id']}_reading_completed',
          true,
        );
      }
      await _clearSavedStoryProgress();

      if (!mounted) return;

      // 🌟 KUNG PRACTICE MODE (MY LIBRARY):
      if (widget.isPracticeOnly) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text("Magaling! 🌟", textAlign: TextAlign.center),
            content: const Text(
              "Natapos mo ang pagsasanay sa pagbasa!",
              textAlign: TextAlign.center,
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext); // Isara ang dialog
                  Navigator.pop(context); // Bumalik sa My Library
                },
                child: const Text("OK"),
              ),
            ],
          ),
        );
        return;
      }

      if (widget.assessmentMode) {
        final score = await Navigator.push<PassageScore>(
          context,
          MaterialPageRoute(
            builder: (context) => QuizScreen(
              testType: widget.testType,
              storyId: widget.story['id'] ?? widget.story['_id'],
              studentId: widget.studentId,
              baseUrl: widget.baseUrl,
              oralAccuracy: wrPct,
              totalWords: totalWordsCount,
              readingTimeSeconds: activeSeconds,
              struggledWords: _allFailedWords.map((w) => w.cleanWord).toList(),
              assessmentMode: true,
            ),
          ),
        );
        if (!mounted) return;
        Navigator.pop(context, score);
        return;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => QuizScreen(
            testType: widget.testType,
            storyId: widget.story['id'] ?? widget.story['_id'],
            studentId: widget.studentId,
            baseUrl: widget.baseUrl,
            oralAccuracy: wrPct,
            totalWords: totalWordsCount,
            readingTimeSeconds: activeSeconds,
          ),
        ),
      );
    }
  }

  void _triggerRemediationPopup(List<WordStatus> failedWords) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return RemediationDialog(
          failedWords: failedWords,
          flutterTts: _flutterTts,
          deepgramService: _deepgramService,
          onCompleted: (remainingUncorrectedWords) async {
            Navigator.of(context).pop();
            if (remainingUncorrectedWords.isNotEmpty) {
              for (final w in remainingUncorrectedWords) {
                if (!_allFailedWords.any(
                  (e) => e.originalWord == w.originalWord,
                )) {
                  _allFailedWords.add(w);
                }
              }
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Words noted. Moving to the next slide!"),
                  backgroundColor: Colors.deepOrange,
                  duration: Duration(seconds: 3),
                ),
              );
            }
            setState(() => _isAssessmentPassed = true);
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

  Future<void> _notifyTeacherOfFailedWords(List<WordStatus> failedWords) async {
    if (failedWords.isEmpty || widget.isPracticeOnly) return;
    try {
      final url = Uri.parse("${widget.baseUrl}/api/student-mispronunciations");
      var request = http.MultipartRequest('POST', url);

      request.headers.addAll({"ngrok-skip-browser-warning": "69420"});

      request.fields['student_id'] = widget.studentId.toString();
      request.fields['user_id'] = widget.studentId.toString();
      request.fields['story_id'] = (widget.story['id'] ?? widget.story['_id'])
          .toString();

      List<Map<String, dynamic>> wordsData = failedWords
          .map(
            (w) => {
              'word': w.cleanWord,
              'total_attempts': w.totalAttempts > 0
                  ? w.totalAttempts
                  : _maxWordAttempts,
              'miscue_type': w.miscueType,
              'slide_index': _currentPage,
            },
          )
          .toList();
      request.fields['words_json'] = jsonEncode(wordsData);

      for (int i = 0; i < failedWords.length; i++) {
        request.fields['words[$i]'] = failedWords[i].cleanWord;
        request.fields['attempts[$i]'] =
            (failedWords[i].totalAttempts > 0
                    ? failedWords[i].totalAttempts
                    : _maxWordAttempts)
                .toString();
        request.fields['miscue_types[$i]'] = failedWords[i].miscueType;

        if (failedWords[i].audioPath != null) {
          request.files.add(
            await http.MultipartFile.fromPath(
              'audio_files[]',
              failedWords[i].audioPath!,
              filename: 'struggle_${failedWords[i].cleanWord}.wav',
            ),
          );
        }
      }

      var response = await request.send();
      var responseBody = await response.stream.bytesToString();
      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint("Successfully sent notification and audio to teacher.");
      } else {
        debugPrint("LARAVEL ERROR: ${response.statusCode} - $responseBody");
      }
    } catch (e) {
      debugPrint("Failed sending notification to teacher: $e");
    }
  }

  Future<void> _notifyTeacherOfSelfCorrection(
    WordStatus word,
    int totalAttempts,
  ) async {
    if (widget.isPracticeOnly) return;
    try {
      final url = Uri.parse("${widget.baseUrl}/api/student-self-corrections");
      await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "ngrok-skip-browser-warning": "69420",
        },
        body: jsonEncode({
          "student_id": widget.studentId,
          "user_id": widget.studentId,
          "story_id": widget.story['id'] ?? widget.story['_id'],
          "slide_index": _currentPage,
          "word": word.cleanWord,
          "total_attempts": totalAttempts,
        }),
      );
      debugPrint(
        "Successfully logged self-correction for '${word.cleanWord}'.",
      );
    } catch (e) {
      debugPrint("Failed sending self-correction log: $e");
    }
  }

  @override
  void dispose() {
    _endActiveReadingSegment();
    _pageController.dispose();
    _scriptScrollController.dispose();
    _flutterTts.stop();
    _audioPlayer.dispose();
    _deepgramService.stopListening();
    super.dispose();
  }

  Widget _buildScriptBox() {
    if (_targetWords.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.amberAccent,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black, width: 3),
        boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(4, 4))],
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8.0,
        runSpacing: 6.0,
        children: _targetWords.asMap().entries.map((entry) {
          int wIndex = entry.key;
          WordStatus wStatus = entry.value;

          bool isActive = wIndex == _currentWordIndex && _isListening;
          bool isFailed = wStatus.isFailed;

          Color textColor = Colors.black;
          TextDecoration decoration = TextDecoration.underline;
          Color decorationColor = Colors.black54;
          TextDecorationStyle decorationStyle = TextDecorationStyle.dotted;
          Color bgColor = Colors.transparent;
          BoxBorder? border;

          if (wStatus.isCorrect) {
            textColor = Colors.green[800]!;
            decorationColor = Colors.green;
            decorationStyle = TextDecorationStyle.solid;
          } else if (isActive) {
            bgColor = Colors.amber;
            decorationColor = Colors.amber.shade700;
            decorationStyle = TextDecorationStyle.solid;
          }

          if (isFailed) {
            textColor = Colors.red[900]!;
            bgColor = Colors.red[50]!;
            border = Border.all(color: Colors.red[700]!, width: 3);
            decoration = TextDecoration.none;
          }

          Widget textWidget = Text(
            wStatus.originalWord,
            style: GoogleFonts.fredoka(
              color: textColor,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              decoration: decoration,
              decorationStyle: decorationStyle,
              decorationColor: decorationColor,
              backgroundColor: bgColor,
            ),
          );

          if (border != null) {
            textWidget = Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                border: border,
                borderRadius: BorderRadius.circular(12),
                color: bgColor,
              ),
              child: textWidget,
            );
          }

          if (wStatus.isCorrect) {
            textWidget = textWidget
                .animate(key: ValueKey('${wIndex}_correct'))
                .scale(
                  begin: const Offset(1.4, 1.4),
                  end: const Offset(1, 1),
                  duration: 300.ms,
                  curve: Curves.easeOutBack,
                );
          } else if (isActive) {
            textWidget = textWidget
                .animate(
                  onPlay: (controller) => controller.repeat(reverse: true),
                )
                .scale(
                  begin: const Offset(1, 1),
                  end: const Offset(1.1, 1.1),
                  duration: 500.ms,
                );
          } else if (isFailed) {
            textWidget = textWidget
                .animate(key: ValueKey('${wIndex}_failed'))
                .shakeX(amount: 3, duration: 300.ms);
          }

          return GestureDetector(
            key: wIndex < _wordKeys.length ? _wordKeys[wIndex] : null,
            onTap: () => _showWordDefinition(wStatus.originalWord),
            child: textWidget,
          );
        }).toList(),
      ),
    );
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
    String fullTargetText = currentScripts.isNotEmpty ? currentScripts[0] : "";
    if (_targetWords.isEmpty && fullTargetText.isNotEmpty) {
      _setupTargetWords(fullTargetText);
    }

    Widget controlsWidget = SingleChildScrollView(
      child: Container(
        width: double.infinity,
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
                  icon: const Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                    size: 20,
                  ),
                  label: const Text(
                    "Prev",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
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
                  onPressed: _advanceToNextSlide,
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
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward, color: Colors.white, size: 20),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (!_isStoryAlreadyRecorded || widget.isPracticeOnly) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black, width: 2),
                ),
                child: Text(
                  _isListening
                      ? "Read the words out loud. A word turns green when you say it correctly."
                      : "Tap the 🔊 button to hear the page, then tap Start Oral Reading "
                            "and read the words out loud. Each word gets $_maxWordAttempts tries.",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            Builder(
              builder: (context) {
                final int narrationIndex = currentScripts.length > 1 ? 1 : 0;
                final bool isThisServerPlaying =
                    _isPlayingServerAudio && _playingIndex == narrationIndex;

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Container(
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
                            onTap:
                                (_isStoryAlreadyRecorded &&
                                    !widget.isPracticeOnly)
                                ? null
                                : (_currentWordIndex < _targetWords.length
                                      ? _startOralReading
                                      : null),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color:
                                    (_isStoryAlreadyRecorded &&
                                        !widget.isPracticeOnly)
                                    ? Colors.grey[400]
                                    : (_isListening
                                          ? Colors.redAccent
                                          : (_currentWordIndex >=
                                                    _targetWords.length
                                                ? Colors.grey
                                                : Colors.tealAccent[400])),
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
                                    (_isStoryAlreadyRecorded &&
                                            !widget.isPracticeOnly)
                                        ? Icons.check_circle
                                        : (_isListening
                                              ? Icons.stop
                                              : Icons.mic),
                                    color: Colors.black,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      (_isStoryAlreadyRecorded &&
                                              !widget.isPracticeOnly)
                                          ? "Already Recorded"
                                          : (_isListening
                                                ? "Stop Oral Reading"
                                                : (_currentWordIndex <
                                                          _targetWords.length
                                                      ? "Start Oral Reading 🎤"
                                                      : "Completed!")),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Colors.black,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Colors.black, offset: Offset(2, 2)),
                        ],
                      ),
                      child: IconButton(
                        style: IconButton.styleFrom(
                          backgroundColor: isThisServerPlaying
                              ? Colors.amber[800]
                              : Colors.blueAccent,
                          foregroundColor: Colors.white,
                          shape: const CircleBorder(
                            side: BorderSide(color: Colors.black, width: 2.5),
                          ),
                        ),
                        icon: Icon(
                          isThisServerPlaying ? Icons.stop : Icons.volume_up,
                          size: 20,
                        ),
                        onPressed: _isGenerating
                            ? null
                            : () => _playServerAudio(
                                narrationIndex,
                                cleanBaseUrl,
                              ),
                      ),
                    ),
                  ],
                );
              },
            ),
            if (_targetWords.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                "Attempt: $_currentWordAttempts / $_maxWordAttempts",
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  shadows: [Shadow(color: Colors.white, offset: Offset(1, 1))],
                ),
              ),
            ],
          ],
        ),
      ),
    );

    Widget skipButtonWidget = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.amber,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Colors.black, width: 2.5),
            ),
            elevation: 4,
          ),
          onPressed: _advanceToNextSlide,
          child: Text(
            _currentPage < pages.length - 1
                ? "Skip to Next Slide"
                : (widget.isPracticeOnly
                      ? "Finish Practice"
                      : "Finish Reading & Take Quiz"),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
        ),
      ),
    );

    Widget pageViewWidget = PageView.builder(
      controller: _pageController,
      physics: const NeverScrollableScrollPhysics(),
      onPageChanged: (index) async {
        await _stopAllAudio();

        final int leavingPage = _currentPage;
        final List<WordStatus> leavingWords = List.from(_targetWords);
        _pageTargetWords[_currentPage] = leavingWords;
        _pageCurrentWordIndex[_currentPage] = _currentWordIndex;
        _pageAssessmentPassed[_currentPage] = _isAssessmentPassed;

        if (!mounted) return;
        setState(() {
          _currentPage = index;
          if (_pageTargetWords.containsKey(index)) {
            _targetWords = List.from(_pageTargetWords[index]!);
            _wordKeys = List.generate(_targetWords.length, (_) => GlobalKey());
            _currentWordIndex = _pageCurrentWordIndex[index]!;
            _isAssessmentPassed = _pageAssessmentPassed[index]!;
          } else {
            _targetWords = [];
            _wordKeys = [];
            _currentWordIndex = 0;
            _isAssessmentPassed = false;
          }
          _currentWordAttempts = 0;
          _spokenText = "";
          _isListening = false;
        });

        if (_scriptScrollController.hasClients) {
          _scriptScrollController.jumpTo(0);
        }

        if (!_pageTargetWords.containsKey(index)) {
          _setupTargetWords(_firstReadingScript(pages[index]['audio_scripts']));
        }
        if (!widget.isPracticeOnly) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt('story_${widget.story['id']}_page', index);
          await _savePageWordStates(leavingPage, leavingWords);
        }

        String nextPath = "";
        if (index + 1 < pages.length) {
          nextPath =
              pages[index + 1]['image_path'] ?? pages[index + 1]['image'] ?? "";
        }
        if (nextPath.isNotEmpty && mounted) {
          String nextUrl = "";
          if (nextPath.startsWith('http')) {
            nextUrl = nextPath;
          } else {
            if (nextPath.startsWith('public/')) {
              nextPath = nextPath.replaceFirst('public/', '');
            }
            nextUrl = "$cleanBaseUrl/api/get-image?path=$nextPath";
          }
          precacheImage(
            NetworkImage(
              nextUrl,
              headers: const {"ngrok-skip-browser-warning": "69420"},
            ),
            context,
          );
        }
      },
      itemCount: pages.length,
      itemBuilder: (context, index) {
        var page = pages[index];
        String pageImagePath = page['image_path'] ?? page['image'] ?? "";
        String imageUrl = "";

        if (pageImagePath.startsWith('http')) {
          imageUrl = pageImagePath;
        } else {
          if (pageImagePath.startsWith('public/')) {
            pageImagePath = pageImagePath.replaceFirst('public/', '');
          }
          imageUrl = "$cleanBaseUrl/api/get-image?path=$pageImagePath";
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 4.0),
                child: Text(
                  "Slide ${index + 1} of ${pages.length}",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    shadows: [
                      Shadow(color: Colors.black, offset: Offset(2, 2)),
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
                      border: Border.all(color: Colors.black, width: 4),
                      boxShadow: const [
                        BoxShadow(color: Colors.black, offset: Offset(6, 6)),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.contain,
                        width: double.infinity,
                        height: double.infinity,
                        headers: const {"ngrok-skip-browser-warning": "69420"},
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return const Center(
                            child: CircularProgressIndicator(
                              color: Colors.amber,
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) =>
                            const Center(
                              child: Icon(
                                Icons.broken_image,
                                color: Colors.grey,
                                size: 50,
                              ),
                            ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );

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
              : LayoutBuilder(
                  builder: (context, constraints) {
                    bool isDesktop = constraints.maxWidth > 750;

                    if (isDesktop) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(flex: 5, child: pageViewWidget),
                          Expanded(
                            flex: 5,
                            child: Padding(
                              padding: const EdgeInsets.only(
                                right: 16.0,
                                top: 10.0,
                                bottom: 20.0,
                              ),
                              child: Column(
                                children: [
                                  if (currentScripts.isNotEmpty)
                                    Flexible(
                                      flex: 2,
                                      child: Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 10.0,
                                        ),
                                        child: SingleChildScrollView(
                                          controller: _scriptScrollController,
                                          child: _buildScriptBox(),
                                        ),
                                      ),
                                    ),
                                  Expanded(flex: 4, child: controlsWidget),
                                  skipButtonWidget,
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    } else {
                      return Column(
                        children: [
                          Expanded(flex: 7, child: pageViewWidget),
                          if (currentScripts.isNotEmpty)
                            Flexible(
                              flex: 2,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14.0,
                                  vertical: 6.0,
                                ),
                                child: SingleChildScrollView(
                                  controller: _scriptScrollController,
                                  child: _buildScriptBox(),
                                ),
                              ),
                            ),
                          Expanded(flex: 3, child: controlsWidget),
                          skipButtonWidget,
                        ],
                      );
                    }
                  },
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
  final DeepgramService deepgramService;
  final Function(List<WordStatus> remainingUncorrected) onCompleted;

  const RemediationDialog({
    super.key,
    required this.failedWords,
    required this.flutterTts,
    required this.deepgramService,
    required this.onCompleted,
  });

  @override
  State<RemediationDialog> createState() => _RemediationDialogState();
}

class _RemediationDialogState extends State<RemediationDialog> {
  int _currentIndex = 0;
  bool _isPlayingAudio = false;
  bool _isListeningRemediation = false;
  String _remediationSpokenText = "";
  String _finalRemediationText = "";
  String _statusMessage = "Listen closely to the correct pronunciation!";
  // Guards against duplicate advances: Deepgram keeps delivering buffered
  // interim/final messages for a brief moment after stopListening() is
  // called (it's async), so without this a single word could match twice
  // and silently skip the next practice word.
  bool _resultLocked = false;

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
      _isPlayingAudio = true;
      _statusMessage = "Listen twice: \"${currentWord.originalWord}\"";
    });

    for (int i = 0; i < 2; i++) {
      if (!mounted) return;
      await widget.flutterTts.speak(currentWord.originalWord);
    }

    if (!mounted) return;
    setState(() {
      _statusMessage = "Get ready...";
    });

    await widget.flutterTts.speak("It's your turn!");

    if (!mounted) return;
    setState(() {
      _isPlayingAudio = false;
      _statusMessage = "Speak now 🎙️";
    });

    _listenStudentRetry(currentWord);
  }

  void _listenStudentRetry(WordStatus word) async {
    _resultLocked = false;
    setState(() {
      _isListeningRemediation = true;
      _remediationSpokenText = "";
      _finalRemediationText = "";
    });

    await widget.deepgramService.startListening(
      targetKeywords: [word.cleanWord],
      onResult: (transcript, isFinal) {
        if (!mounted || _resultLocked) return;

        setState(() {
          if (isFinal) {
            _finalRemediationText += " $transcript";
            _remediationSpokenText = _finalRemediationText;
          } else {
            _remediationSpokenText = _finalRemediationText + " " + transcript;
          }
        });

        List<String> spokenWordsClean = _remediationSpokenText
            .toLowerCase()
            .replaceAll(RegExp(r'[^\w\s]'), '')
            .split(RegExp(r'\s+'));

        bool isMatch = spokenWordsClean.any(
          (spokenWord) => isWordMatch(word.cleanWord, spokenWord),
        );

        if (isMatch) {
          _resultLocked = true;
          word.isCorrect = true;
          widget.deepgramService.stopListening();
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
        } else if (isFinal) {
          _resultLocked = true;
          word.isCorrect = false;
          widget.deepgramService.stopListening();
          setState(() {
            _isListeningRemediation = false;
            _statusMessage = "Not quite! We'll practice it next time.";
          });
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted) {
              setState(() => _currentIndex++);
              _startWordTutoring();
            }
          });
        }
      },
    );
  }

  void _skipToNextWord() {
    _resultLocked = true;
    widget.deepgramService.stopListening();
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
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child:
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.amberAccent,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.black, width: 4),
              boxShadow: const [
                BoxShadow(color: Colors.black, offset: Offset(6, 6)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(
                      _isListeningRemediation
                          ? Icons.mic
                          : Icons.record_voice_over,
                      color: Colors.black,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      "Let's Practice!",
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  "Word ${_currentIndex + 1} of ${widget.failedWords.length}",
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.black, width: 3),
                    boxShadow: const [
                      BoxShadow(color: Colors.black, offset: Offset(3, 3)),
                    ],
                  ),
                  child: Text(
                    currentWord.originalWord,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isListeningRemediation)
                      const Padding(
                        padding: EdgeInsets.only(right: 8.0),
                        child: Icon(
                          Icons.mic,
                          color: Colors.redAccent,
                          size: 20,
                        ),
                      ),
                    Flexible(
                      child: Text(
                        _statusMessage,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _isListeningRemediation
                              ? Colors.redAccent
                              : Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_remediationSpokenText.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    "Heard: \"$_remediationSpokenText\"",
                    style: const TextStyle(
                      color: Colors.black54,
                      fontWeight: FontWeight.bold,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                if (!_isPlayingAudio)
                  Container(
                    width: double.infinity,
                    height: 50,
                    decoration: BoxDecoration(
                      boxShadow: const [
                        BoxShadow(color: Colors.black, offset: Offset(3, 3)),
                      ],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: Colors.black, width: 3),
                        ),
                        elevation: 0,
                      ),
                      onPressed: _skipToNextWord,
                      child: const Text(
                        "Next Word / Continue",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ).animate().slideY(
            begin: 1,
            end: 0,
            duration: 400.ms,
            curve: Curves.easeOutBack,
          ),
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

  static final Map<String, Map<String, String>> _dictCache = {};

  @override
  void initState() {
    super.initState();
    _fetchDefinition();
  }

  Future<void> _fetchDefinition() async {
    if (_dictCache.containsKey(widget.cleanWord)) {
      if (mounted) {
        setState(() {
          _partOfSpeech = _dictCache[widget.cleanWord]!['pos']!;
          _definition = _dictCache[widget.cleanWord]!['def']!;
          _isLoading = false;
        });
      }
      return;
    }

    try {
      final response = await http.get(
        Uri.parse(
          'https://api.dictionaryapi.dev/api/v2/entries/en/${widget.cleanWord}',
        ),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (data.isNotEmpty && data[0]['meanings'].isNotEmpty) {
          final firstMeaning = data[0]['meanings'][0];
          final pos = firstMeaning['partOfSpeech'] ?? '';
          if (firstMeaning['definitions'].isNotEmpty) {
            final def =
                firstMeaning['definitions'][0]['definition'] ??
                'No definition found.';
            _dictCache[widget.cleanWord] = {'pos': pos, 'def': def};
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
              : Text(_definition, style: const TextStyle(fontSize: 18)),
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
              child: const Text(
                'Close',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadingResultsDialog extends StatefulWidget {
  final int totalWordsCount;
  final int failedWordsCount;
  final int elapsedSeconds;
  final String wrPct;
  final String wrLevel;
  final List<WordStatus> allFailedWords;
  final VoidCallback onFinish;

  const _ReadingResultsDialog({
    required this.totalWordsCount,
    required this.failedWordsCount,
    required this.elapsedSeconds,
    required this.wrPct,
    required this.wrLevel,
    required this.allFailedWords,
    required this.onFinish,
  });

  @override
  State<_ReadingResultsDialog> createState() => _ReadingResultsDialogState();
}

class _ReadingResultsDialogState extends State<_ReadingResultsDialog> {
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );
    if (widget.wrLevel != "Frustration") _confettiController.play();
  }

  String get _feedbackMessage {
    switch (widget.wrLevel) {
      case "Independent":
        return "Wonderful reading! You read almost every word correctly.";
      case "Instructional":
        return "Good job! Keep practicing and you will get even better.";
      default:
        return "Nice try! Reading takes practice. Read the story again and practice the words below.";
    }
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  Widget _buildScoreRow({
    required IconData icon,
    required String label,
    required String value,
    required String sublabel,
    required String level,
  }) {
    Color levelColor = Colors.greenAccent;
    if (level == "Frustration") levelColor = Colors.redAccent;
    if (level == "Instructional") levelColor = Colors.amberAccent;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.amber, size: 28),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                sublabel,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            Text(
              level,
              style: TextStyle(
                color: levelColor,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        AlertDialog(
          backgroundColor: Colors.grey[900],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.star, color: Colors.amber),
              SizedBox(width: 8),
              Text(
                "Reading Results",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Your Phil-IRI Reading Score",
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 16),
                _buildScoreRow(
                  icon: Icons.record_voice_over,
                  label: "Word Recognition (WR)",
                  value: "${widget.wrPct}%",
                  sublabel:
                      "(${widget.totalWordsCount - widget.failedWordsCount} / ${widget.totalWordsCount} words correct)",
                  level: widget.wrLevel,
                ),
                const SizedBox(height: 12),
                _buildScoreRow(
                  icon: Icons.timer,
                  label: "Reading Duration",
                  value:
                      "${widget.elapsedSeconds ~/ 60}m ${widget.elapsedSeconds % 60}s",
                  sublabel: "Active time spent reading aloud",
                  level: "Independent",
                ),
                const SizedBox(height: 14),
                Text(
                  _feedbackMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const Divider(color: Colors.white24, height: 24),
                if (widget.allFailedWords.isNotEmpty) ...[
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Mispronounced Words:",
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: widget.allFailedWords
                        .map(
                          (word) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red[900],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.black,
                                width: 1.5,
                              ),
                            ),
                            child: Text(
                              word.originalWord,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Colors.black, width: 2.5),
                  ),
                  elevation: 4,
                ),
                onPressed: widget.onFinish,
                child: const Text(
                  "Finish Reading & Take Quiz",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ).animate().scaleXY(
          begin: 0.8,
          end: 1,
          duration: 400.ms,
          curve: Curves.easeOutBack,
        ),
        ConfettiWidget(
          confettiController: _confettiController,
          blastDirectionality: BlastDirectionality.explosive,
          emissionFrequency: 0.05,
          numberOfParticles: 25,
          maxBlastForce: 25,
          minBlastForce: 5,
          colors: const [
            Colors.green,
            Colors.blue,
            Colors.pink,
            Colors.orange,
            Colors.purple,
          ],
        ),
      ],
    );
  }
}
