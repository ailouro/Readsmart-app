import '../models/target_word.dart';

/// Tina-transform ang raw string galing sa Database/Editor
/// (halimbawa: "One day, a [frog|🐸] sat on a lily pad.")
/// papuntang List<TargetWord>
List<TargetWord> parseStoryContent(String rawText) {
  List<TargetWord> parsedWords = [];

  // Hatiin ang buong text gamit ang whitespace
  List<String> tokens = rawText.split(RegExp(r'\s+'));

  // Regex pattern para sa [aiWord|displaySymbol]
  final bracketRegex = RegExp(r'\[(.*?)\|(.*?)\]');

  for (String token in tokens) {
    if (token.isEmpty) continue;

    final match = bracketRegex.firstMatch(token);

    if (match != null) {
      // Kapag nahanap ang bracket format tulad ng [frog|🐸]
      String aiWord = match.group(1)!; // "frog"
      String uiWord = match.group(2)!; // "🐸"

      // Pinapanatili ang punctuation sa dulo kung mayroon man (hal. "[frog|🐸]," -> "🐸,")
      String fullDisplayWord = token.replaceFirst(bracketRegex, uiWord);

      parsedWords.add(
        TargetWord(
          cleanWord: _cleanPunctuation(aiWord),
          displayWord: fullDisplayWord,
        ),
      );
    } else {
      // Normal na salita
      parsedWords.add(
        TargetWord(cleanWord: _cleanPunctuation(token), displayWord: token),
      );
    }
  }

  return parsedWords;
}

/// Tinatanggal ang punctuation marks para malinis ang ipapasang keywords sa Deepgram
String _cleanPunctuation(String word) {
  return word.replaceAll(RegExp(r'[^\w\s]+'), '').toLowerCase();
}
