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

class _StudentProgressScreenState extends State<StudentProgressScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  List<dynamic> _records = [];
  List<dynamic> _mispronunciations = [];
  late TabController _tabController;

  static const Color independentColor = Color(0xFF4CAF50);
  static const Color instructionalColor = Color(0xFFFFA726);
  static const Color frustrationColor = Color(0xFFE53935);
  static const Color maroon = Color(0xFF9B0505);
  static const Color accentYellow = Color(0xFFFDE047);
  static const Color paperColor = Color(0xFFFFF6E4);
  static const Color inkText = Color(0xFF201A1A);
  static const Color inkSubtext = Color(0xFF6B5D5D);
  static const Color cardFill = Colors.white;
  static const Color cardBorder = Color(0xFF201A1A);

  // Weekly reading goal — change this number to adjust the target.
  static const int weeklyGoal = 5;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
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

  // Counts how many stories were completed within the current week
  // (Monday–Sunday), based on each record's `created_at` timestamp.
  int _storiesThisWeek() {
    final now = DateTime.now();
    final startOfWeek = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));

    return _records.where((r) {
      final createdAtStr = r['created_at']?.toString();
      if (createdAtStr == null) return false;
      final createdAt = DateTime.tryParse(createdAtStr);
      if (createdAt == null) return false;
      return !createdAt.isBefore(startOfWeek);
    }).length;
  }

  Widget _buildWeeklyGoalBanner() {
    final int doneThisWeek = _storiesThisWeek();
    final int goal = weeklyGoal;
    final double progress = goal > 0
        ? (doneThisWeek / goal).clamp(0.0, 1.0)
        : 0.0;
    final bool reached = doneThisWeek >= goal;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cardFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cardBorder, width: 2),
        boxShadow: const [BoxShadow(color: cardBorder, offset: Offset(2, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                reached
                    ? "Weekly Goal Reached! 🎉"
                    : "This Week's Reading Quest 📚",
                style: const TextStyle(
                  color: inkText,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
              Text(
                "$doneThisWeek / $goal stories",
                style: TextStyle(
                  color: reached ? independentColor : maroon,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: Colors.black.withOpacity(0.08),
              valueColor: AlwaysStoppedAnimation<Color>(
                reached ? independentColor : accentYellow,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            reached
                ? "Ang galing! Kumpleto na ang goal mo this week!"
                : "${goal - doneThisWeek} more ${(goal - doneThisWeek) == 1 ? 'story' : 'stories'} to go this week!",
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

  Color _levelColor(String level) {
    if (level.toLowerCase().contains('independent')) return independentColor;
    if (level.toLowerCase().contains('instructional'))
      return instructionalColor;
    return frustrationColor;
  }

  Widget _buildBarChartTab() {
    if (_records.isEmpty) {
      return const Center(
        child: Text(
          "No missions completed yet.\nRead a story to earn stars!",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: inkSubtext,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }
    final bars = _records.asMap().entries.map((entry) {
      int i = entry.key;
      double wr = (entry.value['oral_fluency_accuracy'] ?? 0).toDouble();
      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: wr,
            width: 22,
            borderRadius: BorderRadius.circular(6),
            color: _levelColor(entry.value['reading_level'] ?? ''),
            backDrawRodData: BackgroundBarChartRodData(
              show: true,
              toY: 100,
              color: Colors.black.withOpacity(0.06),
            ),
          ),
        ],
      );
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "My Story Accuracy Scores 🎯",
            style: TextStyle(
              color: inkText,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          _buildLegendRow(),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.black12),
            ),
            child: const Text(
              "🟢 Independent Explorer   🟡 Growing Reader   🔴 Needs Practice",
              style: TextStyle(
                color: inkSubtext,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: BarChart(
              BarChartData(
                maxY: 100,
                minY: 0,
                gridData: FlGridData(
                  show: true,
                  horizontalInterval: 20,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: Colors.black.withOpacity(0.08),
                    strokeWidth: 1,
                    dashArray: const [4, 4],
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 20,
                      reservedSize: 36,
                      getTitlesWidget: (v, _) => Text(
                        "${v.toInt()}%",
                        style: const TextStyle(
                          color: inkSubtext,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 44,
                      getTitlesWidget: (v, _) {
                        int i = v.toInt();
                        if (i >= _records.length)
                          return const SizedBox.shrink();
                        String t = _records[i]['story_title'] ?? '';
                        if (t.length > 9) t = '${t.substring(0, 8)}…';
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            t,
                            style: const TextStyle(
                              color: inkSubtext,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: bars,
                extraLinesData: ExtraLinesData(
                  horizontalLines: [
                    HorizontalLine(
                      y: 97,
                      color: independentColor.withValues(alpha: 0.5),
                      strokeWidth: 1.5,
                      dashArray: [6, 3],
                    ),
                    HorizontalLine(
                      y: 90,
                      color: instructionalColor.withValues(alpha: 0.5),
                      strokeWidth: 1.5,
                      dashArray: [6, 3],
                    ),
                  ],
                ),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => Colors.black87,
                    getTooltipItem: (group, _, rod, __) => BarTooltipItem(
                      '${_records[group.x]['story_title']}\n${rod.toY.toStringAsFixed(1)}% Score!',
                      const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPieChartTab() {
    if (_records.isEmpty) {
      return const Center(
        child: Text(
          "No missions completed yet.",
          style: TextStyle(
            color: inkSubtext,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }
    int indep = _records
        .where(
          (r) =>
              (r['reading_level'] ?? '').toLowerCase().contains('independent'),
        )
        .length;
    int instr = _records
        .where(
          (r) => (r['reading_level'] ?? '').toLowerCase().contains(
            'instructional',
          ),
        )
        .length;
    int frust = _records
        .where(
          (r) =>
              (r['reading_level'] ?? '').toLowerCase().contains('frustration'),
        )
        .length;
    int total = _records.length;

    List<PieChartSectionData> sections = [
      if (indep > 0)
        PieChartSectionData(
          value: indep.toDouble(),
          color: independentColor,
          title: '$indep',
          radius: 80,
          titleStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
      if (instr > 0)
        PieChartSectionData(
          value: instr.toDouble(),
          color: instructionalColor,
          title: '$instr',
          radius: 80,
          titleStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
      if (frust > 0)
        PieChartSectionData(
          value: frust.toDouble(),
          color: frustrationColor,
          title: '$frust',
          radius: 80,
          titleStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
    ];

    String best = 'N/A';
    Color bestColor = Colors.white;
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

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "My Reading Power",
            style: TextStyle(
              color: inkText,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          Text(
            "Based on $total completed ${total == 1 ? 'mission' : 'missions'}",
            style: const TextStyle(
              color: inkSubtext,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            flex: 3,
            child: PieChart(
              PieChartData(
                sections: sections,
                centerSpaceRadius: 55,
                sectionsSpace: 3,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildPieLegendCard(
                "🟢 Explorer",
                indep,
                total,
                independentColor,
              ),
              _buildPieLegendCard(
                "🟡 Growing",
                instr,
                total,
                instructionalColor,
              ),
              _buildPieLegendCard(
                "🔴 Practice",
                frust,
                total,
                frustrationColor,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardFill,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cardBorder, width: 2.5),
              boxShadow: const [
                BoxShadow(color: cardBorder, offset: Offset(3, 3)),
              ],
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

  Widget _buildWordsTab() {
    if (_mispronunciations.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.military_tech_rounded,
              color: independentColor,
              size: 80,
            ),
            SizedBox(height: 12),
            Text(
              "Perfect Pronunciation!\nNo words to practice right now! 🎉",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: inkText,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }
    Map<String, int> wordCounts = {};
    for (var m in _mispronunciations) {
      String w = m['word'] ?? '';
      wordCounts[w] = (wordCounts[w] ?? 0) + 1;
    }
    List<MapEntry<String, int>> sorted = wordCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Words to Defeat ⚔️",
            style: TextStyle(
              color: inkText,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          Text(
            "${sorted.length} tricky words • sorted by boss level",
            style: const TextStyle(
              color: inkSubtext,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: ListView.builder(
              itemCount: sorted.length,
              itemBuilder: (context, i) {
                final e = sorted[i];
                Color barColor = e.value >= 3
                    ? frustrationColor
                    : e.value == 2
                    ? instructionalColor
                    : Colors.amber;
                double barWidth = (e.value / sorted.first.value).clamp(
                  0.05,
                  1.0,
                );
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: cardFill,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: cardBorder, width: 2),
                    boxShadow: const [
                      BoxShadow(color: cardBorder, offset: Offset(2, 2)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            e.key,
                            style: const TextStyle(
                              color: inkText,
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                          ),
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
                          backgroundColor: Colors.black.withOpacity(0.08),
                          valueColor: AlwaysStoppedAnimation<Color>(barColor),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendRow() => Row(
    children: [
      _dot(independentColor, "Explorer"),
      const SizedBox(width: 12),
      _dot(instructionalColor, "Growing"),
      const SizedBox(width: 12),
      _dot(frustrationColor, "Practice"),
    ],
  );

  Widget _dot(Color color, String label) => Row(
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 4),
      Text(
        label,
        style: const TextStyle(
          color: inkSubtext,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    ],
  );

  Widget _buildPieLegendCard(String label, int count, int total, Color color) {
    String pct = total > 0
        ? "${((count / total) * 100).toStringAsFixed(0)}%"
        : "0%";
    return Column(
      children: [
        Text(
          pct,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w900,
            fontSize: 20,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: inkSubtext,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isWide = MediaQuery.of(context).size.width >= 800;

    return Scaffold(
      backgroundColor: paperColor,
      appBar: AppBar(
        backgroundColor: maroon,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "My Hero Progress 🏆",
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
            ),
            Text(
              widget.studentName,
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchData),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.18),
                borderRadius: BorderRadius.circular(30),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: accentYellow,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.black, width: 2),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: Colors.black,
                unselectedLabelColor: Colors.white,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 12.5,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12.5,
                ),
                tabs: const [
                  Tab(icon: Icon(Icons.star_rounded, size: 18), text: "Scores"),
                  Tab(icon: Icon(Icons.bolt_rounded, size: 18), text: "Power"),
                  Tab(
                    icon: Icon(Icons.record_voice_over, size: 18),
                    text: "Words",
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: maroon))
          : Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isWide ? 900 : double.infinity,
                ),
                child: Column(
                  children: [
                    _buildWeeklyGoalBanner(),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildBarChartTab(),
                          _buildPieChartTab(),
                          _buildWordsTab(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
