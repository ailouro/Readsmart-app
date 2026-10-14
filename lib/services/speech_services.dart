import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class SpeechService {
  final AudioRecorder _audioRecorder = AudioRecorder();
  WebSocketChannel? _channel;
  StreamSubscription<List<int>>? _audioSub;
  StreamSubscription? _wsSub;
  bool _isRecording = false;

  // HUWAG i-hardcode ang key. Ipasa sa build:
  //   flutter run --dart-define=DEEPGRAM_API_KEY=xxxx
  static const String _deepgramApiKey = String.fromEnvironment(
    'DEEPGRAM_API_KEY',
  );

  Future<bool> initSpeech() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("Error initializing speech: $e");
      return false;
    }
  }

  void startListening(Function(String) onResult) async {
    if (_isRecording) return;

    if (_deepgramApiKey.isEmpty) {
      debugPrint(
        "DEEPGRAM_API_KEY is empty. Run with --dart-define=DEEPGRAM_API_KEY=83753f44ae2998a12ef160454cff235de71acb3a",
      );
      return;
    }

    _isRecording = true;

    try {
      // Create WebSocket connection
      // For web, passing headers directly in WebSocketChannel is not supported.
      // Deepgram supports sending the token as a subprotocol:
      final uri = Uri.parse(
        'wss://api.deepgram.com/v1/listen?encoding=linear16&sample_rate=16000&channels=1&model=nova-2&language=en',
      );

      _channel = WebSocketChannel.connect(
        uri,
        protocols: ['token', _deepgramApiKey],
      );

      _wsSub = _channel!.stream.listen(
        (message) {
          if (!_isRecording) return;
          try {
            final data = jsonDecode(message);
            if (data['is_final'] == true || data['is_final'] == false) {
              if (data['channel'] != null &&
                  data['channel']['alternatives'] != null &&
                  data['channel']['alternatives'].isNotEmpty) {
                String transcript =
                    data['channel']['alternatives'][0]['transcript'];
                if (transcript.isNotEmpty) {
                  onResult(transcript);
                }
              }
            }
          } catch (e) {
            debugPrint("JSON Parse Error: $e");
          }
        },
        onError: (error) {
          debugPrint("WebSocket Error: $error");
        },
        onDone: () {
          debugPrint("WebSocket Closed");
        },
      );

      // Kung may natirang recording, isara muna (ligtas sa Windows).
      if (await _audioRecorder.isRecording()) {
        await _audioRecorder.stop();
      }

      // Start recording audio
      final stream = await _audioRecorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
        ),
      );

      _audioSub = stream.listen((data) {
        if (_isRecording && _channel != null) {
          try {
            _channel!.sink.add(data);
          } catch (e) {
            debugPrint("Audio send failed: $e");
          }
        }
      });
    } catch (e) {
      debugPrint("Start listening error: $e");
      _isRecording = false;
    }
  }

  Future<void> stopListening() async {
    _isRecording = false;

    await _audioSub?.cancel();
    _audioSub = null;

    // Huwag tawagin ang stop() kung hindi naman nagre-record: puwedeng
    // mag-crash ang native recorder sa Windows.
    try {
      if (await _audioRecorder.isRecording()) {
        await _audioRecorder.stop();
      }
    } catch (e) {
      debugPrint("Recorder stop failed: $e");
    }

    // Send close message to Deepgram
    try {
      if (_channel != null) {
        _channel!.sink.add(jsonEncode({"type": "CloseStream"}));
        await _channel!.sink.close();
      }
    } catch (_) {}
    _channel = null;

    await _wsSub?.cancel();
    _wsSub = null;
  }

  /// Tawagin kapag hindi na gagamitin ang service (halimbawa sa dispose()).
  Future<void> dispose() async {
    await stopListening();
    try {
      await _audioRecorder.dispose();
    } catch (e) {
      debugPrint("Recorder dispose failed: $e");
    }
  }

  // Same evaluate method from original just in case it's called anywhere
  Map<String, dynamic> evaluateSpeech({
    required String targetText,
    required String spokenText,
  }) {
    RegExp regExp = RegExp(r"[^\w\s]");
    List<String> targetWords = targetText
        .toLowerCase()
        .replaceAll(regExp, '')
        .split(RegExp(r'\s+'));
    List<String> spokenWords = spokenText
        .toLowerCase()
        .replaceAll(regExp, '')
        .split(RegExp(r'\s+'));

    List<String> mispronunciations = [];
    int correctCount = 0;

    for (int i = 0; i < targetWords.length; i++) {
      String expected = targetWords[i];
      if (spokenWords.contains(expected)) {
        correctCount++;
      } else {
        mispronunciations.add(expected);
      }
    }

    double accuracy = targetWords.isNotEmpty
        ? double.parse(
            ((correctCount / targetWords.length) * 100).toStringAsFixed(1),
          )
        : 0.0;

    return {
      'accuracy': accuracy,
      'mispronunciations': mispronunciations,
      'total_words': targetWords.length,
      'correct_words': correctCount,
    };
  }
}
