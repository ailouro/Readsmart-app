// lib/services/assessment_score.dart

enum ReadingLevel { independent, instructional, frustration }

/// Result of one graded-passage attempt during a Phil-IRI-style
/// assessment: oral reading accuracy from StoryViewerScreen combined
/// with comprehension results from QuizScreen.
class PassageScore {
  final double wrPct; // word reading accuracy, 0-100
  final int totalWords;
  final int readingSeconds;
  final List<String> struggledWords;
  final int compCorrect;
  final int compTotal;

  PassageScore({
    required this.wrPct,
    required this.totalWords,
    required this.readingSeconds,
    required this.struggledWords,
    required this.compCorrect,
    required this.compTotal,
  });

  double get compPct =>
      compTotal > 0 ? (compCorrect / compTotal) * 100.0 : 0.0;

  ReadingLevel get wordReadingLevel {
    if (wrPct >= 97) return ReadingLevel.independent;
    if (wrPct >= 90) return ReadingLevel.instructional;
    return ReadingLevel.frustration;
  }

  ReadingLevel get comprehensionLevel {
    // No quiz attached to this passage (e.g. word-reading-only check):
    // fall back to the word reading level instead of silently scoring
    // 0% comprehension.
    if (compTotal == 0) return wordReadingLevel;
    if (compPct >= 80) return ReadingLevel.independent;
    if (compPct >= 59) return ReadingLevel.instructional;
    return ReadingLevel.frustration;
  }

  /// Phil-IRI takes the LOWER of the two sub-scores: a student who
  /// decodes perfectly but can't answer comprehension questions is
  /// not "independent" overall, and vice versa.
  ///
  /// NOTE: the 97/90 (word reading) and 80/59 (comprehension) cutoffs
  /// above are the commonly published Phil-IRI defaults. Replace them
  /// with the exact table from your program's manual/appendix if it
  /// specifies different bands.
  ReadingLevel get overallLevel {
    const order = [
      ReadingLevel.frustration,
      ReadingLevel.instructional,
      ReadingLevel.independent,
    ];
    final wr = order.indexOf(wordReadingLevel);
    final comp = order.indexOf(comprehensionLevel);
    return order[wr < comp ? wr : comp];
  }

  /// Direction the assessment should search next, per the Stage 2
  /// branching flowchart: +1 climbs a grade level, -1 descends.
  /// AssessmentFlowScreen uses this to pick the next passage.
  int get nextGradeLevelOffset {
    switch (overallLevel) {
      case ReadingLevel.independent:
      case ReadingLevel.instructional:
        return 1;
      case ReadingLevel.frustration:
        return -1;
    }
  }

  String get levelLabel {
    switch (overallLevel) {
      case ReadingLevel.independent:
        return 'Independent';
      case ReadingLevel.instructional:
        return 'Instructional';
      case ReadingLevel.frustration:
        return 'Frustration';
    }
  }
}

/// Table 3 (Starting Point for the Graded Passage) from the Phil-IRI
/// manual: converts a student's GST raw score into where the
/// individualized graded-passage assessment should begin.
class GstPlacement {
  /// Returns the grade level to start the graded passages at, or null
  /// if the GST score means testing should be discontinued (student is
  /// already performing at or above expectation).
  static int? startingGradeLevel({
    required int gstRawScore,
    required int currentGradeLevel,
    int minGradeLevel = 1,
  }) {
    int offset;
    if (gstRawScore <= 7) {
      offset = 3;
    } else if (gstRawScore <= 13) {
      offset = 2;
    } else {
      return null; // 14+ points: discontinue testing
    }
    final target = currentGradeLevel - offset;
    return target < minGradeLevel ? minGradeLevel : target;
  }
}
