import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class SpeechService {
  final AudioRecorder _audioRecorder = AudioRecorder();
  WebSocketChannel? _channel;
  bool _isRecording = false;

  final String _deepgramApiKey = "7905187eebc3f25d97f256336e4db7374b62dbda";

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
    _isRecording = true;

    try {
      // Create WebSocket connection
      // For web, passing headers directly in WebSocketChannel is not supported.
      // Deepgram supports sending the token as a subprotocol:
      final uri = Uri.parse('wss://api.deepgram.com/v1/listen?encoding=linear16&sample_rate=16000&channels=1&model=nova-2&language=en');
      
      _channel = WebSocketChannel.connect(
        uri,
        protocols: ['token', _deepgramApiKey],
      );

      _channel!.stream.listen((message) {
        if (!_isRecording) return;
        try {
          final data = jsonDecode(message);
          if (data['is_final'] == true || data['is_final'] == false) {
            if (data['channel'] != null && 
                data['channel']['alternatives'] != null && 
                data['channel']['alternatives'].isNotEmpty) {
                  
              String transcript = data['channel']['alternatives'][0]['transcript'];
              if (transcript.isNotEmpty) {
                onResult(transcript);
              }
            }
          }
        } catch (e) {
          debugPrint("JSON Parse Error: $e");
        }
      }, onError: (error) {
        debugPrint("WebSocket Error: $error");
      }, onDone: () {
        debugPrint("WebSocket Closed");
      });

      // Start recording audio
      final stream = await _audioRecorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
        ),
      );

      stream.listen((data) {
        if (_isRecording && _channel != null) {
          _channel!.sink.add(data);
        }
      });

    } catch (e) {
      debugPrint("Start listening error: $e");
      _isRecording = false;
    }
  }

  void stopListening() {
    _isRecording = false;
    _audioRecorder.stop();
    // Send close message to Deepgram
    if (_channel != null) {
      _channel!.sink.add(jsonEncode({"type": "CloseStream"}));
      _channel!.sink.close();
      _channel = null;
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
