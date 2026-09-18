import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';

class BgmService with WidgetsBindingObserver {
  static final BgmService _instance = BgmService._internal();
  factory BgmService() => _instance;
  BgmService._internal() {
    WidgetsBinding.instance.addObserver(this);
  }

  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  bool _isInitialized = false;

  bool _wantsToPlay = false;
  bool _pausedByLifecycle = false;

  Future<void> startBgm() async {
    _wantsToPlay = true;
    if (_isPlaying) return;
    try {
      if (!_isInitialized) {
        _player.setReleaseMode(ReleaseMode.loop);
        _isInitialized = true;
      }
      await _player.play(AssetSource('audio/bgm.mp3'), volume: 0.2);
      _isPlaying = true;
    } catch (e) {
      print(
        "BGM Service Error: Asset missing or could not be played. Add bgm.mp3 to assets/audio/",
      );
    }
  }

  Future<void> stopBgm() async {
    _wantsToPlay = false;
    _pausedByLifecycle = false;
    if (!_isPlaying) return;
    try {
      await _player.pause();
      _isPlaying = false;
    } catch (e) {
      print("BGM Service Error: $e");
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        // Kapag hindi na active sa screen (app switcher, notification shade, lock screen, atbp.)
        if (_isPlaying) {
          _pausedByLifecycle = true;
          _player.pause();
          _isPlaying = false;
        }
        break;

      case AppLifecycleState.resumed:
        // Kapag bumalik na ulit at active na sa screen ang app
        if (_pausedByLifecycle && _wantsToPlay) {
          _pausedByLifecycle = false;
          _player
              .resume()
              .then((_) {
                _isPlaying = true;
              })
              .catchError((e) {
                print("BGM Service Error resuming: $e");
              });
        }
        break;

      default:
        break;
    }
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }
}
