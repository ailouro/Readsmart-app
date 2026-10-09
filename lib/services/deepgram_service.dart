import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

/// Tala kung malusog ang mic/connection habang nagbabasa ang bata.
/// Ipadala ang [toJson] kasama ng progress para ang analytics ay may
/// TOTOONG datos kung bakit mababa ang Word Reading (hindi hula).
class MicHealth {
  int chunksSent = 0;
  int transcripts = 0;
  int finals = 0;
  int drops = 0; // ilang beses nawala ang connection
  int reconnects = 0;
  double peakLevel = 0; // 0..1, pinakamalakas na tunog na nahuli ng mic

  /// ok | no_audio | no_sound | no_transcript | unstable
  String get status {
    if (chunksSent == 0) return 'no_audio'; // walang audio na nakuha
    if (peakLevel < 0.02)
      return 'no_sound'; // tahimik ang mic (hardware/permission)
    if (transcripts == 0)
      return 'no_transcript'; // may tunog pero walang sagot ang Deepgram
    if (drops > 0) return 'unstable'; // nawalan ng connection habang nagbabasa
    return 'ok';
  }

  Map<String, dynamic> toJson() => {
    'mic_status': status,
    'mic_peak_level': double.parse(peakLevel.toStringAsFixed(3)),
    'asr_transcripts': transcripts,
    'asr_drops': drops,
  };
}

class DeepgramService {
  // HUWAG i-hardcode ang key. Ipasa sa build:
  //   flutter run --dart-define=DEEPGRAM_API_KEY=xxxx
  // (Mas ligtas pa: kumuha ng short-lived token mula sa Laravel.)
  static const String _apiKey = String.fromEnvironment('DEEPGRAM_API_KEY');

  // Ilang audio lang ang itatabi para sa "struggle word" recording
  // (6 na segundo ng 16kHz 16-bit mono). Dati lumalaki ito buong session.
  static const int _maxBufferBytes = 16000 * 2 * 6;
  static const int _maxPendingChunks =
      40; // ~ ilang segundo habang nagre-reconnect
  static const Duration _warmUp = Duration(milliseconds: 250);

  WebSocketChannel? _channel;
  final AudioRecorder _audioRecorder = AudioRecorder();
  StreamSubscription<List<int>>? _audioStreamSubscription;
  StreamSubscription? _wsSubscription;
  final List<int> _audioBuffer = [];
  final List<List<int>> _pending = [];
  Timer? _keepAliveTimer;
  Timer? _reconnectTimer;
  DateTime? _micStartedAt;

  bool _listening = false;
  bool _trackHealth =
      true; // false sa remediation retry: huwag guluhin ang sukat
  bool _socketReady = false;
  int _retry = 0;
  List<String> _keywords = const [];
  Function(String word, bool isFinal)? _onResult;

  MicHealth health = MicHealth();

  /// Tawagin ng screen isang beses bawat pagbasa (hindi bawat listen segment).
  void resetHealth() => health = MicHealth();

  void clearAudioBuffer() => _audioBuffer.clear();

  // ---------------------------------------------------------------- WAV save
  Future<String?> saveFailedWordAudio(String word) async {
    if (_audioBuffer.isEmpty) return null;

    try {
      final dir = await getTemporaryDirectory();
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String safeWord = word.replaceAll(RegExp(r'[^\w-]'), '_');
      final File file = File('${dir.path}/struggle_${safeWord}_$timestamp.wav');

      const int sampleRate = 16000;
      const int channels = 1;
      const int byteRate = sampleRate * channels * 2;
      final int dataSize = _audioBuffer.length;

      final ByteData header = ByteData(44);
      void tag(int offset, String s) {
        for (int i = 0; i < s.length; i++) {
          header.setUint8(offset + i, s.codeUnitAt(i));
        }
      }

      tag(0, 'RIFF');
      header.setUint32(4, 36 + dataSize, Endian.little);
      tag(8, 'WAVE');
      tag(12, 'fmt ');
      header.setUint32(16, 16, Endian.little);
      header.setUint16(20, 1, Endian.little);
      header.setUint16(22, channels, Endian.little);
      header.setUint32(24, sampleRate, Endian.little);
      header.setUint32(28, byteRate, Endian.little);
      header.setUint16(32, channels * 2, Endian.little);
      header.setUint16(34, 16, Endian.little);
      tag(36, 'data');
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

  // ---------------------------------------------------------------- Listening
  Future<void> startListening({
    required List<String> targetKeywords,
    required Function(String word, bool isFinal) onResult,
    bool trackHealth = true,
  }) async {
    if (_listening) return;
    _listening = true;
    _trackHealth = trackHealth;
    _audioBuffer.clear();
    _pending.clear();
    _retry = 0;
    _keywords = targetKeywords
        .map((w) => w.trim())
        .where((w) => w.isNotEmpty)
        .toSet()
        .toList();
    _onResult = onResult;

    await _connect();

    _keepAliveTimer?.cancel();
    _keepAliveTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_socketReady && _channel != null) {
        try {
          _channel!.sink.add(jsonEncode({"type": "KeepAlive"}));
        } catch (e) {
          debugPrint("KeepAlive send failed: $e");
        }
      }
    });

    if (await _audioRecorder.hasPermission()) {
      try {
        final audioStream = await _audioRecorder.startStream(
          const RecordConfig(
            encoder: AudioEncoder.pcm16bits,
            sampleRate: 16000,
            numChannels: 1,
          ),
        );

        _micStartedAt = DateTime.now();
        _audioStreamSubscription = audioStream.listen(_onAudioChunk);
      } catch (e) {
        debugPrint("Mic Stream Error: $e");
      }
    } else {
      debugPrint("Microphone permission denied.");
    }
  }

  void _onAudioChunk(List<int> chunk) {
    // Para sa struggle-word recording (may limitasyon na ang laki).
    _audioBuffer.addAll(chunk);
    if (_audioBuffer.length > _maxBufferBytes) {
      _audioBuffer.removeRange(0, _audioBuffer.length - _maxBufferBytes);
    }

    final peak = _peak(chunk);
    if (_trackHealth && peak > health.peakLevel) health.peakLevel = peak;

    // Iwasang marinig ang sariling TTS prompt ng app sa pinakaunang sandali.
    final bool warmedUp =
        _micStartedAt == null ||
        DateTime.now().difference(_micStartedAt!) >= _warmUp;
    if (!warmedUp) return;

    if (_socketReady && _channel != null) {
      try {
        _channel!.sink.add(chunk);
        if (_trackHealth) health.chunksSent++;
      } catch (e) {
        debugPrint("Audio send failed: $e");
      }
    } else {
      // Nawala ang connection: itabi sandali, ipapadala pagbalik ng socket
      // para hindi mawala ang mga salitang binasa ng bata.
      _pending.add(chunk);
      if (_pending.length > _maxPendingChunks) _pending.removeAt(0);
      if (_trackHealth)
        health.chunksSent++; // may audio naman, ang connection ang may problema
    }
  }

  double _peak(List<int> c) {
    int max = 0;
    for (int i = 0; i + 1 < c.length; i += 16) {
      int s = c[i] | (c[i + 1] << 8);
      if (s >= 32768) s -= 65536;
      if (s < 0) s = -s;
      if (s > max) max = s;
    }
    return max / 32768.0;
  }

  // --------------------------------------------------------------- Connection
  Future<void> _connect() async {
    _socketReady = false;
    await _wsSubscription?.cancel();

    final uri = Uri(
      scheme: 'wss',
      host: 'api.deepgram.com',
      path: '/v1/listen',
      queryParameters: {
        'model': 'nova-2',
        'language': 'en',
        'smart_format': 'false',
        'encoding': 'linear16',
        'sample_rate': '16000',
        'channels': '1',
        'endpointing': '10',
        'vad_events': 'true',
        'utterance_end_ms': '1000',
        'interim_results': 'true',
        // naka-encode na nang tama (dati raw string kaya puwedeng masira)
        if (_keywords.isNotEmpty) 'keywords': _keywords.map((w) => '$w:2'),
      },
    );

    try {
      final channel = WebSocketChannel.connect(
        uri,
        protocols: ['token', _apiKey],
      );
      _channel = channel;
      await channel.ready; // hintayin ang totoong koneksyon

      _wsSubscription = channel.stream.listen(
        _onMessage,
        onError: (error) {
          debugPrint("Deepgram WS Error: $error");
          _onSocketLost();
        },
        onDone: () {
          debugPrint(
            "Deepgram WS closed (code: ${channel.closeCode}, reason: ${channel.closeReason})",
          );
          _onSocketLost();
        },
      );

      _socketReady = true;
      _retry = 0;

      // Ipadala ang naipong audio habang wala ang connection.
      for (final c in _pending) {
        channel.sink.add(c);
      }
      _pending.clear();
    } catch (e) {
      debugPrint("Deepgram connect failed: $e");
      _onSocketLost();
    }
  }

  void _onMessage(dynamic message) {
    try {
      final data = jsonDecode(message);
      if (data['type'] == 'UtteranceEnd') return;

      final alternatives = data['channel']?['alternatives'];
      if (alternatives is List && alternatives.isNotEmpty) {
        final String transcript = alternatives[0]['transcript'] ?? '';
        final bool isFinal = data['is_final'] ?? false;
        if (transcript.isNotEmpty) {
          if (_trackHealth) {
            health.transcripts++;
            if (isFinal) health.finals++;
          }
          _onResult?.call(transcript, isFinal);
        }
      }
    } catch (e) {
      debugPrint("Deepgram parse error: $e");
    }
  }

  void _onSocketLost() {
    if (!_listening) return; // normal na pagsara
    if (_socketReady && _trackHealth) health.drops++;
    _socketReady = false;
    if (_reconnectTimer?.isActive ?? false) return;

    // Exponential backoff: 0.5s, 1s, 2s ... hanggang 5s
    final delay = Duration(
      milliseconds: (500 * (1 << _retry.clamp(0, 4))).clamp(500, 5000),
    );
    _retry++;
    _reconnectTimer = Timer(delay, () async {
      if (!_listening) return;
      if (_trackHealth) health.reconnects++;
      await _connect();
    });
  }

  // ------------------------------------------------------------------- Stop
  Future<void> stopListening() async {
    _listening = false;
    _keepAliveTimer?.cancel();
    _keepAliveTimer = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _micStartedAt = null;

    await _audioStreamSubscription?.cancel();
    _audioStreamSubscription = null;
    await _audioRecorder.stop();

    // Hayaang mag-flush ang Deepgram ng huling salita bago isara.
    // Dati agad isinasara kaya nawawala ang final transcript ng huling salita.
    try {
      if (_socketReady && _channel != null) {
        _channel!.sink.add(jsonEncode({"type": "CloseStream"}));
        await Future.delayed(const Duration(milliseconds: 400));
      }
    } catch (_) {}

    await _wsSubscription?.cancel();
    _wsSubscription = null;
    try {
      await _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    _socketReady = false;
    _pending.clear();
  }
}
