import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'student_progress_screen.dart';

/// Roster ng mga estudyante ng teacher: initials, LRN, post-test level at
/// pagbabago, may search at filter. Sa malapad na screen (laptop) ang profile
/// ay lumalabas sa kanan; sa phone, bubukas ang bagong screen.
///
/// [students] = summary['students'] mula sa /api/teachers/{id}/dashboard-summary.
/// Ang level at pagbabago ay galing sa /api/student/{id}/progress-detail
/// (pooled), kaya tugma sa profile ng estudyante.
class StudentRosterPanel extends StatefulWidget {
  final List<dynamic> students;
  final String baseUrl;
  final Map<dynamic, dynamic> headers;

  const StudentRosterPanel({
    super.key,
    required this.students,
    required this.baseUrl,
    this.headers = const {},
  });

  @override
  State<StudentRosterPanel> createState() => _StudentRosterPanelState();
}

class _StudentRosterPanelState extends State<StudentRosterPanel> {
  static const Color _lvIndependent = Color(0xFF4CAF50);
  static const Color _lvInstructional = Color(0xFFFFA726);
  static const Color _lvFrustration = Color(0xFFE53935);

  final TextEditingController _search = TextEditingController();
  String _filter = 'all'; // all | needs_help | improved | no_post
  int? _selectedId;

  final Map<dynamic, Map<String, dynamic>> _totals = {};
  final Map<dynamic, List<dynamic>> _records = {};
  Future<void>? _loadFuture;
  String _idsKey = '';

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didUpdateWidget(covariant StudentRosterPanel old) {
    super.didUpdateWidget(old);
    if (_keyOf(widget.students) != _idsKey) _reload();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _keyOf(List<dynamic> list) =>
      list.map((s) => s is Map ? '${s['id']}' : '').join(',');

  List<Map<String, dynamic>> get _list => widget.students
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList();

  void _reload() {
    _idsKey = _keyOf(widget.students);
    _totals.clear();
    _records.clear();
    _loadFuture = Future.wait(_list.map((s) => _fetch(s['id'])));
  }

  Future<void> _fetch(dynamic id) async {
    try {
      final res = await http.get(
        Uri.parse("${widget.baseUrl}/api/student/$id/progress-detail"),
        headers: widget.headers.map(
          (k, v) => MapEntry(k.toString(), v.toString()),
        ),
      );
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map) {
          if (decoded['totals'] is Map) {
            _totals[id] = Map<String, dynamic>.from(decoded['totals'] as Map);
          }
          if (decoded['data'] is List) {
            _records[id] = decoded['data'] as List<dynamic>;
          }
        }
      }
    } catch (e) {
      debugPrint("Roster: error fetching progress for $id: $e");
    }
  }

  // ---------------------------------------------------------------- helpers
  String _s(dynamic v, [String d = '']) {
    final t = v?.toString().trim() ?? '';
    return (t.isEmpty || t == 'null') ? d : t;
  }

  String _name(Map<String, dynamic> s) {
    final full = '${_s(s['first_name'])} ${_s(s['last_name'])}'.trim();
    return _s(s['name'], full.isEmpty ? 'Unnamed student' : full);
  }

  String _className(Map<String, dynamic> s) =>
      _s(s['class_name'], '${_s(s['grade_level'])} ${_s(s['section'])}'.trim());

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  Map<String, dynamic> _test(dynamic id, String key) {
    final t = _totals[id]?[key];
    return t is Map ? Map<String, dynamic>.from(t) : <String, dynamic>{};
  }

  bool _has(Map<String, dynamic> t) =>
      (num.tryParse('${t['stories'] ?? 0}') ?? 0) > 0;

  String _level(Map<String, dynamic> t) {
    if (!_has(t)) return '';
    final lv = '${t['level'] ?? ''}'.toLowerCase();
    return const ['independent', 'instructional', 'frustration'].contains(lv)
        ? lv
        : '';
  }

  Color _lvColor(String k) => k == 'independent'
      ? _lvIndependent
      : k == 'instructional'
      ? _lvInstructional
      : k == 'frustration'
      ? _lvFrustration
      : Colors.black26;

  String _lvLabel(String k) => k == 'independent'
      ? 'Independent'
      : k == 'instructional'
      ? 'Instructional'
      : k == 'frustration'
      ? 'Frustration'
      : '';

  double? _change(Map<String, dynamic> s) {
    final pre = _test(s['id'], 'pre_test');
    final post = _test(s['id'], 'post_test');
    if (!_has(pre) || !_has(post)) return null;
    final a = double.tryParse('${pre['word_pct']}');
    final b = double.tryParse('${post['word_pct']}');
    return (a == null || b == null) ? null : b - a;
  }

  // Parehong rule ng Alerts tab: ang huling 2 natapos na story ay parehong
  // Frustration (kailangan ng hindi bababa sa 2 story).
  bool _needsHelp(Map<String, dynamic> s) {
    final recs = _records[s['id']] ?? const <dynamic>[];
    if (recs.length < 2) return false;
    return recs
        .sublist(recs.length - 2)
        .every(
          (r) =>
              '${r['reading_level'] ?? ''}'.trim().toLowerCase() ==
              'frustration',
        );
  }

  bool _matches(Map<String, dynamic> s) {
    final q = _search.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      final hay = '${_name(s)} ${_s(s['lrn'])}'.toLowerCase();
      if (!hay.contains(q)) return false;
    }
    switch (_filter) {
      case 'needs_help':
        return _needsHelp(s);
      case 'improved':
        final ch = _change(s);
        return ch != null && ch > 0;
      case 'no_post':
        return !_has(_test(s['id'], 'post_test'));
      default:
        return true;
    }
  }

  void _open(Map<String, dynamic> s, {required bool wide}) {
    final id = int.tryParse('${s['id']}');
    if (id == null) return;
    if (wide) {
      setState(() => _selectedId = id);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StudentProgressScreen(
          studentId: id,
          baseUrl: widget.baseUrl,
          studentName: _name(s),
          teacherView: true,
          lrn: _s(s['lrn']),
          className: _className(s),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------- UI
  Widget _pill(String lv) {
    final bool none = lv.isEmpty;
    final Color c = none ? Colors.black45 : _lvColor(lv);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: none
            ? Colors.black.withValues(alpha: 0.05)
            : c.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        none ? 'No post-test yet' : _lvLabel(lv),
        style: TextStyle(color: c, fontWeight: FontWeight.w900, fontSize: 11),
      ),
    );
  }

  Widget _row(Map<String, dynamic> s, {required bool wide}) {
    final id = int.tryParse('${s['id']}');
    final bool selected = wide && id != null && id == _selectedId;
    final change = _change(s);
    final name = _name(s);
    final lrn = _s(s['lrn']);
    final cls = _className(s);

    String changeText = '--';
    Color changeColor = Colors.black38;
    if (change != null) {
      final v = change % 1 == 0
          ? change.toStringAsFixed(0)
          : change.toStringAsFixed(1);
      changeText = change >= 0 ? '+$v%' : '$v%';
      changeColor = change < 0 ? _lvFrustration : _lvIndependent;
    }

    return Material(
      color: selected ? const Color(0xFFE8F1FB) : Colors.transparent,
      child: InkWell(
        onTap: () => _open(s, wide: wide),
        hoverColor: const Color(0xFFF1F6FC),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: const Color(0xFFD6E6FA),
                child: Text(
                  _initials(name),
                  style: const TextStyle(
                    color: Color(0xFF1F4E8C),
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (lrn.isNotEmpty || cls.isNotEmpty)
                      Text(
                        lrn.isNotEmpty ? 'LRN $lrn' : cls,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _pill(_level(_test(s['id'], 'post_test'))),
                  const SizedBox(height: 4),
                  Text(
                    changeText,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: changeColor,
                    ),
                  ),
                ],
              ),
              if (!wide) const Icon(Icons.chevron_right, color: Colors.black38),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stat(String label, int value) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
        Text(
          '$value',
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
        ),
      ],
    ),
  );

  Widget _shell({required Widget child}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.black, width: 3),
      boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(4, 4))],
    ),
    child: child,
  );

  @override
  Widget build(BuildContext context) {
    final students = _list;
    if (students.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, box) {
        final bool wide = box.maxWidth >= 900;

        return FutureBuilder<void>(
          future: _loadFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return _shell(
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }

            int priority(Map<String, dynamic> s) {
              final lv = _level(_test(s['id'], 'post_test'));
              return lv == 'frustration'
                  ? 0
                  : lv == 'instructional'
                  ? 1
                  : lv == 'independent'
                  ? 2
                  : 3;
            }

            final sorted = [...students]
              ..sort((a, b) {
                final p = priority(a).compareTo(priority(b));
                if (p != 0) return p;
                return _name(a).toLowerCase().compareTo(_name(b).toLowerCase());
              });

            final int finishedPost = students
                .where((s) => _has(_test(s['id'], 'post_test')))
                .length;
            final int needHelp = students.where(_needsHelp).length;
            final visible = sorted.where(_matches).toList();

            Widget chip(String key, String label) => ChoiceChip(
              label: Text(label),
              selected: _filter == key,
              onSelected: (_) => setState(() => _filter = key),
            );

            final Widget top = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Students",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                Text(
                  "${students.length} enrolled",
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _stat('Finished post-test', finishedPost),
                    _stat('Need help', needHelp),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search student or LRN',
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    chip('all', 'All'),
                    chip('needs_help', 'Needs help'),
                    chip('improved', 'Improved'),
                    chip('no_post', 'No post-test'),
                  ],
                ),
                const SizedBox(height: 4),
              ],
            );

            const Widget empty = Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No students match.',
                  style: TextStyle(color: Colors.black54),
                ),
              ),
            );

            Widget divider() =>
                Divider(height: 1, color: Colors.black.withValues(alpha: 0.07));

            // ---- Phone: isang column, bubukas ang bagong screen ----------
            if (!wide) {
              return _shell(
                child: Column(
                  children: [
                    top,
                    if (visible.isEmpty) empty,
                    for (int i = 0; i < visible.length; i++) ...[
                      if (i > 0) divider(),
                      _row(visible[i], wide: false),
                    ],
                  ],
                ),
              );
            }

            // ---- Laptop: roster sa kaliwa, profile sa kanan --------------
            final double h = (MediaQuery.of(context).size.height - 160)
                .clamp(520.0, 900.0)
                .toDouble();

            Map<String, dynamic>? selected;
            for (final s in students) {
              if (int.tryParse('${s['id']}') == _selectedId) selected = s;
            }

            return SizedBox(
              height: h,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 380,
                    child: _shell(
                      child: Column(
                        children: [
                          top,
                          Expanded(
                            child: visible.isEmpty
                                ? empty
                                : ListView.separated(
                                    itemCount: visible.length,
                                    separatorBuilder: (context, index) =>
                                        divider(),
                                    itemBuilder: (context, i) =>
                                        _row(visible[i], wide: true),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: selected == null
                        ? _shell(
                            child: const Center(
                              child: Text(
                                'Select a student to see their progress.',
                                style: TextStyle(color: Colors.black54),
                              ),
                            ),
                          )
                        : StudentProgressScreen(
                            key: ValueKey(_selectedId),
                            studentId: _selectedId!,
                            baseUrl: widget.baseUrl,
                            studentName: _name(selected),
                            teacherView: true,
                            embedded: true,
                            lrn: _s(selected['lrn']),
                            className: _className(selected),
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
