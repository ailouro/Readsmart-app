import 'dart:math' as math;

import 'phil_iri_rules.dart';

/// One graded passage attempt (oral reading + comprehension quiz).
class PassageResult {
  final int grade;
  final dynamic storyId; // the app uses story['id'] ?? story['_id']
  final double wrPct;
  final int compCorrect;
  final int compTotal;
  final ReadingLevel wrLevel;
  final ReadingLevel compLevel;
  final ReadingLevel level; // the level that drives the flowchart

  const PassageResult({
    required this.grade,
    required this.storyId,
    required this.wrPct,
    required this.compCorrect,
    required this.compTotal,
    required this.wrLevel,
    required this.compLevel,
    required this.level,
  });

  /// Scores a passage from raw numbers.
  factory PassageResult.score({
    required int grade,
    required dynamic storyId,
    required double wrPct,
    required int compCorrect,
    required int compTotal,
    LevelRule rule = LevelRule.lowerOfBoth,
  }) {
    final wr = PhilIriRules.wordReadingLevel(wrPct);
    final comp = PhilIriRules.comprehensionLevel(compCorrect, compTotal);
    return PassageResult(
      grade: grade,
      storyId: storyId,
      wrPct: wrPct,
      compCorrect: compCorrect,
      compTotal: compTotal,
      wrLevel: wr,
      compLevel: comp,
      level: PhilIriRules.combine(wr, comp, rule: rule),
    );
  }

  Map<String, dynamic> toJson() => {
    'grade': grade,
    'story_id': storyId,
    'wr_pct': wrPct,
    'comp_correct': compCorrect,
    'comp_total': compTotal,
    'wr_level': wrLevel.name,
    'comp_level': compLevel.name,
    'level': level.name,
  };

  factory PassageResult.fromJson(Map<String, dynamic> j) => PassageResult(
    grade: j['grade'] as int,
    storyId: j['story_id'],
    wrPct: (j['wr_pct'] as num).toDouble(),
    compCorrect: j['comp_correct'] as int,
    compTotal: j['comp_total'] as int,
    wrLevel: ReadingLevel.values.byName(j['wr_level'] as String),
    compLevel: ReadingLevel.values.byName(j['comp_level'] as String),
    level: ReadingLevel.values.byName(j['level'] as String),
  );
}

/// What Stage 2 found for the student.
class PhilIriOutcome {
  /// Highest grade read at the Independent level.
  final int? independentGrade;

  /// Highest grade read at the Instructional level.
  final int? instructionalGrade;

  /// Lowest grade read at the Frustration level.
  final int? frustrationGrade;

  /// No Independent level found even at the lowest available grade (Grade 2).
  final bool belowRange;

  /// No Frustration level found even at the highest available grade (Grade 7).
  final bool aboveRange;

  const PhilIriOutcome({
    this.independentGrade,
    this.instructionalGrade,
    this.frustrationGrade,
    this.belowRange = false,
    this.aboveRange = false,
  });
}

/// Runs the Phil-IRI Stage 2 flowchart for one student and one test
/// (pre-test or post-test) on one passage set (A-D).
///
/// Flowchart, in short: keep moving until the Independent, Instructional and
/// Frustration levels are found.
///  - Going up: from Independent or Instructional, give a higher grade until
///    Frustration is found.
///  - Going down: once Frustration is found (or the student started there),
///    give grades below the starting point until Independent is found.
class PhilIriSession {
  final int studentId;
  final int studentGrade;
  final String testType; // 'pre_test' | 'post_test'
  final String setLetter; // 'A' | 'B' | 'C' | 'D'
  final int startGrade;
  final LevelRule rule;
  final Map<int, PassageResult> _results;

  PhilIriSession._({
    required this.studentId,
    required this.studentGrade,
    required this.testType,
    required this.setLetter,
    required this.startGrade,
    required this.rule,
    Map<int, PassageResult>? results,
  }) : _results = results ?? <int, PassageResult>{};

  /// Pre-test. Returns null when the GST raw score is 14 or more, because
  /// the manual says no further testing is needed.
  static PhilIriSession? forPreTest({
    required int studentId,
    required int studentGrade,
    required int gstRaw,
    required String setLetter,
    LevelRule rule = LevelRule.lowerOfBoth,
  }) {
    final start = PhilIriRules.startGrade(
      studentGrade: studentGrade,
      gstRaw: gstRaw,
    );
    if (start == null) return null;
    return PhilIriSession._(
      studentId: studentId,
      studentGrade: studentGrade,
      testType: 'pre_test',
      setLetter: setLetter,
      startGrade: start,
      rule: rule,
    );
  }

  /// Post-test. The manual only says to identify the three levels again, so
  /// the starting grade is a parameter. Reusing the pre-test start grade is
  /// the simplest choice; confirm what your teachers want.
  static PhilIriSession forPostTest({
    required int studentId,
    required int studentGrade,
    required String setLetter,
    required int startGrade,
    LevelRule rule = LevelRule.lowerOfBoth,
  }) {
    return PhilIriSession._(
      studentId: studentId,
      studentGrade: studentGrade,
      testType: 'post_test',
      setLetter: setLetter,
      startGrade: math.max(
        PhilIriRules.minGrade,
        math.min(PhilIriRules.maxGrade, startGrade),
      ),
      rule: rule,
    );
  }

  List<PassageResult> get history => List.unmodifiable(_results.values);

  bool _has(ReadingLevel l) => _results.values.any((r) => r.level == l);

  /// The grade of the next passage to give, or null when Stage 2 is done.
  int? get nextGrade {
    if (_results.isEmpty) return startGrade;

    final grades = _results.keys.toList()..sort();
    final highest = grades.last;
    final lowest = grades.first;

    // Going up: look for Frustration.
    if (!_has(ReadingLevel.frustration) && highest < PhilIriRules.maxGrade) {
      return highest + 1;
    }
    // Going down: look for Independent, below the lowest grade read so far.
    if (!_has(ReadingLevel.independent) && lowest > PhilIriRules.minGrade) {
      return lowest - 1;
    }
    return null;
  }

  bool get isComplete => _results.isNotEmpty && nextGrade == null;

  /// Saves a passage result. It must be for the grade the session asked for.
  void record(PassageResult result) {
    final expected = nextGrade;
    if (expected == null) {
      throw StateError('Stage 2 is already complete.');
    }
    if (result.grade != expected) {
      throw StateError(
        'Expected a Grade $expected passage but got Grade ${result.grade}.',
      );
    }
    _results[result.grade] = result;
  }

  PhilIriOutcome get outcome {
    int? highestOf(ReadingLevel l) {
      final g = _results.values.where((r) => r.level == l).map((r) => r.grade);
      return g.isEmpty ? null : g.reduce((a, b) => a > b ? a : b);
    }

    int? lowestOf(ReadingLevel l) {
      final g = _results.values.where((r) => r.level == l).map((r) => r.grade);
      return g.isEmpty ? null : g.reduce((a, b) => a < b ? a : b);
    }

    final grades = _results.keys.toList()..sort();
    final independent = highestOf(ReadingLevel.independent);
    final frustration = lowestOf(ReadingLevel.frustration);

    return PhilIriOutcome(
      independentGrade: independent,
      instructionalGrade: highestOf(ReadingLevel.instructional),
      frustrationGrade: frustration,
      belowRange:
          grades.isNotEmpty &&
          independent == null &&
          grades.first == PhilIriRules.minGrade,
      aboveRange:
          grades.isNotEmpty &&
          frustration == null &&
          grades.last == PhilIriRules.maxGrade,
    );
  }

  Map<String, dynamic> toJson() => {
    'student_id': studentId,
    'student_grade': studentGrade,
    'test_type': testType,
    'set_letter': setLetter,
    'start_grade': startGrade,
    'rule': rule.name,
    'results': _results.values.map((r) => r.toJson()).toList(),
  };

  factory PhilIriSession.fromJson(Map<String, dynamic> j) {
    final results = <int, PassageResult>{};
    for (final raw in (j['results'] as List)) {
      final r = PassageResult.fromJson(Map<String, dynamic>.from(raw as Map));
      results[r.grade] = r;
    }
    return PhilIriSession._(
      studentId: j['student_id'] as int,
      studentGrade: j['student_grade'] as int,
      testType: j['test_type'] as String,
      setLetter: j['set_letter'] as String,
      startGrade: j['start_grade'] as int,
      rule: LevelRule.values.byName(j['rule'] as String),
      results: results,
    );
  }
}
