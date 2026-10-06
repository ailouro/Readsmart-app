import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Builds a class-wide reading performance report (PDF, landscape).
///
/// Input is one entry per enrolled student:
///   {
///     'name':       String,
///     'class_name': String,
///     'pre':        Map  (the `totals['pre_test']`  from /progress-detail),
///     'post':       Map  (the `totals['post_test']` from /progress-detail),
///   }
/// plus the teacher's raw mispronunciation logs (word, student_id,
/// total_attempts) for the "words to practice" section.
///
/// Text is kept to plain Latin characters (no emoji, arrows or special
/// symbols) because the built-in PDF fonts can't draw them.
class ClassReportPdf {
  static const PdfColor _ink = PdfColors.grey900;
  static const PdfColor _muted = PdfColors.grey600;
  static const PdfColor _line = PdfColors.grey300;

  static const _levelRank = {
    'frustration': 0,
    'instructional': 1,
    'independent': 2,
  };

  static double? _d(dynamic v) =>
      v is num ? v.toDouble() : double.tryParse('${v ?? ''}');
  static int _i(dynamic v) =>
      v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;
  static String _fmt(double v) =>
      v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
  static String _pct(double? v) => v == null ? '-' : '${_fmt(v)}%';
  static String _signed(double d) => d >= 0 ? '+${_fmt(d)}%' : '${_fmt(d)}%';
  static String _signedInt(int d) => d > 0 ? '+$d' : '$d';

  static Map<String, dynamic> _map(dynamic v) =>
      v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

  static bool _has(Map<String, dynamic> t) => _i(t['stories']) > 0;

  static String _levelKey(Map<String, dynamic> t) {
    if (!_has(t)) return '';
    final s = '${t['level'] ?? ''}'.toLowerCase();
    return _levelRank.containsKey(s) ? s : '';
  }

  static String _levelLabel(String key) {
    switch (key) {
      case 'independent':
        return 'Independent';
      case 'instructional':
        return 'Instructional';
      case 'frustration':
        return 'Frustration';
      default:
        return '-';
    }
  }

  static PdfColor _levelColor(String key) {
    switch (key) {
      case 'independent':
        return PdfColors.green700;
      case 'instructional':
        return PdfColors.orange700;
      case 'frustration':
        return PdfColors.red700;
      default:
        return _muted;
    }
  }

  static PdfColor? _changeColor(double? d) =>
      d == null ? null : (d < 0 ? PdfColors.red700 : PdfColors.green700);

  // ---- Small building blocks -------------------------------------------------
  static pw.Widget _cell(
    String text, {
    bool bold = false,
    PdfColor? color,
    double size = 10,
    pw.TextAlign align = pw.TextAlign.left,
  }) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 4),
    child: pw.Text(
      text,
      textAlign: align,
      style: pw.TextStyle(
        fontSize: size,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        color: color ?? _ink,
      ),
    ),
  );

  static pw.Widget _head(String text, {double size = 10}) =>
      _cell(text, bold: true, color: _muted, size: size);

  static pw.Widget _table(
    List<pw.TableRow> rows,
    Map<int, pw.TableColumnWidth> widths,
  ) => pw.Table(
    columnWidths: widths,
    border: pw.TableBorder(
      horizontalInside: pw.BorderSide(color: _line, width: 0.5),
      bottom: pw.BorderSide(color: _line, width: 0.5),
    ),
    children: rows,
  );

  static pw.Widget _section(String title, [String? note]) => pw.Padding(
    padding: const pw.EdgeInsets.only(top: 20, bottom: 6),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 13,
            fontWeight: pw.FontWeight.bold,
            color: _ink,
          ),
        ),
        if (note != null)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 2),
            child: pw.Text(
              note,
              style: const pw.TextStyle(fontSize: 9, color: _muted),
            ),
          ),
      ],
    ),
  );

  // ---- Class-wide numbers ----------------------------------------------------
  /// Pooled totals for one test across every student who has data for it
  /// (total correct words / total words, total correct answers / total
  /// questions) so it matches how each student's own totals are computed.
  static Map<String, dynamic> _classTotals(List<Map<String, dynamic>> tots) {
    final withData = tots.where(_has).toList();
    int stories = 0, words = 0, correct = 0, quizC = 0, quizQ = 0;
    final wordPcts = <double>[];
    final compPcts = <double>[];
    for (final t in withData) {
      stories += _i(t['stories']);
      words += _i(t['total_words']);
      correct += _i(t['correct_words']);
      quizC += _i(t['quiz_correct']);
      quizQ += _i(t['quiz_questions']);
      final w = _d(t['word_pct']);
      final c = _d(t['comp_pct']);
      if (w != null) wordPcts.add(w);
      if (c != null) compPcts.add(c);
    }
    double? avg(List<double> l) =>
        l.isEmpty ? null : l.reduce((a, b) => a + b) / l.length;

    return {
      'students': withData.length,
      'stories': stories,
      'word_pct': withData.isEmpty
          ? null
          : (words > 0 ? correct / words * 100 : avg(wordPcts)),
      'comp_pct': withData.isEmpty
          ? null
          : (quizQ > 0 ? quizC / quizQ * 100 : avg(compPcts)),
    };
  }

  static int _countLevel(List<Map<String, dynamic>> tots, String key) =>
      tots.where((t) => _levelKey(t) == key).length;

  // ---- Section 1: class summary ----------------------------------------------
  static pw.Widget _summary(
    List<Map<String, dynamic>> pre,
    List<Map<String, dynamic>> post,
    int enrolled,
  ) {
    final a = _classTotals(pre);
    final b = _classTotals(post);

    pw.TableRow row(
      String label,
      String x,
      String y, {
      String change = '',
      PdfColor? changeColor,
    }) => pw.TableRow(
      children: [
        _cell(label, color: _muted),
        _cell(x, bold: true),
        _cell(y, bold: true),
        _cell(change, bold: true, color: changeColor),
      ],
    );

    pw.TableRow pctRow(String label, String key) {
      final x = a[key] as double?;
      final y = b[key] as double?;
      final d = (x != null && y != null) ? y - x : null;
      return row(
        label,
        _pct(x),
        _pct(y),
        change: d == null ? '' : _signed(d),
        changeColor: _changeColor(d),
      );
    }

    pw.TableRow levelRow(String label, String key) {
      final x = _countLevel(pre, key);
      final y = _countLevel(post, key);
      return row(label, '$x', '$y', change: _signedInt(y - x));
    }

    return _table(
      [
        pw.TableRow(
          repeat: true,
          children: [
            _head(''),
            _head('Pre-test'),
            _head('Post-test'),
            _head('Change'),
          ],
        ),
        row(
          'Students who finished the test',
          '${a['students']} of $enrolled',
          '${b['students']} of $enrolled',
        ),
        row('Stories finished', '${a['stories']}', '${b['stories']}'),
        pctRow('Word reading (class total)', 'word_pct'),
        pctRow('Comprehension (class total)', 'comp_pct'),
        levelRow('Students at Independent', 'independent'),
        levelRow('Students at Instructional', 'instructional'),
        levelRow('Students at Frustration', 'frustration'),
      ],
      {
        0: const pw.FlexColumnWidth(3),
        1: const pw.FlexColumnWidth(1.4),
        2: const pw.FlexColumnWidth(1.4),
        3: const pw.FlexColumnWidth(1.2),
      },
    );
  }

  // ---- Section 2: every enrolled student -------------------------------------
  static pw.Widget _students(List<Map<String, dynamic>> students) {
    // Students who need the most support first (by post-test level), then
    // students without a post-test yet; ties by name.
    int priority(Map<String, dynamic> s) {
      final k = _levelKey(_map(s['post']));
      return k.isEmpty ? 3 : _levelRank[k]!;
    }

    final sorted = [...students]
      ..sort((x, y) {
        final p = priority(x).compareTo(priority(y));
        if (p != 0) return p;
        return '${x['name']}'.toLowerCase().compareTo(
          '${y['name']}'.toLowerCase(),
        );
      });

    const double fs = 9;
    final rows = <pw.TableRow>[
      pw.TableRow(
        repeat: true,
        children: [
          _head('#', size: fs),
          _head('Student', size: fs),
          _head('Class', size: fs),
          _head('Pre word', size: fs),
          _head('Pre comp.', size: fs),
          _head('Pre level', size: fs),
          _head('Post word', size: fs),
          _head('Post comp.', size: fs),
          _head('Post level', size: fs),
          _head('Word change', size: fs),
          _head('Comp. change', size: fs),
        ],
      ),
    ];

    for (int i = 0; i < sorted.length; i++) {
      final s = sorted[i];
      final pre = _map(s['pre']);
      final post = _map(s['post']);
      final hasPre = _has(pre);
      final hasPost = _has(post);
      final preLevel = _levelKey(pre);
      final postLevel = _levelKey(post);

      double? change(String key) {
        if (!hasPre || !hasPost) return null;
        final x = _d(pre[key]);
        final y = _d(post[key]);
        return (x == null || y == null) ? null : y - x;
      }

      final wc = change('word_pct');
      final cc = change('comp_pct');

      rows.add(
        pw.TableRow(
          children: [
            _cell('${i + 1}', color: _muted, size: fs),
            _cell('${s['name']}', bold: true, size: fs),
            _cell('${s['class_name']}', size: fs),
            _cell(hasPre ? _pct(_d(pre['word_pct'])) : '-', size: fs),
            _cell(hasPre ? _pct(_d(pre['comp_pct'])) : '-', size: fs),
            _cell(
              _levelLabel(preLevel),
              bold: true,
              color: _levelColor(preLevel),
              size: fs,
            ),
            _cell(hasPost ? _pct(_d(post['word_pct'])) : '-', size: fs),
            _cell(hasPost ? _pct(_d(post['comp_pct'])) : '-', size: fs),
            _cell(
              hasPost ? _levelLabel(postLevel) : 'Not yet',
              bold: true,
              color: hasPost ? _levelColor(postLevel) : _muted,
              size: fs,
            ),
            _cell(
              wc == null ? '-' : _signed(wc),
              bold: true,
              color: _changeColor(wc),
              size: fs,
            ),
            _cell(
              cc == null ? '-' : _signed(cc),
              bold: true,
              color: _changeColor(cc),
              size: fs,
            ),
          ],
        ),
      );
    }

    return _table(rows, {
      0: const pw.FixedColumnWidth(20),
      1: const pw.FlexColumnWidth(3),
      2: const pw.FlexColumnWidth(2),
      3: const pw.FlexColumnWidth(1),
      4: const pw.FlexColumnWidth(1),
      5: const pw.FlexColumnWidth(1.5),
      6: const pw.FlexColumnWidth(1),
      7: const pw.FlexColumnWidth(1),
      8: const pw.FlexColumnWidth(1.5),
      9: const pw.FlexColumnWidth(1.1),
      10: const pw.FlexColumnWidth(1.1),
    });
  }

  // ---- Section 3: words the class struggles with -----------------------------
  static pw.Widget? _words(List<dynamic> logs) {
    final attempts = <String, int>{};
    final who = <String, Set<String>>{};
    for (final m in logs) {
      if (m is! Map) continue;
      final w = '${m['word'] ?? ''}'.trim().toLowerCase();
      if (w.isEmpty) continue;
      final n = _i(m['total_attempts']);
      attempts[w] = (attempts[w] ?? 0) + (n > 0 ? n : 1);
      (who[w] ??= <String>{}).add('${m['student_id']}');
    }
    if (attempts.isEmpty) return null;

    final top = attempts.keys.toList()
      ..sort((a, b) {
        final byStudents = who[b]!.length.compareTo(who[a]!.length);
        if (byStudents != 0) return byStudents;
        return attempts[b]!.compareTo(attempts[a]!);
      });

    return _table(
      [
        pw.TableRow(
          repeat: true,
          children: [
            _head('Word'),
            _head('Students who missed it'),
            _head('Times missed'),
          ],
        ),
        for (final w in top.take(10))
          pw.TableRow(
            children: [
              _cell(w, bold: true),
              _cell('${who[w]!.length}'),
              _cell('${attempts[w]}'),
            ],
          ),
      ],
      {
        0: const pw.FlexColumnWidth(3),
        1: const pw.FlexColumnWidth(2),
        2: const pw.FlexColumnWidth(2),
      },
    );
  }

  // ---- Public entry point ----------------------------------------------------
  static Future<Uint8List> build({
    required List<Map<String, dynamic>> students,
    required List<dynamic> mispronunciations,
  }) async {
    final pre = students.map((s) => _map(s['pre'])).toList();
    final post = students.map((s) => _map(s['post'])).toList();

    final classNames =
        students
            .map((s) => '${s['class_name'] ?? ''}'.trim())
            .where((n) => n.isNotEmpty && n != 'null')
            .toSet()
            .toList()
          ..sort();

    final now = DateTime.now();
    final date =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final words = _words(mispronunciations);

    final doc = pw.Document(title: 'Class reading report');
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(32),
        footer: (ctx) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: _muted),
          ),
        ),
        build: (ctx) => [
          pw.Text(
            'Class reading performance report',
            style: pw.TextStyle(
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
              color: _ink,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            classNames.isEmpty ? 'All classes' : classNames.join(', '),
            style: pw.TextStyle(
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
              color: _ink,
            ),
          ),
          pw.Text(
            'Enrolled students: ${students.length}   |   Generated $date',
            style: const pw.TextStyle(fontSize: 9, color: _muted),
          ),

          _section(
            'Class summary',
            'Class totals add up every student\'s correct words and quiz answers (not an average of percentages). Level counts are per student.',
          ),
          _summary(pre, post, students.length),

          _section(
            'Every enrolled student',
            'Students who need the most support are listed first. "Change" is post-test minus pre-test.',
          ),
          _students(students),

          if (words != null) ...[
            _section(
              'Words to practice as a class',
              'Most commonly mispronounced words across all students.',
            ),
            words,
          ],

          pw.SizedBox(height: 22),
          pw.Text(
            'How levels are decided (Phil-IRI)',
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: _muted,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            'Word reading: Independent 97% and up, Instructional 90-96%, Frustration below 90%. '
            'Comprehension: Independent 80% and up, Instructional 59-79%, Frustration below 59%. '
            'The overall level is the lower of the two.',
            style: const pw.TextStyle(fontSize: 9, color: _muted),
          ),
        ],
      ),
    );

    return doc.save();
  }
}
