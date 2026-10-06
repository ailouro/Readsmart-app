import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';
import 'package:printing/printing.dart';
import 'student_report_pdf.dart';

class StudentProgressScreen extends StatefulWidget {
  final int studentId;
  final String baseUrl;
  final String studentName;

  // Teacher view: nagpapakita ng header (pangalan, klase, LRN, level, PDF)
  // sa taas ng page. Hindi ito lumalabas sa student mismo.
  final bool teacherView;

  // embedded = true kapag nasa loob ng master-detail ng teacher (malapad na
  // screen), kaya walang sariling Scaffold/AppBar.
  final bool embedded;
  final String lrn;
  final String className;

  const StudentProgressScreen({
    super.key,
    required this.studentId,
    required this.baseUrl,
    required this.studentName,
    this.teacherView = false,
    this.embedded = false,
    this.lrn = '',
    this.className = '',
  });

  @override
  State<StudentProgressScreen> createState() => _StudentProgressScreenState();
}

class _StudentProgressScreenState extends State<StudentProgressScreen> {
  bool _isLoading = true;
  bool _showAllWords = false;
  List<dynamic> _records = [];
  String _testFilter = 'all'; // 'all' | 'pre_test' | 'post_test'

  // Mga record na tugma sa napiling Pre/Post filter. Dahil may sariling row na
  // ang pre-test at post-test ng parehong story, ito ang gamit sa lahat ng
  // bilang at listahan sa screen.
  List<dynamic> get _view => _testFilter == 'all'
      ? _records
      : _records
            .where((r) => (r['test_type'] ?? '').toString() == _testFilter)
            .toList();

  bool get _hasTestTypes =>
      _records.any((r) => (r['test_type'] ?? '').toString().isNotEmpty);

  List<dynamic> _mispronunciations = [];
  Map<String, dynamic> _totals = {};

  // Ilang words ang ipapakita bago mag-"Show all" (para hindi sobrang haba
  // ng page sa mobile).
  static const int _wordsPreview = 8;

  static const Color independentColor = Color(0xFF4CAF50);
  static const Color instructionalColor = Color(0xFFFFA726);
  static const Color frustrationColor = Color(0xFFE53935);
  static const Color maroon = Color(0xFF9B0505);
  static const Color paperColor = Color(0xFFFFF6E4);
  static const Color inkText = Color(0xFF201A1A);
  static const Color inkSubtext = Color(0xFF6B5D5D);
  static const Color cardFill = Colors.white;
  static const Color cardBorder = Color(0xFF201A1A);

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  // silent = true kapag pull-to-refresh, para hindi mawala ang page at
  // mapalitan ng spinner habang nagre-reload.
  Future<void> _fetchData({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        http.get(
          Uri.parse(
            "${widget.baseUrl}/api/student/${widget.studentId}/progress-detail",
          ),
          headers: const {"ngrok-skip-browser-warning": "69420"},
        ),
        http.get(
          Uri.parse(
            "${widget.baseUrl}/api/students/${widget.studentId}/mispronunciations",
          ),
          headers: const {"ngrok-skip-browser-warning": "69420"},
        ),
      ]);
      if (results[0].statusCode == 200) {
        final body = jsonDecode(results[0].body);
        _records = body['data'] ?? [];
        final t = body['totals'];
        _totals = t is Map ? Map<String, dynamic>.from(t) : {};
      }
      if (results[1].statusCode == 200) {
        _mispronunciations = jsonDecode(results[1].body)['data'] ?? [];
      }
    } catch (e) {
      debugPrint("Error fetching progress: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ==========================================
  // PDF REPORT
  // ==========================================
  // Gumagawa ng PDF report ng estudyanteng ito (lahat ng natapos na stories,
  // hindi lang ang napiling Pre/Post filter) at binubuksan ang share/save
  // sheet (download sa web).
  Future<void> _exportReport() async {
    final messenger = ScaffoldMessenger.of(context);
    if (_records.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Wala pang natapos na story para sa report.'),
        ),
      );
      return;
    }
    try {
      final bytes = await StudentReportPdf.build(
        studentName: widget.studentName,
        records: _records,
        totals: _totals,
        words: _sortedWords(),
      );
      final safeName = widget.studentName.trim().replaceAll(
        RegExp(r'[^A-Za-z0-9]+'),
        '_',
      );
      await Printing.sharePdf(
        bytes: bytes,
        filename:
            'reading_report_${safeName.isEmpty ? 'student' : safeName}.pdf',
      );
    } catch (e) {
      debugPrint('Error creating report: $e');
      messenger.showSnackBar(
        const SnackBar(content: Text('Hindi nagawa ang report. Subukan ulit.')),
      );
    }
  }

  // ==========================================
  // HELPERS
  // ==========================================
  Color _levelColor(String level) {
    if (level.toLowerCase().contains('independent')) return independentColor;
    if (level.toLowerCase().contains('instructional')) {
      return instructionalColor;
    }
    return frustrationColor;
  }

  double _score(dynamic record) {
    final v = record['oral_fluency_accuracy'];
    if (v is num) return v.toDouble();
    return double.tryParse('$v') ?? 0;
  }

  int _countLevel(String key) => _view
      .where(
        (r) =>
            (r['reading_level'] ?? '').toString().toLowerCase().contains(key),
      )
      .length;

  List<MapEntry<String, int>> _sortedWords() {
    final Map<String, int> wordCounts = {};
    for (var m in _mispronunciations) {
      final String w = (m['word'] ?? '').toString();
      wordCounts[w] = (wordCounts[w] ?? 0) + 1;
    }
    return wordCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
  }

  String _fmt(double v) =>
      v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  // ==========================================
  // REUSABLE PIECES
  // ==========================================
  Widget _card({required Widget child}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: cardFill,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: child,
  );

  Widget _sectionHeader(String title, {String? subtitle}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(
          color: inkText,
          fontWeight: FontWeight.w900,
          fontSize: 17,
        ),
      ),
      if (subtitle != null) ...[
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: const TextStyle(
            color: inkSubtext,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ],
  );

  Widget _emptyText(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 20),
    child: Center(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: inkSubtext,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
  );

  Widget _dot(Color color, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 5),
      Text(
        label,
        style: const TextStyle(
          color: inkSubtext,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    ],
  );

  // Iisang legend na lang (dati dalawa na pareho lang ang ibig sabihin).
  Widget _buildLegend() => Wrap(
    spacing: 14,
    runSpacing: 6,
    children: [
      _dot(independentColor, "Independent Explorer"),
      _dot(instructionalColor, "Growing Reader"),
      _dot(frustrationColor, "Needs Practice"),
    ],
  );

  // Pre/Post filter. Lalabas lang kung may test_type ang data galing sa server.
  Widget _buildTestFilter() {
    if (!_hasTestTypes) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: SegmentedButton<String>(
        segments: const [
          ButtonSegment(value: 'all', label: Text('Lahat')),
          ButtonSegment(value: 'pre_test', label: Text('Pre-Test')),
          ButtonSegment(value: 'post_test', label: Text('Post-Test')),
        ],
        selected: {_testFilter},
        showSelectedIcon: false,
        onSelectionChanged: (s) => setState(() => _testFilter = s.first),
      ),
    );
  }

  // ==========================================
  // 1. PRE-TEST vs POST-TEST — kabuuang total ng lahat ng stories
  // ==========================================
  Map<String, dynamic> _tot(String key) {
    final t = _totals[key];
    return t is Map ? Map<String, dynamic>.from(t) : <String, dynamic>{};
  }

  int _i(dynamic v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;

  double? _d(dynamic v) =>
      v is num ? v.toDouble() : double.tryParse('${v ?? ''}');

  String _levelLabel(String level) {
    final l = level.toLowerCase();
    if (l.contains('independent')) return 'Independent Explorer';
    if (l.contains('instructional')) return 'Growing Reader';
    if (l.contains('frustration')) return 'Needs Practice';
    return '—';
  }

  String _dur(int s) => s <= 0 ? '—' : '${s ~/ 60}m ${s % 60}s';

  Widget _levelChip(String level) {
    final Color c = _levelColor(level);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _levelLabel(level),
        style: TextStyle(color: c, fontWeight: FontWeight.w900, fontSize: 11),
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          k,
          style: const TextStyle(
            color: inkSubtext,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          v,
          style: const TextStyle(
            color: inkText,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );

  Widget _bigStat(String label, String value, String? sub) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          color: inkSubtext,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
      Text(
        value,
        style: const TextStyle(
          color: inkText,
          fontSize: 24,
          fontWeight: FontWeight.w900,
        ),
      ),
      if (sub != null)
        Text(sub, style: const TextStyle(color: inkSubtext, fontSize: 11)),
    ],
  );

  Widget _totalBlock(String title, Map<String, dynamic> t, Color accent) {
    final bool hasData = _i(t['stories']) > 0;
    final int stories = _i(t['stories']);
    final int words = _i(t['total_words']);
    final int quizQ = _i(t['quiz_questions']);
    final double wr = _d(t['word_pct']) ?? 0;
    final double comp = _d(t['comp_pct']) ?? 0;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: accent,
                fontWeight: FontWeight.w900,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 2),
            if (!hasData)
              const Text(
                'Wala pang natapos na story.',
                style: TextStyle(color: inkSubtext, fontSize: 12),
              )
            else ...[
              Text(
                '$stories ${stories == 1 ? 'story' : 'stories'} natapos',
                style: const TextStyle(color: inkSubtext, fontSize: 12),
              ),
              const SizedBox(height: 12),
              _bigStat(
                'Word Reading',
                '${_fmt(wr)}%',
                words > 0
                    ? '${_i(t['correct_words'])} sa $words salita tama'
                    : null,
              ),
              const SizedBox(height: 10),
              _bigStat(
                'Comprehension',
                '${_fmt(comp)}%',
                quizQ > 0
                    ? '${_i(t['quiz_correct'])} sa $quizQ tanong tama'
                    : null,
              ),
              const SizedBox(height: 12),
              _levelChip('${t['level'] ?? ''}'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCompareSection() {
    final pre = _tot('pre_test');
    final post = _tot('post_test');
    if (_i(pre['stories']) == 0 && _i(post['stories']) == 0) {
      return const SizedBox.shrink();
    }

    const Color preColor = Color(0xFF5C6BC0);
    final bool both = _i(pre['stories']) > 0 && _i(post['stories']) > 0;

    double v(Map<String, dynamic> m, String k) => _d(m[k]) ?? 0;
    BarChartRodData rod(double y, Color c) => BarChartRodData(
      toY: y,
      color: c,
      width: 26,
      borderRadius: BorderRadius.circular(4),
    );

    final chart = SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          minY: 0,
          maxY: 100,
          alignment: BarChartAlignment.spaceAround,
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 20,
          ),
          barGroups: [
            BarChartGroupData(
              x: 0,
              barsSpace: 6,
              barRods: [
                rod(v(pre, 'word_pct'), preColor),
                rod(v(post, 'word_pct'), maroon),
              ],
            ),
            BarChartGroupData(
              x: 1,
              barsSpace: 6,
              barRods: [
                rod(v(pre, 'comp_pct'), preColor),
                rod(v(post, 'comp_pct'), maroon),
              ],
            ),
          ],
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 20,
                reservedSize: 34,
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) => Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    value.toInt() == 0 ? 'Word Reading %' : 'Comprehension %',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    String? gainText;
    if (both) {
      String sign(double d) => d >= 0 ? '+${_fmt(d)}' : _fmt(d);
      gainText =
          'Pagbabago (Post − Pre): Word Reading '
          '${sign(v(post, 'word_pct') - v(pre, 'word_pct'))}% • '
          'Comprehension ${sign(v(post, 'comp_pct') - v(pre, 'comp_pct'))}%';
    }

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            'Pre-Test vs Post-Test 📊',
            subtitle:
                'Kabuuan ng lahat ng natapos na stories sa bawat test '
                '(total ng salita at sagot, hindi average ng %).',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 14,
            children: [_dot(preColor, 'Pre-Test'), _dot(maroon, 'Post-Test')],
          ),
          const SizedBox(height: 12),
          chart,
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _totalBlock('Pre-Test', pre, preColor),
              const SizedBox(width: 10),
              _totalBlock('Post-Test', post, maroon),
            ],
          ),
          if (gainText != null) ...[
            const SizedBox(height: 12),
            Text(
              gainText,
              style: const TextStyle(
                color: inkText,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ==========================================
  // 2. BAWAT STORY — chart + computation breakdown
  // ==========================================
  Widget _storyChart(List<dynamic> recs) {
    return LayoutBuilder(
      builder: (context, c) {
        final double w = recs.length * 52.0 > c.maxWidth
            ? recs.length * 52.0
            : c.maxWidth;
        final Color line = inkText.withValues(alpha: 0.5);
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: w,
            height: 190,
            child: BarChart(
              BarChartData(
                minY: 0,
                maxY: 100,
                alignment: BarChartAlignment.spaceAround,
                borderData: FlBorderData(show: false),
                gridData: const FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 20,
                ),
                extraLinesData: ExtraLinesData(
                  horizontalLines: [
                    HorizontalLine(
                      y: 90,
                      color: line,
                      strokeWidth: 1,
                      dashArray: [5, 4],
                    ),
                    HorizontalLine(
                      y: 97,
                      color: line,
                      strokeWidth: 1,
                      dashArray: [5, 4],
                    ),
                  ],
                ),
                barGroups: [
                  for (int i = 0; i < recs.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: _score(recs[i]).clamp(0.0, 100.0),
                          width: 20,
                          color: _levelColor(
                            (recs[i]['reading_level'] ?? '').toString(),
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    ),
                ],
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 20,
                      reservedSize: 34,
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) => Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          '#${value.toInt() + 1}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _storyDetail(int n, dynamic r) {
    final String title = (r['story_title'] ?? 'Untitled story').toString();
    final String level = (r['reading_level'] ?? '').toString();
    final int total = _i(r['total_words']);
    final int miscues = _i(r['miscues_count']);
    final int correct = _i(r['correct_words_count']);
    final double wr = _score(r);
    final int qc = _i(r['quiz_score']);
    final int qt = _i(r['total_questions']);
    final double comp = _d(r['comprehension_score_pct']) ?? 0;
    final int wpm = _i(r['wpm']);
    final int secs = _i(r['time_on_task']);
    final Color lc = _levelColor(level);

    const TextStyle detail = TextStyle(color: inkSubtext, fontSize: 12.5);

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        key: PageStorageKey('story_${r['id']}'),
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(left: 28, bottom: 10),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        shape: const Border(),
        collapsedShape: const Border(),
        iconColor: inkSubtext,
        collapsedIconColor: inkSubtext,
        title: Row(
          children: [
            SizedBox(
              width: 28,
              child: Text(
                '#$n',
                style: const TextStyle(
                  color: inkSubtext,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
            ),
            Expanded(
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: inkText,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(left: 28, top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _dot(lc, _levelLabel(level)),
              const SizedBox(height: 3),
              Text(
                'Word Reading ${_fmt(wr)}%  •  Comprehension ${_fmt(comp)}%  •  ${wpm > 0 ? '$wpm WPM' : '— WPM'}',
                style: const TextStyle(
                  color: inkText,
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        children: [
          Text(
            total > 0
                ? 'Tamang salita: $correct sa $total  ($miscues miscues)'
                : 'Walang naka-save na bilang ng salita',
            style: detail,
          ),
          if (qt > 0) ...[
            const SizedBox(height: 4),
            Text('Quiz: $qc sa $qt tama', style: detail),
          ],
          const SizedBox(height: 4),
          Text('Oras ng pagbasa: ${_dur(secs)}', style: detail),
        ],
      ),
    );
  }

  Widget _buildTestGroup(String type, List<dynamic> recs) {
    final String name = type == 'pre_test'
        ? 'Pre-Test'
        : type == 'post_test'
        ? 'Post-Test'
        : 'Mga Kwento';
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            '$name — Bawat Story 🎯',
            subtitle:
                'Isang bar kada story (guhit = 90% at 97% na cutoff). I-tap ang story para makita ang detalye.',
          ),
          const SizedBox(height: 12),
          _buildLegend(),
          const SizedBox(height: 14),
          _storyChart(recs),
          const SizedBox(height: 8),
          for (int i = 0; i < recs.length; i++) ...[
            if (i > 0)
              Divider(height: 1, color: Colors.black.withValues(alpha: 0.07)),
            _storyDetail(i + 1, recs[i]),
          ],
        ],
      ),
    );
  }

  Widget _buildScoresSection() {
    if (_view.isEmpty) {
      return _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader('My Story Accuracy Scores 🎯'),
            _emptyText(
              'No missions completed yet.\nRead a story to earn stars!',
            ),
          ],
        ),
      );
    }
    String typeOf(dynamic r) => (r['test_type'] ?? '').toString();
    final groups = <MapEntry<String, List<dynamic>>>[];
    for (final t in ['pre_test', 'post_test']) {
      final l = _view.where((r) => typeOf(r) == t).toList();
      if (l.isNotEmpty) groups.add(MapEntry(t, l));
    }
    final other = _view
        .where((r) => typeOf(r) != 'pre_test' && typeOf(r) != 'post_test')
        .toList();
    if (other.isNotEmpty) groups.add(MapEntry('', other));

    return Column(
      children: [
        for (int g = 0; g < groups.length; g++) ...[
          if (g > 0) const SizedBox(height: 18),
          _buildTestGroup(groups[g].key, groups[g].value),
        ],
      ],
    );
  }

  // ==========================================
  // 3. POWER (pie + badge)
  // ==========================================
  Widget _buildPieLegendCard(String label, int count, int total, Color color) {
    final String pct = total > 0
        ? "${((count / total) * 100).toStringAsFixed(0)}%"
        : "0%";
    return Expanded(
      child: Column(
        children: [
          Text(
            pct,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: inkSubtext,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  PieChartSectionData _pieSection(int value, Color color) =>
      PieChartSectionData(
        value: value.toDouble(),
        color: color,
        title: '$value',
        radius: 55,
        titleStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 15,
        ),
      );

  Widget _buildPowerSection() {
    if (_view.isEmpty) {
      return _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader("My Reading Power ⚡"),
            _emptyText("No missions completed yet."),
          ],
        ),
      );
    }

    final int indep = _countLevel('independent');
    final int instr = _countLevel('instructional');
    final int frust = _countLevel('frustration');
    final int total = _view.length;

    String best = 'N/A';
    Color bestColor = inkText;
    if (indep >= instr && indep >= frust && indep > 0) {
      best = 'Master Explorer 🌟';
      bestColor = independentColor;
    } else if (instr >= frust && instr > 0) {
      best = 'Growing Hero 📖';
      bestColor = instructionalColor;
    } else if (frust > 0) {
      best = 'Brave Learner 💪';
      bestColor = frustrationColor;
    }

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            "My Reading Power ⚡",
            subtitle:
                "Based on $total completed ${total == 1 ? 'mission' : 'missions'}",
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sections: [
                  if (indep > 0) _pieSection(indep, independentColor),
                  if (instr > 0) _pieSection(instr, instructionalColor),
                  if (frust > 0) _pieSection(frust, frustrationColor),
                ],
                centerSpaceRadius: 35,
                sectionsSpace: 3,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPieLegendCard(
                "🟢 Independent Explorer",
                indep,
                total,
                independentColor,
              ),
              _buildPieLegendCard(
                "🟡 Growing Reader",
                instr,
                total,
                instructionalColor,
              ),
              _buildPieLegendCard(
                "🔴 Needs Practice",
                frust,
                total,
                frustrationColor,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: paperColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                const Text(
                  "Current Power Badge",
                  style: TextStyle(
                    color: inkSubtext,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  best,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: bestColor,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 4. WORDS
  // ==========================================
  Widget _wordRow(MapEntry<String, int> e, int maxCount) {
    final Color barColor = e.value >= 3
        ? frustrationColor
        : e.value == 2
        ? instructionalColor
        : Colors.amber;
    final double barWidth = (e.value / maxCount).clamp(0.05, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  e.key,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: inkText,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: barColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "Missed ${e.value}x",
                  style: TextStyle(
                    color: barColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: barWidth,
              minHeight: 6,
              backgroundColor: Colors.black.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWordsSection() {
    final sorted = _sortedWords();

    if (sorted.isEmpty) {
      return _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader("Words to practice"),
            const SizedBox(height: 12),
            const Center(
              child: Icon(
                Icons.military_tech_rounded,
                color: independentColor,
                size: 56,
              ),
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text(
                "Perfect Pronunciation!\nNo words to practice right now! 🎉",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: inkText,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final bool canCollapse = sorted.length > _wordsPreview;
    final visible = (canCollapse && !_showAllWords)
        ? sorted.take(_wordsPreview).toList()
        : sorted;
    final int maxCount = sorted.first.value;

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            "Words to practice",
            subtitle: "${sorted.length} tricky words • most missed first",
          ),
          const SizedBox(height: 6),
          for (int i = 0; i < visible.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: Colors.black12),
            _wordRow(visible[i], maxCount),
          ],
          if (canCollapse)
            Center(
              child: TextButton(
                onPressed: () => setState(() => _showAllWords = !_showAllWords),
                child: Text(
                  _showAllWords
                      ? "Show fewer"
                      : "Show all ${sorted.length} words",
                  style: const TextStyle(
                    color: maroon,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ==========================================
  // PROGRESS OVER TIME — isang tuldok kada natapos na story
  // ==========================================
  String _trendMetric = 'word'; // 'word' | 'comp'
  static const Color _preColor = Color(0xFF5C6BC0);
  static const Color _practiceColor = Color(0xFF9E9E9E);

  DateTime? _when(dynamic r) =>
      DateTime.tryParse('${r['date_completed'] ?? ''}')?.toLocal();

  double? _trendValue(dynamic r) => _trendMetric == 'word'
      ? _d(r['oral_fluency_accuracy'])
      : _d(r['comprehension_score_pct']);

  Color _typeColor(String t) => t == 'pre_test'
      ? _preColor
      : t == 'post_test'
      ? maroon
      : _practiceColor;

  String _typeLabel(String t) => t == 'pre_test'
      ? 'Pre-Test'
      : t == 'post_test'
      ? 'Post-Test'
      : 'Practice';

  // Mga story na may halaga para sa napiling chart, nakaayos ayon sa petsa.
  List<dynamic> _trendRecords() {
    final list = _records.where((r) => _trendValue(r) != null).toList();
    if (list.isNotEmpty && list.every((r) => _when(r) != null)) {
      final indexed = list.asMap().entries.toList()
        ..sort((a, b) {
          final c = _when(a.value)!.compareTo(_when(b.value)!);
          return c != 0 ? c : a.key.compareTo(b.key);
        });
      return indexed.map((e) => e.value).toList();
    }
    return list;
  }

  Widget _trendChart(List<dynamic> recs) {
    final bool word = _trendMetric == 'word';
    // Phil-IRI cutoffs: word reading 90 / 97, comprehension 59 / 80.
    final List<double> cuts = word ? [90, 97] : [59, 80];
    final int n = recs.length;
    final List<double> values = [
      for (final r in recs) _trendValue(r)!.clamp(0.0, 100.0).toDouble(),
    ];
    final double lowest = values.reduce((a, b) => a < b ? a : b);
    final double minY = word
        ? ((lowest / 10).floor() * 10.0).clamp(0.0, 80.0).toDouble()
        : 0.0;
    final Set<int> ticks = {
      minY.round(),
      cuts[0].round(),
      cuts[1].round(),
      100,
    };
    final int xInterval = n > 6 ? (n / 6).ceil() : 1;

    HorizontalRangeAnnotation band(double lo, double hi, Color c) =>
        HorizontalRangeAnnotation(
          y1: lo < minY ? minY : lo,
          y2: hi,
          color: c.withValues(alpha: 0.18),
        );

    return LayoutBuilder(
      builder: (context, c) {
        final double w = n * 48.0 > c.maxWidth ? n * 48.0 : c.maxWidth;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: w,
            height: 220,
            child: Padding(
              padding: const EdgeInsets.only(top: 22, right: 12),
              child: LineChart(
                LineChartData(
                  minX: n == 1 ? -1 : 0,
                  maxX: n == 1 ? 1 : (n - 1).toDouble(),
                  minY: minY,
                  maxY: 100,
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  rangeAnnotations: RangeAnnotations(
                    horizontalRangeAnnotations: [
                      if (cuts[0] > minY) band(0, cuts[0], frustrationColor),
                      band(cuts[0], cuts[1], instructionalColor),
                      band(cuts[1], 100, independentColor),
                    ],
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 34,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          final int v = value.round();
                          if ((value - v).abs() > 0.01 || !ticks.contains(v)) {
                            return const SizedBox.shrink();
                          }
                          return Text(
                            '$v',
                            style: const TextStyle(
                              fontSize: 11,
                              color: inkSubtext,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 26,
                        interval: n == 1 ? 1 : xInterval.toDouble(),
                        getTitlesWidget: (value, meta) {
                          final int idx = value.round();
                          if ((value - idx).abs() > 0.01 ||
                              idx < 0 ||
                              idx >= n) {
                            return const SizedBox.shrink();
                          }
                          final dt = _when(recs[idx]);
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              dt == null
                                  ? '#${idx + 1}'
                                  : '${dt.month}/${dt.day}',
                              style: const TextStyle(
                                fontSize: 10,
                                color: inkSubtext,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (spots) => spots.map((s) {
                        final r = recs[s.spotIndex];
                        final String title =
                            (r['story_title'] ?? 'Untitled story').toString();
                        final String type = (r['test_type'] ?? '').toString();
                        return LineTooltipItem(
                          '$title\n${_typeLabel(type)}  •  ${_fmt(s.y)}%',
                          const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: [
                        for (int i = 0; i < n; i++)
                          FlSpot(i.toDouble(), values[i]),
                      ],
                      isCurved: false,
                      barWidth: 2,
                      color: inkText.withValues(alpha: 0.45),
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, pct, bar, idx) => _LabeledDot(
                          label: _fmt(values[idx]),
                          radius: 5.5,
                          color: _typeColor(
                            (recs[idx]['test_type'] ?? '').toString(),
                          ),
                          strokeWidth: 2,
                          strokeColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _changeStat(String label, double? v) {
    final String text = v == null
        ? '—'
        : (v >= 0 ? '+${_fmt(v)}%' : '${_fmt(v)}%');
    final Color color = v == null
        ? inkSubtext
        : (v < 0 ? frustrationColor : independentColor);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: inkSubtext,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _buildTrendCard() {
    final bool word = _trendMetric == 'word';
    final recs = _trendRecords();

    final toggle = SegmentedButton<String>(
      segments: const [
        ButtonSegment(value: 'word', label: Text('Word reading')),
        ButtonSegment(value: 'comp', label: Text('Comprehension')),
      ],
      selected: {_trendMetric},
      showSelectedIcon: false,
      onSelectionChanged: (s) => setState(() => _trendMetric = s.first),
    );

    if (recs.isEmpty) {
      return _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader('Progress over time'),
            const SizedBox(height: 10),
            toggle,
            _emptyText('No finished stories yet.'),
          ],
        ),
      );
    }

    final double first = _trendValue(recs.first)!;
    final double last = _trendValue(recs.last)!;
    final String lastLevel = '${recs.last['reading_level'] ?? ''}';

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            'Progress over time',
            subtitle:
                '${word ? 'Word reading' : 'Comprehension'} per story. '
                'Tap or hover a dot for details.',
          ),
          const SizedBox(height: 10),
          toggle,
          const SizedBox(height: 12),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              _dot(_preColor, 'Pre-Test'),
              _dot(maroon, 'Post-Test'),
              _dot(_practiceColor, 'Practice'),
            ],
          ),
          const SizedBox(height: 6),
          _buildLegend(),
          const SizedBox(height: 10),
          _trendChart(recs),
          const SizedBox(height: 14),
          Wrap(
            spacing: 28,
            runSpacing: 12,
            children: [
              _bigStat('First story', '${_fmt(first)}%', null),
              _bigStat('Latest story', '${_fmt(last)}%', null),
              _changeStat('Change', recs.length > 1 ? last - first : null),
              _bigStat('Stories finished', '${_records.length}', null),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text(
                'Current level  ',
                style: TextStyle(
                  color: inkSubtext,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              _levelChip(lastLevel),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TEACHER HEADER — pangalan, klase, LRN, level, PDF, at buod
  // ==========================================
  String _initialsOf(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  Widget _buildTeacherHeader() {
    final pre = _tot('pre_test');
    final post = _tot('post_test');
    final bool hasPre = _i(pre['stories']) > 0;
    final bool hasPost = _i(post['stories']) > 0;
    final base = hasPost ? post : pre;
    final bool hasBase = hasPre || hasPost;

    double? change;
    if (hasPre && hasPost) {
      final a = _d(pre['word_pct']);
      final b = _d(post['word_pct']);
      if (a != null && b != null) change = b - a;
    }

    String pct(dynamic v) {
      final d = _d(v);
      return d == null ? '—' : '${_fmt(d)}%';
    }

    final String meta = [
      if (widget.className.isNotEmpty) widget.className,
      if (widget.lrn.isNotEmpty) 'LRN ${widget.lrn}',
    ].join('  •  ');

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: const Color(0xFFD6E6FA),
                child: Text(
                  _initialsOf(widget.studentName),
                  style: const TextStyle(
                    color: Color(0xFF1F4E8C),
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.studentName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: inkText,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                    if (meta.isNotEmpty)
                      Text(
                        meta,
                        style: const TextStyle(
                          color: inkSubtext,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
              ),
              if (hasBase) _levelChip('${base['level'] ?? ''}'),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _exportReport,
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Download report (PDF)'),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 28,
            runSpacing: 12,
            children: [
              _bigStat(
                'Word reading',
                hasBase ? pct(base['word_pct']) : '—',
                hasBase ? (hasPost ? 'Post-test' : 'Pre-test') : null,
              ),
              _bigStat(
                'Comprehension',
                hasBase ? pct(base['comp_pct']) : '—',
                hasBase ? (hasPost ? 'Post-test' : 'Pre-test') : null,
              ),
              _bigStat('Stories finished', '${_records.length}', null),
              _changeStat('Change (post − pre)', change),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // BUILD — isang scrollable page, walang tabs
  // ==========================================
  Widget _buildBody(bool isWide, double bottomInset) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: maroon));
    }
    return RefreshIndicator(
      color: maroon,
      onRefresh: () => _fetchData(silent: true),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16, 16, 16, 32 + bottomInset),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isWide ? 900 : double.infinity,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.teacherView) ...[
                  _buildTeacherHeader(),
                  const SizedBox(height: 18),
                ],
                _buildCompareSection(),
                const SizedBox(height: 18),
                _buildTrendCard(),
                const SizedBox(height: 18),
                _buildTestFilter(),
                _buildScoresSection(),
                const SizedBox(height: 18),
                _buildPowerSection(),
                const SizedBox(height: 18),
                _buildWordsSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isWide = MediaQuery.of(context).size.width >= 800;
    final double bottomInset = MediaQuery.of(context).padding.bottom;

    // Nasa loob ng teacher master-detail: body lang, walang Scaffold.
    if (widget.embedded) {
      return Material(
        color: paperColor,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: _buildBody(false, 0),
      );
    }

    return Scaffold(
      backgroundColor: paperColor,
      appBar: AppBar(
        backgroundColor: maroon,
        foregroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 64,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.teacherView ? "Student record" : "My Hero Progress 🏆",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
            ),
            Text(
              widget.studentName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          // Sa teacher view, nasa header na ang Download button.
          if (!widget.teacherView)
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_outlined),
              tooltip: "Download report (PDF)",
              onPressed: _exportReport,
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Refresh",
            onPressed: () => _fetchData(),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _buildBody(isWide, bottomInset),
    );
  }
}

/// Tuldok na may numero sa itaas (halaga ng score ng story).
class _LabeledDot extends FlDotCirclePainter {
  final String label;

  _LabeledDot({
    required this.label,
    super.color,
    super.radius,
    super.strokeColor,
    super.strokeWidth,
  });

  @override
  void draw(Canvas canvas, FlSpot spot, Offset offsetInCanvas) {
    super.draw(canvas, spot, offsetInCanvas);
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Color(0xFF201A1A),
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(
        offsetInCanvas.dx - tp.width / 2,
        offsetInCanvas.dy - radius - tp.height - 3,
      ),
    );
  }
}
