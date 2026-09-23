class TargetWord {
  final String
  cleanWord; // Gagamitin para sa Deepgram / AI Evaluation (hal. "frog")
  final String displayWord; // Gagamitin para sa Yellow Box UI (hal. "🐸")

  TargetWord({required this.cleanWord, required this.displayWord});

  @override
  String toString() => 'TargetWord(clean: $cleanWord, display: $displayWord)';
}
