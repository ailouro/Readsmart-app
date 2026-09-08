import 'package:flutter_tts/flutter_tts.dart';

class TtsNarrator {
  final FlutterTts _flutterTts = FlutterTts();

  // 1. I-configure ang boses ng Narrator
  Future<void> initNarrator() async {
    // I-set sa English dahil English ang module ninyo
    await _flutterTts.setLanguage("en-US");

    // BAGALAN ANG PAGSASALITA (Masyadong mabilis ang default na 0.5 para sa mga bata)
    await _flutterTts.setSpeechRate(0.4);

    // I-set ang tono (Pitch) - 1.0 ay normal, medyo lakasan ng konti kung gusto ng cartoonish
    await _flutterTts.setPitch(1.0);
  }

  // 2. Ang function na magpapasalita sa Narrator
  Future<void> speak(String sentence) async {
    await _flutterTts.speak(sentence);
  }

  // 3. Pag-stop sa Narrator (importante ito para kung gusto ihinto ng bata ang pagbasa)
  Future<void> stop() async {
    await _flutterTts.stop();
  }
}
