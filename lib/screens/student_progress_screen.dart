import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';

class StudentProgressScreen extends StatefulWidget {
  final int studentId;
  final String baseUrl;
  final String studentName;

  const StudentProgressScreen({
    super.key,
    required this.studentId,
    required this.baseUrl,
    required this.studentName,
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
      border: Border.all(color: cardBorder, width: 2.5),
      boxShadow: const [BoxShadow(color: cardBorder, offset: Offset(3, 3))],
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
        border: Border.all(color: c, width: 1.5),
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

  Widget _totalBlock(String title, Map<String, dynamic> t, Color accent) {
    final bool hasData = _i(t['stories']) > 0;
    final int words = _i(t['total_words']);
    final int quizQ = _i(t['quiz_questions']);
    final double wr = _d(t['word_pct']) ?? 0;
    final double comp = _d(t['comp_pct']) ?? 0;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: paperColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent, width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: accent,
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 6),
            if (!hasData)
              const Text(
                'Wala pang natapos na story.',
                style: TextStyle(color: inkSubtext, fontSize: 12),
              )
            else ...[
              _kv('Stories', '${_i(t['stories'])}'),
              _kv('Kabuuang salita', words > 0 ? '$words' : '—'),
              _kv('Miscues', words > 0 ? '${_i(t['miscues'])}' : '—'),
              _kv(
                'Tamang salita',
                words > 0 ? '${_i(t['correct_words'])}' : '—',
              ),
              const Divider(height: 14, color: Colors.black26),
              const Text(
                'Word Reading',
                style: TextStyle(
                  color: inkSubtext,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                words > 0
                    ? '${_i(t['correct_words'])} ÷ $words × 100 = ${_fmt(wr)}%'
                    : '${_fmt(wr)}% (average)',
                style: const TextStyle(
                  color: inkText,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Comprehension',
                style: TextStyle(
                  color: inkSubtext,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                quizQ > 0
                    ? '${_i(t['quiz_correct'])} ÷ $quizQ × 100 = ${_fmt(comp)}%'
                    : '${_fmt(comp)}% (average)',
                style: const TextStyle(
                  color: inkText,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
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
  Widget _wordSplitBar(int correct, int miscues) => ClipRRect(
    borderRadius: BorderRadius.circular(6),
    child: SizedBox(
      height: 14,
      child: Row(
        children: [
          if (correct > 0)
            Expanded(
              flex: correct,
              child: Container(color: independentColor),
            ),
          if (miscues > 0)
            Expanded(
              flex: miscues,
              child: Container(color: frustrationColor),
            ),
        ],
      ),
    ),
  );

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

    TextStyle label() => const TextStyle(
      color: inkSubtext,
      fontSize: 11,
      fontWeight: FontWeight.bold,
    );
    TextStyle formula() => const TextStyle(
      color: inkText,
      fontSize: 13,
      fontWeight: FontWeight.w900,
    );

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: paperColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardBorder, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  '#$n  $title',
                  style: const TextStyle(
                    color: inkText,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _levelChip(level),
            ],
          ),
          const SizedBox(height: 10),
          Text('Word Reading', style: label()),
          const SizedBox(height: 2),
          if (total > 0) ...[
            Text(
              '$total salita − $miscues miscues = $correct tama',
              style: formula(),
            ),
            Text('$correct ÷ $total × 100 = ${_fmt(wr)}%', style: formula()),
            const SizedBox(height: 6),
            _wordSplitBar(correct, miscues),
            const SizedBox(height: 4),
            Row(
              children: [
                _dot(independentColor, 'Tama: $correct'),
                const SizedBox(width: 14),
                _dot(frustrationColor, 'Miscues: $miscues'),
              ],
            ),
          ] else
            Text(
              '${_fmt(wr)}% (walang naka-save na bilang ng salita para sa story na ito)',
              style: formula(),
            ),
          const SizedBox(height: 10),
          Text('Comprehension', style: label()),
          const SizedBox(height: 2),
          Text(
            qt > 0 ? '$qc ÷ $qt × 100 = ${_fmt(comp)}%' : '${_fmt(comp)}%',
            style: formula(),
          ),
          const SizedBox(height: 10),
          Text(
            'Bilis: ${wpm > 0 ? '$wpm WPM' : '—'}  •  Oras: ${_dur(secs)}',
            style: label(),
          ),
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
                'Isang bar kada story. Ang mga guhit ay 90% at 97% na cutoff.',
          ),
          const SizedBox(height: 12),
          _buildLegend(),
          const SizedBox(height: 14),
          _storyChart(recs),
          for (int i = 0; i < recs.length; i++) _storyDetail(i + 1, recs[i]),
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
              border: Border.all(color: cardBorder, width: 2),
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
                  border: Border.all(color: barColor, width: 1.5),
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
            _sectionHeader("Words to Defeat ⚔️"),
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
            "Words to Defeat ⚔️",
            subtitle: "${sorted.length} tricky words • sorted by boss level",
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
  // BUILD — isang scrollable page, walang tabs
  // ==========================================
  @override
  Widget build(BuildContext context) {
    final bool isWide = MediaQuery.of(context).size.width >= 800;
    final double bottomInset = MediaQuery.of(context).padding.bottom;

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
            const Text(
              "My Hero Progress 🏆",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
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
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Refresh",
            onPressed: () => _fetchData(),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: maroon))
          : RefreshIndicator(
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
                        _buildCompareSection(),
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
            ),
    );
  }
}
