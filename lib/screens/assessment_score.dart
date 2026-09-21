/// What one graded passage produced: the oral reading score from
/// [StoryViewerScreen] plus the comprehension score from [QuizScreen].
///
/// In assessment mode both screens return this with Navigator.pop instead of
/// saving progress themselves, so [AssessmentFlowScreen] can score the passage
/// with the Phil-IRI rules and save it once.
class PassageScore {
  final double wrPct;
  final int totalWords;
  final int readingSeconds;
  final List<String> struggledWords;
  final int compCorrect;
  final int compTotal;

  const PassageScore({
    required this.wrPct,
    required this.totalWords,
    required this.readingSeconds,
    required this.struggledWords,
    required this.compCorrect,
    required this.compTotal,
  });

  int get correctWords => (totalWords * wrPct / 100).round();

  double get wordsPerMinute {
    if (readingSeconds <= 0 || totalWords <= 0) return 0;
    return totalWords / readingSeconds * 60;
  }
}
