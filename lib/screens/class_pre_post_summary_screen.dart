import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

/// Class-level Pre-Test vs Post-Test summary (numeric gain + CSV export).
/// Backend: GET /api/classes/{classId}/pre-post-summary  (ClassReportController)
class ClassPrePostSummaryScreen extends StatefulWidget {
  final String baseUrl;
  final dynamic classId;
  final String className;

  const ClassPrePostSummaryScreen({
    super.key,
    required this.baseUrl,
    required this.classId,
    required this.className,
  });

  @override
  State<ClassPrePostSummaryScreen> createState() =>
      _ClassPrePostSummaryScreenState();
}

class _ClassPrePostSummaryScreenState extends State<ClassPrePostSummaryScreen> {
  static const Color _maroon = Color(0xFF9B0505);
  static const Map<String, String> _headers = {
    'ngrok-skip-browser-warning': '69420',
  };

  // key -> [label, suffix, decimals]
  static const List<List<String>> _metricDefs = [
    ['instructional', 'Instructional Grade', '', '1'],
    ['independent', 'Independent Grade', '', '1'],
    ['frustration', 'Frustration Grade', '', '1'],
    ['wr', 'Word Reading (WR)', '%', '1'],
    ['comp', 'Comprehension (Comp)', '%', '1'],
    ['wpm', 'Words per Minute', '', '1'],
  ];

  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _data;

  String get _url =>
      '${widget.baseUrl}/api/classes/${widget.classId}/pre-post-summary';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await http.get(Uri.parse(_url), headers: _headers);
      if (res.statusCode == 200) {
        _data = Map<String, dynamic>.from(jsonDecode(res.body) as Map);
      } else {
        _error = 'Could not load summary (code ${res.statusCode}).';
      }
    } catch (e) {
      _error = 'No connection. Check your internet and try again.';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _copyCsv() async {
    try {
      final res = await http.get(Uri.parse('$_url?format=csv'), headers: _headers);
      if (res.statusCode != 200) throw Exception('status ${res.statusCode}');
      await Clipboard.setData(ClipboardData(text: utf8.decode(res.bodyBytes)));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('CSV copied. Paste it into Excel / Google Sheets.'),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not export CSV. Try again.')),
      );
    }
  }

  String _fmt(dynamic v, {String suffix = '', bool sign = false}) {
    if (v == null) return '—';
    final n = v is num ? v : num.tryParse(v.toString());
    if (n == null) return '—';
    final s = n.toStringAsFixed(1);
    return '${sign && n > 0 ? '+' : ''}$s$suffix';
  }

  Color _gainColor(dynamic g) {
    final n = g is num ? g : num.tryParse('$g');
    if (n == null || n == 0) return Colors.black54;
    return n > 0 ? Colors.green.shade700 : Colors.red.shade700;
  }

  Widget _box(Widget child) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.brown, width: 2),
        ),
        child: child,
      );

  Widget _chip(String label, dynamic value, Color color) => Expanded(
        child: Column(children: [
          Text('$value',
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w900, color: color)),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
        ]),
      );

  Widget _overview(Map s) {
    final mv = Map<String, dynamic>.from(s['movement'] ?? {});
    return _box(Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('📊 Class Overview',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
        const SizedBox(height: 4),
        Text(
          '${s['total_students']} students • ${s['with_pre']} with pre-test • '
          '${s['with_post']} with post-test • ${s['paired_students']} with both',
          style: const TextStyle(fontSize: 10, color: Colors.black54),
        ),
        const SizedBox(height: 10),
        const Text('Instructional grade movement',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Row(children: [
          _chip('Improved', mv['improved'] ?? 0, Colors.green.shade700),
          _chip('Same', mv['same'] ?? 0, Colors.black54),
          _chip('Declined', mv['declined'] ?? 0, Colors.red.shade700),
        ]),
      ],
    ));
  }

  Widget _metricsTable(Map s) {
    final metrics = Map<String, dynamic>.from(s['metrics'] ?? {});
    return _box(Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('📈 Average Pre vs Post (paired students only)',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowHeight: 34,
            dataRowMinHeight: 34,
            dataRowMaxHeight: 38,
            columnSpacing: 16,
            columns: const [
              DataColumn(label: Text('Measure', style: TextStyle(fontSize: 11))),
              DataColumn(label: Text('n', style: TextStyle(fontSize: 11))),
              DataColumn(label: Text('Pre', style: TextStyle(fontSize: 11))),
              DataColumn(label: Text('Post', style: TextStyle(fontSize: 11))),
              DataColumn(label: Text('Mean gain', style: TextStyle(fontSize: 11))),
              DataColumn(label: Text('SD', style: TextStyle(fontSize: 11))),
              DataColumn(label: Text('t (df)', style: TextStyle(fontSize: 11))),
            ],
            rows: [
              for (final d in _metricDefs)
                () {
                  final m = Map<String, dynamic>.from(metrics[d[0]] ?? {});
                  final suffix = d[2];
                  final t = m['t'] == null
                      ? '—'
                      : '${m['t']} (${m['df']})';
                  return DataRow(cells: [
                    DataCell(Text(d[1], style: const TextStyle(fontSize: 11))),
                    DataCell(Text('${m['n'] ?? 0}',
                        style: const TextStyle(fontSize: 11))),
                    DataCell(Text(_fmt(m['pre_mean'], suffix: suffix),
                        style: const TextStyle(fontSize: 11))),
                    DataCell(Text(_fmt(m['post_mean'], suffix: suffix),
                        style: const TextStyle(fontSize: 11))),
                    DataCell(Text(
                      _fmt(m['mean_gain'], suffix: suffix, sign: true),
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: _gainColor(m['mean_gain'])),
                    )),
                    DataCell(Text(_fmt(m['sd_gain']),
                        style: const TextStyle(fontSize: 11))),
                    DataCell(Text(t, style: const TextStyle(fontSize: 11))),
                  ]);
                }(),
            ],
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Mean gain = average of (post − pre) per student. t is the paired '
          't-statistic; use the CSV export for the p-value in Excel/SPSS.',
          style: TextStyle(fontSize: 9, fontStyle: FontStyle.italic, color: Colors.black54),
        ),
      ],
    ));
  }

  Widget _studentTable(List students) {
    return _box(Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('🧒 Per-Student Results',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowHeight: 34,
            dataRowMinHeight: 34,
            dataRowMaxHeight: 38,
            columnSpacing: 14,
            columns: const [
              DataColumn(label: Text('Student', style: TextStyle(fontSize: 11))),
              DataColumn(label: Text('Inst. Gr. (pre→post)', style: TextStyle(fontSize: 11))),
              DataColumn(label: Text('Gain', style: TextStyle(fontSize: 11))),
              DataColumn(label: Text('WR % (pre→post)', style: TextStyle(fontSize: 11))),
              DataColumn(label: Text('Comp % (pre→post)', style: TextStyle(fontSize: 11))),
              DataColumn(label: Text('WPM (pre→post)', style: TextStyle(fontSize: 11))),
            ],
            rows: [
              for (final raw in students)
                () {
                  final r = Map<String, dynamic>.from(raw as Map);
                  String pair(String k, {String suffix = ''}) =>
                      '${_fmt(r['pre_$k'], suffix: suffix)} → ${_fmt(r['post_$k'], suffix: suffix)}';
                  const st = TextStyle(fontSize: 11);
                  return DataRow(cells: [
                    DataCell(Text('${r['name']}', style: st)),
                    DataCell(Text(pair('instructional'), style: st)),
                    DataCell(Text(
                      _fmt(r['gain_instructional'], sign: true),
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: _gainColor(r['gain_instructional'])),
                    )),
                    DataCell(Text(pair('wr', suffix: '%'), style: st)),
                    DataCell(Text(pair('comp', suffix: '%'), style: st)),
                    DataCell(Text(pair('wpm'), style: st)),
                  ]);
                }(),
            ],
          ),
        ),
      ],
    ));
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _maroon));
    }
    if (_error != null || _data == null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_error ?? 'Something went wrong.'),
          const SizedBox(height: 10),
          ElevatedButton(onPressed: _load, child: const Text('Try Again')),
        ]),
      );
    }
    final s = Map<String, dynamic>.from(_data!['summary'] as Map);
    final students = (_data!['students'] as List?) ?? [];
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          _overview(s),
          _metricsTable(s),
          _studentTable(students),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF6F6),
      appBar: AppBar(
        title: Text('Pre vs Post • ${widget.className}',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        backgroundColor: _maroon,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Copy CSV',
            icon: const Icon(Icons.copy_all_rounded),
            onPressed: _data == null ? null : _copyCsv,
          ),
        ],
      ),
      body: _body(),
    );
  }
}