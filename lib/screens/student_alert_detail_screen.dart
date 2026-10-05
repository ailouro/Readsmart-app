import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/config.dart';

class StudentAlertDetailScreen extends StatefulWidget {
  final int teacherId;
  final String studentId;
  const StudentAlertDetailScreen({
    super.key,
    required this.teacherId,
    required this.studentId,
  });

  @override
  State<StudentAlertDetailScreen> createState() =>
      _StudentAlertDetailScreenState();
}

class _StudentAlertDetailScreenState extends State<StudentAlertDetailScreen> {
  static const Color maroon = Color(0xFF940D0D);
  static const Color independentColor = Color(0xFF4CAF50);
  static const Color instructionalColor = Color(0xFFFFA726);
  static const Color frustrationColor = Color(0xFFE53935);

  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _data;

  // Galing sa GET /api/student/{id}/progress-detail. Optional: kung pumalya,
  // ang dating Review screen pa rin ang lalabas (walang breakdown sections).
  List<dynamic> _records = [];
  Map<String, dynamic> _totals = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        http.get(
          Uri.parse(
            '$baseUrl/api/teachers/${widget.teacherId}/alerts/${widget.studentId}',
          ),
          headers: networkHeaders,
        ),
        _fetchDetail(),
      ]);
      final res = results[0] as http.Response;
      if (!mounted) return;
      if (res.statusCode == 200) {
        setState(() {
          _data = jsonDecode(res.body)['data'];
          _loading = false;
        });
      } else {
        setState(() {
          _error = 'Error ${res.statusCode}';
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Hindi ma-load: $e';
        _loading = false;
      });
    }
  }

  Future<void> _fetchDetail() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/student/${widget.studentId}/progress-detail'),
        headers: networkHeaders,
      );
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body is Map) {
          _records = (body['data'] as List?) ?? [];
          final t = body['totals'];
          _totals = t is Map ? Map<String, dynamic>.from(t) : {};
        }
      }
    } catch (e) {
      debugPrint('Error fetching progress-detail: $e');
    }
  }

  // ==========================================
  // HELPERS
  // ==========================================
  num? _n(dynamic v) => v is num ? v : num.tryParse('${v ?? ''}');

  int _i(dynamic v) => _n(v)?.toInt() ?? 0;

  String _p1(num? v) {
    if (v == null) return '—';
    return v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
  }

  String _levelLabel(dynamic level) {
    final s = '${level ?? ''}'.toLowerCase();
    if (s.contains('independent')) return 'Independent';
    if (s.contains('instructional')) return 'Instructional';
    if (s.contains('frustration')) return 'Frustration';
    return '—';
  }

  Color _levelColor(dynamic level) {
    final s = '${level ?? ''}'.toLowerCase();
    if (s.contains('independent')) return independentColor;
    if (s.contains('instructional')) return instructionalColor;
    return frustrationColor;
  }

  Map<String, dynamic> _tot(String key) {
    final t = _totals[key];
    return t is Map ? Map<String, dynamic>.from(t) : <String, dynamic>{};
  }

  Widget _levelChip(dynamic level) {
    final c = _levelColor(level);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c, width: 1.2),
      ),
      child: Text(
        _levelLabel(level),
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c),
      ),
    );
  }

  Widget _stat(String label, dynamic value, {String suffix = ''}) => Expanded(
    child: Column(
      children: [
        Text(
          value == null ? '—' : '$value$suffix',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11, color: Colors.black54),
        ),
      ],
    ),
  );

  String _attemptText(int n) =>
      n <= 1 ? 'Isang beses nagkamali' : '$n beses nagkamali';

  // ==========================================
  // PRE-TEST vs POST-TEST (pooled totals)
  // ==========================================
  Widget _testColumn(String title, Map<String, dynamic> t) {
    final stories = _i(t['stories']);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          if (stories == 0)
            const Text(
              'Wala pang natapos.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            )
          else ...[
            Text(
              '$stories ${stories == 1 ? 'story' : 'stories'}',
              style: const TextStyle(fontSize: 11, color: Colors.black54),
            ),
            const SizedBox(height: 6),
            const Text(
              'Word Reading',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
            if (_i(t['total_words']) > 0)
              Text(
                '${_i(t['correct_words'])} ÷ ${_i(t['total_words'])} × 100',
                style: const TextStyle(fontSize: 11, color: Colors.black54),
              )
            else
              const Text(
                'Walang naka-save na bilang ng salita',
                style: TextStyle(fontSize: 10, color: Colors.black54),
              ),
            Text(
              '= ${_p1(_n(t['word_pct']))}%',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            const Text(
              'Comprehension',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
            if (_i(t['quiz_questions']) > 0)
              Text(
                '${_i(t['quiz_correct'])} ÷ ${_i(t['quiz_questions'])} × 100',
                style: const TextStyle(fontSize: 11, color: Colors.black54),
              ),
            Text(
              '= ${_p1(_n(t['comp_pct']))}%',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            _levelChip(t['level']),
          ],
        ],
      ),
    );
  }

  Widget _gainText(String label, num? pre, num? post) {
    if (pre == null || post == null) return const SizedBox.shrink();
    final g = post - pre;
    final color = g > 0
        ? Colors.green.shade700
        : g < 0
        ? Colors.red.shade700
        : Colors.black54;
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        '$label: ${g > 0 ? '+' : ''}${_p1(g)}%',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }

  Widget _buildPrePostCard() {
    final pre = _tot('pre_test');
    final post = _tot('post_test');
    if (pre.isEmpty && post.isEmpty) return const SizedBox.shrink();

    final bothDone = _i(pre['stories']) > 0 && _i(post['stories']) > 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pre-Test vs Post-Test',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const Text(
              'Kabuuang tamang salita ÷ kabuuang salita (pooled)',
              style: TextStyle(fontSize: 10, color: Colors.black54),
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _testColumn('Pre-Test', pre),
                const SizedBox(width: 12),
                _testColumn('Post-Test', post),
              ],
            ),
            if (bothDone) ...[
              const Divider(height: 22),
              const Text(
                'Pagbabago (Post − Pre)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              _gainText(
                'Word Reading',
                _n(pre['word_pct']),
                _n(post['word_pct']),
              ),
              _gainText(
                'Comprehension',
                _n(pre['comp_pct']),
                _n(post['comp_pct']),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ==========================================
  // BAWAT STORY
  // ==========================================
  Widget _storyTile(Map<String, dynamic> r) {
    final isPre = '${r['test_type']}' == 'pre_test';
    final total = _i(r['total_words']);
    final miscues = _i(r['miscues_count']);
    final correct = _i(r['correct_words_count']);
    final wordPct = _n(
      r['word_reading_score_pct'] ?? r['oral_fluency_accuracy'],
    );
    final qq = _i(r['total_questions']);
    final qc = _i(r['quiz_score']);
    final compPct = _n(r['comprehension_score_pct']);
    final wpm = _n(r['wpm']);
    final secs = _i(r['time_on_task']);

    const small = TextStyle(fontSize: 12, color: Colors.black87);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${r['story_title'] ?? 'Untitled story'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                isPre ? 'PRE' : 'POST',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: isPre ? Colors.blueGrey : maroon,
                ),
              ),
              const SizedBox(width: 6),
              _levelChip(r['reading_level']),
            ],
          ),
          const SizedBox(height: 8),
          if (total > 0) ...[
            Text(
              '$total salita − $miscues miscues = $correct tama',
              style: small,
            ),
            Text(
              '$correct ÷ $total × 100 = ${_p1(wordPct)}%',
              style: small.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 8,
                child: Row(
                  children: [
                    Expanded(
                      flex: correct == 0 ? 0 : correct,
                      child: Container(color: independentColor),
                    ),
                    Expanded(
                      flex: miscues == 0 ? 0 : miscues,
                      child: Container(color: frustrationColor),
                    ),
                  ],
                ),
              ),
            ),
          ] else
            Text(
              'Word Reading: ${_p1(wordPct)}% (walang naka-save na bilang ng salita)',
              style: small,
            ),
          const SizedBox(height: 6),
          if (qq > 0)
            Text(
              'Comprehension: $qc ÷ $qq × 100 = ${_p1(compPct)}%',
              style: small,
            )
          else
            Text('Comprehension: ${_p1(compPct)}%', style: small),
          const SizedBox(height: 2),
          Text(
            'WPM: ${_p1(wpm)} • Oras: ${secs ~/ 60}m ${secs % 60}s',
            style: const TextStyle(fontSize: 11, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _buildStoriesSection() {
    if (_records.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Bawat story',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        ..._records.whereType<Map>().map(
          (r) => _storyTile(Map<String, dynamic>.from(r)),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Review'),
        backgroundColor: maroon,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: maroon))
          : _error != null
          ? Center(child: Text(_error!))
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    final d = _data!;
    final latest = d['latest'] as Map<String, dynamic>?;
    final words = (d['top_struggled_words'] as List?) ?? [];
    final history = (d['history'] as List?) ?? [];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          '${d['student_name'] ?? ''}',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        Text('${d['class_name'] ?? ''}'),
        const SizedBox(height: 16),
        if (latest != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Latest Result',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _stat('Words/min', latest['wpm']),
                      _stat(
                        'Oral fluency',
                        latest['oral_fluency_accuracy'],
                        suffix: '%',
                      ),
                      _stat(
                        'Comprehension',
                        latest['comprehension_score_pct'],
                        suffix: '%',
                      ),
                      _stat(
                        'Word reading',
                        latest['word_reading_score_pct'],
                        suffix: '%',
                      ),
                    ],
                  ),
                  if (latest['reading_profile'] != null) ...[
                    const SizedBox(height: 10),
                    Text('Profile: ${latest['reading_profile']}'),
                  ],
                ],
              ),
            ),
          ),
        const SizedBox(height: 16),
        _buildPrePostCard(),
        _buildStoriesSection(),
        const SizedBox(height: 8),
        const Text(
          'Words na nahirapan',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        if (words.isEmpty)
          const Text('Wala pang naitalang struggled words.')
        else ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'Pinakamadalas nahirapan sa '
              '${words.take(3).map((w) => '"${w['word']}"').join(', ')}.',
              style: const TextStyle(fontSize: 13),
            ),
          ),
          const SizedBox(height: 4),
          ...words.take(8).map((w) {
            final n = (w['count'] as num?)?.toInt() ?? 1;
            return ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 20,
              ),
              title: Text(
                '${w['word']}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(_attemptText(n)),
            );
          }),
        ],
        if (history.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text('History', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ...history.map((item) {
            final score = item['score'] ?? '—';
            final date = item['date'] ?? '—';
            return ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.history, size: 18),
              title: Text('$score'),
              subtitle: Text('$date'),
            );
          }),
        ],
      ],
    );
  }
}
