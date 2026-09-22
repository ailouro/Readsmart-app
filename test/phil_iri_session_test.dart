import 'package:flutter_test/flutter_test.dart';
import 'package:theapp/services/phil_iri_rules.dart';
import 'package:theapp/services/phil_iri_session.dart';

/// Builds a result that lands on the wanted level (7-question passage).
PassageResult result(int grade, ReadingLevel level) {
  const wr = {
    ReadingLevel.independent: 98.0,
    ReadingLevel.instructional: 93.0,
    ReadingLevel.frustration: 80.0,
  };
  const correct = {
    ReadingLevel.independent: 7,
    ReadingLevel.instructional: 5,
    ReadingLevel.frustration: 2,
  };
  return PassageResult.score(
    grade: grade,
    storyId: grade,
    wrPct: wr[level]!,
    compCorrect: correct[level]!,
    compTotal: 7,
  );
}

PhilIriSession pre(int studentGrade, int gstRaw) => PhilIriSession.forPreTest(
  studentId: 1,
  studentGrade: studentGrade,
  gstRaw: gstRaw,
  setLetter: 'A',
)!;

void main() {
  group('scoring (Table 6 and 7)', () {
    test('word reading cut-offs', () {
      expect(PhilIriRules.wordReadingLevel(100), ReadingLevel.independent);
      expect(PhilIriRules.wordReadingLevel(97), ReadingLevel.independent);
      expect(PhilIriRules.wordReadingLevel(96), ReadingLevel.instructional);
      expect(PhilIriRules.wordReadingLevel(90), ReadingLevel.instructional);
      expect(PhilIriRules.wordReadingLevel(89), ReadingLevel.frustration);
    });

    test('Grade 5 (7 items) comprehension', () {
      expect(PhilIriRules.comprehensionLevel(7, 7), ReadingLevel.independent);
      expect(PhilIriRules.comprehensionLevel(6, 7), ReadingLevel.independent);
      expect(PhilIriRules.comprehensionLevel(5, 7), ReadingLevel.instructional);
      expect(PhilIriRules.comprehensionLevel(4, 7), ReadingLevel.frustration);
    });

    test('Grade 6 (8 items) comprehension', () {
      expect(PhilIriRules.comprehensionLevel(8, 8), ReadingLevel.independent);
      expect(PhilIriRules.comprehensionLevel(7, 8), ReadingLevel.independent);
      expect(PhilIriRules.comprehensionLevel(6, 8), ReadingLevel.instructional);
      expect(PhilIriRules.comprehensionLevel(5, 8), ReadingLevel.instructional);
      expect(PhilIriRules.comprehensionLevel(4, 8), ReadingLevel.frustration);
    });

    test('lower of both wins by default', () {
      expect(
        PhilIriRules.combine(
          ReadingLevel.independent,
          ReadingLevel.instructional,
        ),
        ReadingLevel.instructional,
      );
      expect(
        PhilIriRules.combine(
          ReadingLevel.instructional,
          ReadingLevel.frustration,
        ),
        ReadingLevel.frustration,
      );
    });
  });

  group('start grade (Stage 2, Step 1)', () {
    test('GST 14 or more needs no test', () {
      expect(PhilIriRules.startGrade(studentGrade: 5, gstRaw: 14), isNull);
      expect(
        PhilIriSession.forPreTest(
          studentId: 1,
          studentGrade: 5,
          gstRaw: 18,
          setLetter: 'A',
        ),
        isNull,
      );
    });

    test('0-7 is three grades below, 8-13 is two below', () {
      expect(PhilIriRules.startGrade(studentGrade: 5, gstRaw: 6), 2);
      expect(PhilIriRules.startGrade(studentGrade: 5, gstRaw: 10), 3);
      expect(PhilIriRules.startGrade(studentGrade: 6, gstRaw: 7), 3);
      expect(PhilIriRules.startGrade(studentGrade: 6, gstRaw: 8), 4);
    });

    test('never goes below Grade 2', () {
      expect(PhilIriRules.startGrade(studentGrade: 3, gstRaw: 0), 2);
    });

    test('rejects impossible scores', () {
      expect(
        () => PhilIriRules.startGrade(studentGrade: 5, gstRaw: 21),
        throwsArgumentError,
      );
    });
  });

  group('flowchart branches', () {
    test('starts Independent: goes up until Frustration', () {
      final s = pre(5, 10); // starts at Grade 3
      expect(s.nextGrade, 3);
      s.record(result(3, ReadingLevel.independent));
      expect(s.nextGrade, 4);
      s.record(result(4, ReadingLevel.instructional));
      expect(s.nextGrade, 5);
      s.record(result(5, ReadingLevel.frustration));
      expect(s.nextGrade, isNull);
      expect(s.isComplete, isTrue);

      final o = s.outcome;
      expect(o.independentGrade, 3);
      expect(o.instructionalGrade, 4);
      expect(o.frustrationGrade, 5);
      expect(o.belowRange, isFalse);
      expect(o.aboveRange, isFalse);
    });

    test('starts Instructional: up to Frustration, then below the start', () {
      final s = pre(6, 8); // starts at Grade 4
      s.record(result(4, ReadingLevel.instructional));
      expect(s.nextGrade, 5);
      s.record(result(5, ReadingLevel.frustration));
      expect(s.nextGrade, 3); // below the starting point
      s.record(result(3, ReadingLevel.independent));
      expect(s.isComplete, isTrue);
      expect(s.outcome.independentGrade, 3);
      expect(s.outcome.instructionalGrade, 4);
      expect(s.outcome.frustrationGrade, 5);
    });

    test('starts Frustration: down to Instructional, then to Independent', () {
      final s = pre(6, 8); // starts at Grade 4
      s.record(result(4, ReadingLevel.frustration));
      expect(s.nextGrade, 3);
      s.record(result(3, ReadingLevel.instructional));
      expect(s.nextGrade, 2);
      s.record(result(2, ReadingLevel.independent));
      expect(s.isComplete, isTrue);
      expect(s.outcome.independentGrade, 2);
      expect(s.outcome.instructionalGrade, 3);
      expect(s.outcome.frustrationGrade, 4);
    });

    test('Frustration at Grade 2 is reported as below range', () {
      final s = pre(3, 0); // starts at Grade 2
      s.record(result(2, ReadingLevel.frustration));
      expect(s.isComplete, isTrue);
      expect(s.outcome.belowRange, isTrue);
      expect(s.outcome.independentGrade, isNull);
    });

    test('Independent all the way to Grade 7 is reported as above range', () {
      final s = pre(6, 8); // starts at Grade 4
      for (final g in [4, 5, 6, 7]) {
        expect(s.nextGrade, g);
        s.record(result(g, ReadingLevel.independent));
      }
      expect(s.isComplete, isTrue);
      expect(s.outcome.aboveRange, isTrue);
      expect(s.outcome.frustrationGrade, isNull);
    });

    test('rejects a passage for the wrong grade', () {
      final s = pre(5, 10);
      expect(
        () => s.record(result(5, ReadingLevel.independent)),
        throwsStateError,
      );
    });

    test('cannot record after Stage 2 is complete', () {
      final s = pre(3, 0);
      s.record(result(2, ReadingLevel.frustration));
      expect(
        () => s.record(result(2, ReadingLevel.frustration)),
        throwsStateError,
      );
    });
  });

  test('session survives a JSON round trip', () {
    final s = pre(6, 8);
    s.record(result(4, ReadingLevel.instructional));
    final copy = PhilIriSession.fromJson(s.toJson());
    expect(copy.nextGrade, 5);
    expect(copy.history.single.level, ReadingLevel.instructional);
    expect(copy.startGrade, 4);
    expect(copy.setLetter, 'A');
  });
}
