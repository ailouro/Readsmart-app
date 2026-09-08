import 'package:audioplayers/audioplayers.dart';

class BgmService {
  static final BgmService _instance = BgmService._internal();
  factory BgmService() => _instance;
  BgmService._internal();

  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  bool _isInitialized = false;

  Future<void> startBgm() async {
    if (_isPlaying) return;
    try {
      if (!_isInitialized) {
        _player.setReleaseMode(ReleaseMode.loop);
        _isInitialized = true;
      }
      // Assuming you place a music file at assets/audio/bgm.mp3
      // We will wrap this in a try-catch so it doesn't crash if the file is missing yet.
      await _player.play(AssetSource('audio/bgm.mp3'), volume: 0.2);
      _isPlaying = true;
    } catch (e) {
      print("BGM Service Error: Asset missing or could not be played. Add bgm.mp3 to assets/audio/");
    }
  }

  Future<void> stopBgm() async {
    if (!_isPlaying) return;
    try {
      await _player.pause();
      _isPlaying = false;
    } catch (e) {
      print("BGM Service Error: $e");
    }
  }
}
