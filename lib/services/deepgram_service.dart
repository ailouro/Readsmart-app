import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

class DeepgramService {
  final String apiKey = "92de17d736efd3034ac8e590d1d59c905931a823";

  WebSocketChannel? _channel;
  final AudioRecorder _audioRecorder = AudioRecorder();
  StreamSubscription<List<int>>? _audioStreamSubscription;
  List<int> _audioBuffer = [];

  void clearAudioBuffer() {
    _audioBuffer.clear();
  }

  Future<String?> saveFailedWordAudio(String word) async {
    if (_audioBuffer.isEmpty) return null;
    
    try {
      final dir = await getTemporaryDirectory();
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String fileName = "struggle_${word}_$timestamp.wav";
      final File file = File('${dir.path}/$fileName');
      
      final int sampleRate = 16000;
      final int channels = 1;
      final int byteRate = sampleRate * channels * 2; // 16-bit
      final int dataSize = _audioBuffer.length;
      
      final ByteData header = ByteData(44);
      // RIFF chunk descriptor
      header.setUint8(0, 0x52); // 'R'
      header.setUint8(1, 0x49); // 'I'
      header.setUint8(2, 0x46); // 'F'
      header.setUint8(3, 0x46); // 'F'
      header.setUint32(4, 36 + dataSize, Endian.little);
      header.setUint8(8, 0x57); // 'W'
      header.setUint8(9, 0x41); // 'A'
      header.setUint8(10, 0x56); // 'V'
      header.setUint8(11, 0x45); // 'E'
      
      // fmt sub-chunk
      header.setUint8(12, 0x66); // 'f'
      header.setUint8(13, 0x6D); // 'm'
      header.setUint8(14, 0x74); // 't'
      header.setUint8(15, 0x20); // ' '
      header.setUint32(16, 16, Endian.little); // Subchunk1Size
      header.setUint16(20, 1, Endian.little); // AudioFormat (PCM)
      header.setUint16(22, channels, Endian.little);
      header.setUint32(24, sampleRate, Endian.little);
      header.setUint32(28, byteRate, Endian.little);
      header.setUint16(32, channels * 2, Endian.little); // BlockAlign
      header.setUint16(34, 16, Endian.little); // BitsPerSample
      
      // data sub-chunk
      header.setUint8(36, 0x64); // 'd'
      header.setUint8(37, 0x61); // 'a'
      header.setUint8(38, 0x74); // 't'
      header.setUint8(39, 0x61); // 'a'
      header.setUint32(40, dataSize, Endian.little);
      
      final BytesBuilder builder = BytesBuilder();
      builder.add(header.buffer.asUint8List());
      builder.add(_audioBuffer);
      
      await file.writeAsBytes(builder.takeBytes());
      return file.path;
    } catch (e) {
      debugPrint("Error saving WAV file: $e");
      return null;
    }
  }

  Future<void> startListening({
    required List<String> targetKeywords,
    required Function(String word, bool isFinal) onResult,
  }) async {
    _audioBuffer.clear();
    String keywordParams = targetKeywords.map((w) => "keywords=$w:2").join("&");

    // Use explicit linear16 encoding which is much more reliable across mobile devices
    final uri = Uri.parse(
      "wss://api.deepgram.com/v1/listen?model=nova-2&language=en&smart_format=false&encoding=linear16&sample_rate=16000&channels=1&endpointing=100&interim_results=true&$keywordParams",
    );

    _channel = WebSocketChannel.connect(uri, protocols: ['token', apiKey]);

    _channel!.stream.listen(
      (message) {
        final data = jsonDecode(message);
        if (data['channel'] != null) {
          final alternatives = data['channel']['alternatives'];
          if (alternatives != null && alternatives.isNotEmpty) {
            String transcript = alternatives[0]['transcript'] ?? "";
            bool isFinal = data['is_final'] ?? false;

            if (transcript.isNotEmpty) {
              onResult(transcript, isFinal);
            }
          }
        }
      },
      onError: (error) {
        debugPrint("Deepgram WS Error: $error");
      },
    );

    if (await _audioRecorder.hasPermission()) {
      try {
        final audioStream = await _audioRecorder.startStream(
          const RecordConfig(
            encoder: AudioEncoder.pcm16bits, // More reliable for native Android
            sampleRate: 16000,
            numChannels: 1,
          ),
        );

        _audioStreamSubscription = audioStream.listen((chunk) {
          _audioBuffer.addAll(chunk); // Keep in memory for struggle word recording
          if (_channel != null) {
            _channel!.sink.add(chunk);
          }
        });
      } catch (e) {
        debugPrint("Mic Stream Error: $e");
      }
    } else {
      debugPrint("Microphone permission denied.");
    }
  }

  Future<void> stopListening() async {
    await _audioStreamSubscription?.cancel();
    await _audioRecorder.stop();
    await _channel?.sink.close();
    _channel = null;
  }
}
