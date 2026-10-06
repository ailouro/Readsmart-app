import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Builds a one-student reading performance report (PDF).
///
/// Uses only the data StudentProgressScreen already loads:
///  - records:  GET /api/student/{id}/progress-detail  -> data
///  - totals:   GET /api/student/{id}/progress-detail  -> totals
///  - words:    mispronounced words as (word, times missed), most missed first
///
/// Text is kept to plain Latin characters (no emoji, arrows or special
/// symbols) because the built-in PDF fonts can't draw them.
class StudentReportPdf {
  static const PdfColor _ink = PdfColors.grey900;
  static const PdfColor _muted = PdfColors.grey600;
  static const PdfColor _line = PdfColors.grey300;

  static double? _d(dynamic v) =>
      v is num ? v.toDouble() : double.tryParse('${v ?? ''}');
  static int _i(dynamic v) =>
      v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;
  static String _fmt(double v) =>
      v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
  static String _pct(dynamic v) {
    final d = _d(v);
    return d == null ? '-' : '${_fmt(d)}%';
  }

  static String _signed(double d) => d >= 0 ? '+${_fmt(d)}%' : '${_fmt(d)}%';

  static String _level(String l) {
    final s = l.toLowerCase();
    if (s.contains('independent')) return 'Independent';
    if (s.contains('instructional')) return 'Instructional';
    if (s.contains('frustration')) return 'Frustration';
    return '-';
  }

  static PdfColor _levelColor(String l) {
    final s = l.toLowerCase();
    if (s.contains('independent')) return PdfColors.green700;
    if (s.contains('instructional')) return PdfColors.orange700;
    if (s.contains('frustration')) return PdfColors.red700;
    return _muted;
  }

  static pw.Widget _cell(
    String text, {
    bool bold = false,
    PdfColor? color,
    pw.TextAlign align = pw.TextAlign.left,
  }) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
    child: pw.Text(
      text,
      textAlign: align,
      style: pw.TextStyle(
        fontSize: 10,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        color: color ?? _ink,
      ),
    ),
  );

  static pw.Widget _head(
    String text, {
    pw.TextAlign align = pw.TextAlign.left,
  }) => _cell(text, bold: true, color: _muted, align: align);

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

  // ---- Pre-test vs post-test summary ---------------------------------------
  static pw.Widget _summary(
    Map<String, dynamic> pre,
    Map<String, dynamic> post,
  ) {
    final bool hasPre = _i(pre['stories']) > 0;
    final bool hasPost = _i(post['stories']) > 0;

    String of(Map<String, dynamic> t, String a, String b) =>
        _i(t[b]) > 0 ? '${_i(t[a])} of ${_i(t[b])}' : '-';

    String change(String key) {
      if (!hasPre || !hasPost) return '';
      final a = _d(pre[key]);
      final b = _d(post[key]);
      if (a == null || b == null) return '';
      return _signed(b - a);
    }

    PdfColor? changeColor(String key) {
      final c = change(key);
      if (c.isEmpty) return null;
      return c.startsWith('-') ? PdfColors.red700 : PdfColors.green700;
    }

    pw.TableRow row(
      String label,
      String a,
      String b, {
      String c = '',
      PdfColor? cColor,
      PdfColor? aColor,
      PdfColor? bColor,
    }) => pw.TableRow(
      children: [
        _cell(label, color: _muted),
        _cell(a, bold: true, color: aColor),
        _cell(b, bold: true, color: bColor),
        _cell(c, bold: true, color: cColor),
      ],
    );

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
          'Stories finished',
          hasPre ? '${_i(pre['stories'])}' : '-',
          hasPost ? '${_i(post['stories'])}' : '-',
        ),
        row(
          'Words read correctly',
          hasPre ? of(pre, 'correct_words', 'total_words') : '-',
          hasPost ? of(post, 'correct_words', 'total_words') : '-',
        ),
        row(
          'Word reading',
          hasPre ? _pct(pre['word_pct']) : '-',
          hasPost ? _pct(post['word_pct']) : '-',
          c: change('word_pct'),
          cColor: changeColor('word_pct'),
        ),
        row(
          'Quiz answers correct',
          hasPre ? of(pre, 'quiz_correct', 'quiz_questions') : '-',
          hasPost ? of(post, 'quiz_correct', 'quiz_questions') : '-',
        ),
        row(
          'Comprehension',
          hasPre ? _pct(pre['comp_pct']) : '-',
          hasPost ? _pct(post['comp_pct']) : '-',
          c: change('comp_pct'),
          cColor: changeColor('comp_pct'),
        ),
        row(
          'Reading level',
          hasPre ? _level('${pre['level'] ?? ''}') : '-',
          hasPost ? _level('${post['level'] ?? ''}') : '-',
          aColor: hasPre ? _levelColor('${pre['level'] ?? ''}') : null,
          bColor: hasPost ? _levelColor('${post['level'] ?? ''}') : null,
        ),
      ],
      {
        0: const pw.FlexColumnWidth(2.2),
        1: const pw.FlexColumnWidth(1.5),
        2: const pw.FlexColumnWidth(1.5),
        3: const pw.FlexColumnWidth(1.2),
      },
    );
  }

  // ---- Per-story table -----------------------------------------------------
  static pw.Widget _stories(List<dynamic> recs) {
    final rows = <pw.TableRow>[
      pw.TableRow(
        repeat: true,
        children: [
          _head('#'),
          _head('Story'),
          _head('Words correct'),
          _head('Word reading'),
          _head('Comprehension'),
          _head('WPM'),
          _head('Level'),
        ],
      ),
    ];
    for (int i = 0; i < recs.length; i++) {
      final r = recs[i];
      final int total = _i(r['total_words']);
      final int correct = _i(r['correct_words_count']);
      final int wpm = _i(r['wpm']);
      final String level = (r['reading_level'] ?? '').toString();
      rows.add(
        pw.TableRow(
          children: [
            _cell('${i + 1}', color: _muted),
            _cell(
              (r['story_title'] ?? 'Untitled story').toString(),
              bold: true,
            ),
            _cell(total > 0 ? '$correct / $total' : '-'),
            _cell(
              _pct(r['word_reading_score_pct'] ?? r['oral_fluency_accuracy']),
            ),
            _cell(_pct(r['comprehension_score_pct'])),
            _cell(wpm > 0 ? '$wpm' : '-'),
            _cell(_level(level), bold: true, color: _levelColor(level)),
          ],
        ),
      );
    }
    return _table(rows, {
      0: const pw.FixedColumnWidth(20),
      1: const pw.FlexColumnWidth(3),
      2: const pw.FlexColumnWidth(1.6),
      3: const pw.FlexColumnWidth(1.5),
      4: const pw.FlexColumnWidth(1.8),
      5: const pw.FixedColumnWidth(34),
      6: const pw.FlexColumnWidth(1.6),
    });
  }

  // ---- Public entry point --------------------------------------------------
  static Future<Uint8List> build({
    required String studentName,
    required List<dynamic> records,
    required Map<String, dynamic> totals,
    required List<MapEntry<String, int>> words,
  }) async {
    Map<String, dynamic> tot(String k) {
      final t = totals[k];
      return t is Map ? Map<String, dynamic>.from(t) : <String, dynamic>{};
    }

    String typeOf(dynamic r) => (r['test_type'] ?? '').toString();
    final pre = records.where((r) => typeOf(r) == 'pre_test').toList();
    final post = records.where((r) => typeOf(r) == 'post_test').toList();
    final other = records
        .where((r) => typeOf(r) != 'pre_test' && typeOf(r) != 'post_test')
        .toList();

    final now = DateTime.now();
    final date =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final doc = pw.Document(title: 'Reading report - $studentName');

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        footer: (ctx) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: _muted),
          ),
        ),
        build: (ctx) => [
          pw.Text(
            'Reading performance report',
            style: pw.TextStyle(
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
              color: _ink,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            studentName,
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: _ink,
            ),
          ),
          pw.Text(
            'Generated $date',
            style: const pw.TextStyle(fontSize: 9, color: _muted),
          ),

          _section(
            'Pre-test vs post-test',
            'Totals across all finished stories in each test (total correct words and answers, not an average of percentages).',
          ),
          _summary(tot('pre_test'), tot('post_test')),

          if (pre.isNotEmpty) ...[_section('Pre-test stories'), _stories(pre)],
          if (post.isNotEmpty) ...[
            _section('Post-test stories'),
            _stories(post),
          ],
          if (other.isNotEmpty) ...[_section('Other stories'), _stories(other)],

          if (words.isNotEmpty) ...[
            _section(
              'Words to practice',
              'Most frequently mispronounced words (times missed).',
            ),
            pw.Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                for (final w in words.take(12))
                  pw.Text(
                    '${w.key} (${w.value}x)',
                    style: const pw.TextStyle(fontSize: 10, color: _ink),
                  ),
              ],
            ),
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
