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
  List<dynamic> _mispronunciations = [];

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
            "${widget.baseUrl}/api/student/${widget.studentId}/all-progress",
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
        _records = jsonDecode(results[0].body)['data'] ?? [];
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

  int _countLevel(String key) => _records
      .where(
        (r) =>
            (r['reading_level'] ?? '').toString().toLowerCase().contains(key),
      )
      .length;

  double get _avgScore {
    if (_records.isEmpty) return 0;
    final sum = _records.fold<double>(0, (s, r) => s + _score(r));
    return sum / _records.length;
  }

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

  // ==========================================
  // 1. SUMMARY (nasa taas, para kita agad ang overall)
  // ==========================================
  Widget _statCard(String value, String label, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(
        color: cardFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cardBorder, width: 2),
        boxShadow: const [BoxShadow(color: cardBorder, offset: Offset(2, 2))],
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 22,
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
    ),
  );

  Widget _buildSummaryRow() {
    final int words = _sortedWords().length;
    return Row(
      children: [
        _statCard("${_records.length}", "Stories Done", maroon),
        const SizedBox(width: 10),
        _statCard(
          _records.isEmpty ? "—" : "${_fmt(_avgScore)}%",
          "Average Score",
          independentColor,
        ),
        const SizedBox(width: 10),
        _statCard("$words", "Words to Practice", instructionalColor),
      ],
    );
  }

  // ==========================================
  // 2. SCORES — isang row bawat story, buong title, walang na-truncate
  // ==========================================
  Widget _scoreBar(double score, Color color) {
    return LayoutBuilder(
      builder: (context, c) {
        final double w = c.maxWidth;
        Widget tick(double pct) => Positioned(
          left: (w * pct / 100) - 0.75,
          top: 0,
          bottom: 0,
          child: Container(width: 1.5, color: inkText.withValues(alpha: 0.45)),
        );
        return SizedBox(
          height: 14,
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(7),
                ),
              ),
              Container(
                width: w * score / 100,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(7),
                ),
              ),
              tick(90),
              tick(97),
            ],
          ),
        );
      },
    );
  }

  Widget _scoreRow(dynamic record) {
    final double score = _score(record).clamp(0.0, 100.0);
    final Color color = _levelColor((record['reading_level'] ?? '').toString());
    final String title = (record['story_title'] ?? 'Untitled story').toString();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: inkText,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                "${_fmt(score)}%",
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _scoreBar(score, color),
        ],
      ),
    );
  }

  Widget _buildScoresSection() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            "My Story Accuracy Scores 🎯",
            subtitle: "Each bar is one story. Thin lines mark 90% and 97%.",
          ),
          const SizedBox(height: 12),
          _buildLegend(),
          const SizedBox(height: 16),
          if (_records.isEmpty)
            _emptyText(
              "No missions completed yet.\nRead a story to earn stars!",
            )
          else
            ..._records.map(_scoreRow),
        ],
      ),
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
    if (_records.isEmpty) {
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
    final int total = _records.length;

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
                        _buildSummaryRow(),
                        const SizedBox(height: 18),
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
