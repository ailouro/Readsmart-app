import 'dart:math' as math;

/// Phil-IRI 2018 rules for the English Graded Passages.
///
/// Sources in the Phil-IRI Manual of Administration:
///  - Table 6  (comprehension percentage per number of items)
///  - Table 7  (Oral Reading Profile: Word Reading / Comprehension cut-offs)
///  - Stage 1 / Stage 2 Step 1 (GST cut-off and starting grade)

enum ReadingLevel { independent, instructional, frustration }

extension ReadingLevelLabel on ReadingLevel {
  String get label {
    switch (this) {
      case ReadingLevel.independent:
        return 'Independent';
      case ReadingLevel.instructional:
        return 'Instructional';
      case ReadingLevel.frustration:
        return 'Frustration';
    }
  }
}

/// Which score decides a passage's level.
///
/// The manual reports Word Reading and Comprehension levels separately and
/// does not spell out a single combined rule, so this is a project decision.
/// [lowerOfBoth] is the conservative default: the weaker of the two wins.
enum LevelRule { lowerOfBoth, wordReadingOnly, comprehensionOnly }

class PhilIriRules {
  PhilIriRules._();

  /// English graded passages exist for Grades 2 to 7.
  static const int minGrade = 2;
  static const int maxGrade = 7;

  /// GST raw score at or above this needs no further testing.
  static const int gstCutoff = 14;

  /// Word Reading %, from correct words over total words.
  static double wordReadingPct({
    required int totalWords,
    required int correctWords,
  }) {
    if (totalWords <= 0) return 0;
    final pct = correctWords / totalWords * 100.0;
    return double.parse(pct.toStringAsFixed(2));
  }

  /// Table 7, Word Reading: 97-100 Independent, 90-96 Instructional,
  /// 89 and below Frustration.
  static ReadingLevel wordReadingLevel(double pct) {
    if (pct >= 97) return ReadingLevel.independent;
    if (pct >= 90) return ReadingLevel.instructional;
    return ReadingLevel.frustration;
  }

  /// Table 6: comprehension % is correct / items, rounded to a whole number
  /// (for example 5/7 = 71, 4/7 = 57, 5/8 = 63, 7/8 = 88).
  static int comprehensionPct(int correct, int total) {
    if (total <= 0) return 0;
    return (correct / total * 100).round();
  }

  /// Table 7, Comprehension: 80-100 Independent, 59-79 Instructional,
  /// 58 and below Frustration.
  static ReadingLevel comprehensionLevel(int correct, int total) {
    final pct = comprehensionPct(correct, total);
    if (pct >= 80) return ReadingLevel.independent;
    if (pct >= 59) return ReadingLevel.instructional;
    return ReadingLevel.frustration;
  }

  static ReadingLevel combine(
    ReadingLevel wordReading,
    ReadingLevel comprehension, {
    LevelRule rule = LevelRule.lowerOfBoth,
  }) {
    switch (rule) {
      case LevelRule.wordReadingOnly:
        return wordReading;
      case LevelRule.comprehensionOnly:
        return comprehension;
      case LevelRule.lowerOfBoth:
        // enum order is independent(0) < instructional(1) < frustration(2),
        // so the larger index is the weaker performance.
        return wordReading.index >= comprehension.index
            ? wordReading
            : comprehension;
    }
  }

  /// Stage 2, Step 1: first passage depends on the GST raw score (0-20).
  ///  - 14 or more   -> no further testing (returns null)
  ///  - 8 to 13      -> 2 grade levels below the student's grade
  ///  - 0 to 7       -> 3 grade levels below the student's grade
  /// The result is kept inside the available passages (Grades 2-7).
  static int? startGrade({required int studentGrade, required int gstRaw}) {
    if (gstRaw < 0 || gstRaw > 20) {
      throw ArgumentError.value(gstRaw, 'gstRaw', 'GST raw score is 0-20');
    }
    if (gstRaw >= gstCutoff) return null;
    final levelsBelow = gstRaw <= 7 ? 3 : 2;
    return math.max(minGrade, math.min(maxGrade, studentGrade - levelsBelow));
  }
}
