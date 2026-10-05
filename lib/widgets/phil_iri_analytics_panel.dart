import 'dart:math' as math;
import 'package:flutter/material.dart';

// ============================================================
// Phil-IRI analytics panel
//
// Ipinapakita ang buong computation, mula sa score ng bata hanggang sa
// final na level:
//   1. Flow diagram (formula + cutoffs)
//   2. Matrix: Word Reading level x Comprehension level (bilang ng bata)
//   3. Scatter: bawat bata bilang tuldok, may zones ng cutoff
//   4. Donut: kabuuang bilang kada level
//   5. Buod bawat klase
//
// Lahat ng level ay galing sa backend (PhilIriService). Dito lang ito
// ipinapakita, kaya iisa lang ang pinagmumulan ng computation.
//
// Gamitin:
//   PhilIriAnalyticsPanel(summary: _summaryData, testType: _summaryTestType)
// ============================================================

class PhilIriTheme {
  PhilIriTheme._();

  static const Color frustration = Color(0xFFD32F2F);
  static const Color instructional = Color(0xFFFF8F00);
  static const Color independent = Color(0xFF66BB6A);
  static const Color ink = Color(0xFF201A1A);
  static const Color maroon = Color(0xFF940D0D);

  // Pagkakasunod: pinakamababa -> pinakamataas
  static const List<String> levels = [
    'frustration',
    'instructional',
    'independent',
  ];

  static int rank(String level) => levels.indexOf(level);

  static Color colorOf(String level) {
    switch (level) {
      case 'independent':
        return independent;
      case 'instructional':
        return instructional;
      default:
        return frustration;
    }
  }

  static Color onColor(String level) =>
      level == 'frustration' ? Colors.white : Colors.black;

  static String labelOf(String level) {
    switch (level) {
      case 'independent':
        return 'Independent';
      case 'instructional':
        return 'Instructional';
      default:
        return 'Frustration';
    }
  }

  // Panangga lang kung walang wr_level / comp_level galing sa server.
  static String wordReadingLevel(double pct) {
    if (pct >= 97) return 'independent';
    if (pct >= 90) return 'instructional';
    return 'frustration';
  }

  static String comprehensionLevel(double pct) {
    final double r = pct.roundToDouble();
    if (r >= 80) return 'independent';
    if (r >= 59) return 'instructional';
    return 'frustration';
  }
}

int _asInt(dynamic v) {
  if (v is num) return v.toInt();
  return int.tryParse('${v ?? ''}') ?? 0;
}

double? _asDouble(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse('${v ?? ''}');
}

// ------------------------------------------------------------
// Pre/Post filter (pamalit sa SegmentedButton na nagsisingit ang text)
// ------------------------------------------------------------
class PhilIriTestTypeFilter extends StatelessWidget {
  final String value; // 'pre_test' | 'post_test'
  final ValueChanged<String> onChanged;

  const PhilIriTestTypeFilter({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    Widget chip(String key, String label) {
      final bool selected = value == key;
      return ChoiceChip(
        label: Text(
          label,
          softWrap: false,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: selected ? Colors.white : PhilIriTheme.ink,
          ),
        ),
        selected: selected,
        showCheckmark: false,
        selectedColor: PhilIriTheme.maroon,
        backgroundColor: Colors.white,
        side: const BorderSide(color: Colors.black, width: 2),
        onSelected: (_) => onChanged(key),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            chip('pre_test', 'Pre-Test'),
            chip('post_test', 'Post-Test'),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Average ng lahat ng natapos na stories ng bawat bata.',
          style: TextStyle(fontSize: 11, color: Colors.black54),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------
// Model ng isang bata (galing sa summary['students'])
// ------------------------------------------------------------
class _Learner {
  final String name;
  final double wr; // Word Reading % (average)
  final double comp; // Comprehension % (average, whole number)
  final String wrLevel;
  final String compLevel;
  final String level;

  const _Learner({
    required this.name,
    required this.wr,
    required this.comp,
    required this.wrLevel,
    required this.compLevel,
    required this.level,
  });
}

List<_Learner> _parseLearners(Map<String, dynamic> summary) {
  final List raw = (summary['students'] as List?) ?? const [];
  final List<_Learner> out = [];
  for (final item in raw) {
    if (item is! Map) continue;
    final String level = '${item['reading_level'] ?? ''}'.toLowerCase();
    if (PhilIriTheme.rank(level) < 0) continue;

    final double? wr = _asDouble(item['avg_accuracy']);
    final double? comp = _asDouble(item['avg_comprehension']);
    if (wr == null || comp == null) continue;

    String wrLevel = '${item['wr_level'] ?? ''}'.toLowerCase();
    if (PhilIriTheme.rank(wrLevel) < 0) {
      wrLevel = PhilIriTheme.wordReadingLevel(wr);
    }
    String compLevel = '${item['comp_level'] ?? ''}'.toLowerCase();
    if (PhilIriTheme.rank(compLevel) < 0) {
      compLevel = PhilIriTheme.comprehensionLevel(comp);
    }

    out.add(
      _Learner(
        name: '${item['name'] ?? 'N/A'}',
        wr: wr,
        comp: comp,
        wrLevel: wrLevel,
        compLevel: compLevel,
        level: level,
      ),
    );
  }
  return out;
}

// ------------------------------------------------------------
// MAIN PANEL
// ------------------------------------------------------------
class PhilIriAnalyticsPanel extends StatelessWidget {
  final Map<String, dynamic> summary;
  final String testType;

  const PhilIriAnalyticsPanel({
    super.key,
    required this.summary,
    required this.testType,
  });

  @override
  Widget build(BuildContext context) {
    final List<_Learner> learners = _parseLearners(summary);
    final String testLabel = testType == 'pre_test' ? 'Pre-Test' : 'Post-Test';

    return LayoutBuilder(
      builder: (context, c) {
        final bool wide = c.maxWidth >= 900;

        Widget two(Widget a, Widget b) {
          if (wide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: a),
                const SizedBox(width: 16),
                Expanded(child: b),
              ],
            );
          }
          return Column(children: [a, const SizedBox(height: 16), b]);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _FlowCard(),
            const SizedBox(height: 16),
            if (learners.isEmpty)
              _PanelCard(
                title: 'Wala pang datos para sa $testLabel',
                subtitle: null,
                child: const Text(
                  'Lalabas ang diagram kapag may natapos nang story at '
                  'pagsusulit ang mga bata para sa napiling test.',
                  style: TextStyle(fontSize: 13),
                ),
              )
            else ...[
              two(
                _MatrixCard(learners: learners),
                _ScatterCard(learners: learners),
              ),
              const SizedBox(height: 16),
              two(
                _DonutCard(summary: summary),
                _ClassSummaryCard(summary: summary),
              ),
            ],
          ],
        );
      },
    );
  }
}

// ------------------------------------------------------------
// Pangkalahatang card (comic style, kapareho ng existing charts)
// ------------------------------------------------------------
class _PanelCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;

  const _PanelCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black, width: 3),
        boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(4, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: const TextStyle(fontSize: 11, color: Colors.black54),
            ),
          ],
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

// ------------------------------------------------------------
// 1. FLOW: score -> level ng bawat isa -> final level
// ------------------------------------------------------------
class _FlowCard extends StatelessWidget {
  const _FlowCard();

  @override
  Widget build(BuildContext context) {
    return _PanelCard(
      title: 'Paano nakukuwenta ang Phil-IRI level',
      subtitle:
          'Mula sa score ng bata hanggang sa final na level. '
          'Average ito ng lahat ng natapos na stories ng bata.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, c) {
              final bool wide = c.maxWidth >= 720;
              const steps = <Widget>[
                _FlowStep(
                  number: 1,
                  title: 'Pagbasa nang malakas',
                  formula:
                      'Word Reading % =\ntamang salita ÷ kabuuang salita × 100',
                  fill: Color(0xFFE3F2FD),
                ),
                _FlowStep(
                  number: 2,
                  title: 'Pagsusulit',
                  formula:
                      'Comprehension % =\ntamang sagot ÷ bilang ng tanong × 100\n'
                      '(ni-round sa buong numero)',
                  fill: Color(0xFFFFF8E1),
                ),
                _FlowStep(
                  number: 3,
                  title: 'Level ng bawat score',
                  formula: 'Ikumpara ang bawat % sa mga cutoff sa ibaba.',
                  fill: Color(0xFFF3E5F5),
                ),
                _FlowStep(
                  number: 4,
                  title: 'Final na level',
                  formula: 'Ang mas mababa sa dalawang level ang panalo.',
                  fill: Color(0xFFE8F5E9),
                ),
              ];

              Widget arrow() => Center(
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(
                    wide
                        ? Icons.arrow_forward_rounded
                        : Icons.arrow_downward_rounded,
                    color: Colors.black87,
                  ),
                ),
              );

              final List<Widget> items = [];
              for (int i = 0; i < steps.length; i++) {
                if (i > 0) items.add(arrow());
                items.add(wide ? Expanded(child: steps[i]) : steps[i]);
              }

              if (wide) {
                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: items,
                  ),
                );
              }
              return Column(children: items);
            },
          ),
          const SizedBox(height: 16),
          const _ThresholdBar(
            title: 'Word Reading (Pagbasa)',
            ranges: ['0–89%', '90–96%', '97–100%'],
          ),
          const SizedBox(height: 10),
          const _ThresholdBar(
            title: 'Comprehension (Pag-unawa)',
            ranges: ['0–58%', '59–79%', '80–100%'],
          ),
        ],
      ),
    );
  }
}

class _FlowStep extends StatelessWidget {
  final int number;
  final String title;
  final String formula;
  final Color fill;

  const _FlowStep({
    required this.number,
    required this.title,
    required this.formula,
    required this.fill,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 11,
                backgroundColor: Colors.black,
                child: Text(
                  '$number',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(formula, style: const TextStyle(fontSize: 12, height: 1.35)),
        ],
      ),
    );
  }
}

class _ThresholdBar extends StatelessWidget {
  final String title;
  final List<String> ranges; // frustration, instructional, independent

  const _ThresholdBar({required this.title, required this.ranges});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Row(
          children: List.generate(3, (i) {
            final String level = PhilIriTheme.levels[i];
            return Expanded(
              child: Container(
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: PhilIriTheme.colorOf(level),
                  border: Border.all(color: Colors.black, width: 1.5),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${PhilIriTheme.labelOf(level)}\n${ranges[i]}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: PhilIriTheme.onColor(level),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------
// 2. MATRIX: Word Reading level x Comprehension level
// ------------------------------------------------------------
class _MatrixCard extends StatelessWidget {
  final List<_Learner> learners;

  const _MatrixCard({required this.learners});

  static const double _labelWidth = 84;

  void _showNames(BuildContext context, int wrRank, int compRank) {
    final List<_Learner> names = learners
        .where(
          (l) =>
              PhilIriTheme.rank(l.wrLevel) == wrRank &&
              PhilIriTheme.rank(l.compLevel) == compRank,
        )
        .toList();

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Word Reading: ${PhilIriTheme.labelOf(PhilIriTheme.levels[wrRank])}\n'
          'Comprehension: ${PhilIriTheme.labelOf(PhilIriTheme.levels[compRank])}',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
        ),
        content: SizedBox(
          width: 320,
          child: ListView(
            shrinkWrap: true,
            children: names
                .map(
                  (l) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(l.name),
                    trailing: Text(
                      '${l.wr.toStringAsFixed(1)}% • ${l.comp.round()}%',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Isara'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // counts[wrRank][compRank]
    final List<List<int>> counts = List.generate(3, (_) => List.filled(3, 0));
    for (final l in learners) {
      final int w = PhilIriTheme.rank(l.wrLevel);
      final int c = PhilIriTheme.rank(l.compLevel);
      if (w >= 0 && c >= 0) counts[w][c]++;
    }

    Widget headerCell(int compRank) => Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            PhilIriTheme.labelOf(PhilIriTheme.levels[compRank]),
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );

    Widget cell(int wrRank, int compRank) {
      final int count = counts[wrRank][compRank];
      final String finalLevel = PhilIriTheme.levels[math.min(wrRank, compRank)];
      final Color base = PhilIriTheme.colorOf(finalLevel);
      final Color textColor = count == 0
          ? Colors.black38
          : PhilIriTheme.onColor(finalLevel);

      return Expanded(
        child: GestureDetector(
          onTap: count > 0 ? () => _showNames(context, wrRank, compRank) : null,
          child: Container(
            height: 62,
            margin: const EdgeInsets.all(3),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: base.withValues(alpha: count == 0 ? 0.22 : 1.0),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.black, width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: textColor,
                  ),
                ),
                Text('bata', style: TextStyle(fontSize: 10, color: textColor)),
              ],
            ),
          ),
        ),
      );
    }

    return _PanelCard(
      title: 'Saan napunta ang bawat bata',
      subtitle:
          'Ang kulay ng kahon ang final level (mas mababa sa dalawa). '
          'Pindutin ang kahon para makita ang mga pangalan.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: _labelWidth),
            child: Text(
              'COMPREHENSION →',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const SizedBox(width: _labelWidth),
              headerCell(0),
              headerCell(1),
              headerCell(2),
            ],
          ),
          for (final int wrRank in const [2, 1, 0])
            Row(
              children: [
                SizedBox(
                  width: _labelWidth,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        PhilIriTheme.labelOf(PhilIriTheme.levels[wrRank]),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
                cell(wrRank, 0),
                cell(wrRank, 1),
                cell(wrRank, 2),
              ],
            ),
          const SizedBox(height: 6),
          const Text(
            '↑ WORD READING (patayo)',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------
// 3. SCATTER: bawat bata = isang tuldok, may zones ng cutoff
// ------------------------------------------------------------
const double _padL = 40;
const double _padR = 12;
const double _padT = 10;
const double _padB = 30;
const double _yMin = 50;
const double _yMax = 100;

Rect _plotRect(Size s) =>
    Rect.fromLTRB(_padL, _padT, s.width - _padR, s.height - _padB);

Offset _plotPoint(Size s, double comp, double wr) {
  final Rect r = _plotRect(s);
  final double cx = comp.clamp(0.0, 100.0).toDouble();
  final double cy = wr.clamp(_yMin, _yMax).toDouble();
  final double x = r.left + (cx / 100.0) * r.width;
  final double y = r.bottom - ((cy - _yMin) / (_yMax - _yMin)) * r.height;
  return Offset(x, y);
}

void _drawText(
  Canvas canvas,
  String text,
  Offset anchor, {
  double fontSize = 10,
  FontWeight weight = FontWeight.w700,
  Color color = Colors.black87,
  TextAlign align = TextAlign.center,
}) {
  final TextPainter tp = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(fontSize: fontSize, fontWeight: weight, color: color),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  double dx = anchor.dx;
  if (align == TextAlign.center) {
    dx -= tp.width / 2;
  } else if (align == TextAlign.right) {
    dx -= tp.width;
  }
  tp.paint(canvas, Offset(dx, anchor.dy - tp.height / 2));
}

class _ScatterCard extends StatefulWidget {
  final List<_Learner> learners;

  const _ScatterCard({required this.learners});

  @override
  State<_ScatterCard> createState() => _ScatterCardState();
}

class _ScatterCardState extends State<_ScatterCard> {
  static const double _height = 280;
  int? _selected;

  void _onTap(Offset pos, Size size) {
    int? best;
    double bestDist = 18 * 18;
    for (int i = 0; i < widget.learners.length; i++) {
      final _Learner l = widget.learners[i];
      final Offset p = _plotPoint(size, l.comp, l.wr);
      final double d =
          (p.dx - pos.dx) * (p.dx - pos.dx) + (p.dy - pos.dy) * (p.dy - pos.dy);
      if (d <= bestDist) {
        bestDist = d;
        best = i;
      }
    }
    setState(() => _selected = best);
  }

  @override
  Widget build(BuildContext context) {
    final int? sel = _selected;
    final _Learner? picked = (sel != null && sel < widget.learners.length)
        ? widget.learners[sel]
        : null;

    return _PanelCard(
      title: 'Bawat bata: Word Reading laban sa Comprehension',
      subtitle:
          'Bawat tuldok ay isang bata. Ang mga guhit ay ang cutoff, at ang '
          'kulay ng tuldok ang final level.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, c) {
              final Size size = Size(c.maxWidth, _height);
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) => _onTap(d.localPosition, size),
                child: SizedBox(
                  width: size.width,
                  height: size.height,
                  child: CustomPaint(
                    painter: _ScatterPainter(widget.learners, _selected),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 14,
            runSpacing: 4,
            children: [
              for (final String lv in PhilIriTheme.levels)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: PhilIriTheme.colorOf(lv),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black, width: 1.5),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      PhilIriTheme.labelOf(lv),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            picked == null
                ? 'Pindutin ang tuldok para makita ang bata. '
                      '(Ang Word Reading na mas mababa sa 50% ay nasa ilalim na guhit.)'
                : '${picked.name} • Word Reading ${picked.wr.toStringAsFixed(1)}% '
                      '(${PhilIriTheme.labelOf(picked.wrLevel)}) • '
                      'Comprehension ${picked.comp.round()}% '
                      '(${PhilIriTheme.labelOf(picked.compLevel)}) → '
                      '${PhilIriTheme.labelOf(picked.level)}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: picked == null ? FontWeight.w500 : FontWeight.w800,
              color: picked == null ? Colors.black54 : Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScatterPainter extends CustomPainter {
  final List<_Learner> learners;
  final int? selected;

  _ScatterPainter(this.learners, this.selected);

  @override
  void paint(Canvas canvas, Size size) {
    final Rect r = _plotRect(size);

    // Zones: kulay ng bawat kahon = mas mababa sa dalawang level
    const List<double> compEdges = [0.0, 59.0, 80.0, 100.0];
    const List<double> wrEdges = [_yMin, 90.0, 97.0, _yMax];
    for (int wrB = 0; wrB < 3; wrB++) {
      for (int cB = 0; cB < 3; cB++) {
        final double x0 = r.left + compEdges[cB] / 100.0 * r.width;
        final double x1 = r.left + compEdges[cB + 1] / 100.0 * r.width;
        final double yTop = _plotPoint(size, 0, wrEdges[wrB + 1]).dy;
        final double yBottom = _plotPoint(size, 0, wrEdges[wrB]).dy;
        final String level = PhilIriTheme.levels[math.min(wrB, cB)];
        canvas.drawRect(
          Rect.fromLTRB(x0, yTop, x1, yBottom),
          Paint()..color = PhilIriTheme.colorOf(level).withValues(alpha: 0.22),
        );
      }
    }

    // Cutoff lines
    final Paint linePaint = Paint()
      ..color = Colors.black54
      ..strokeWidth = 1;
    for (final double cut in const [59.0, 80.0]) {
      final double x = r.left + cut / 100.0 * r.width;
      canvas.drawLine(Offset(x, r.top), Offset(x, r.bottom), linePaint);
    }
    for (final double cut in const [90.0, 97.0]) {
      final double y = _plotPoint(size, 0, cut).dy;
      canvas.drawLine(Offset(r.left, y), Offset(r.right, y), linePaint);
    }

    // Frame
    canvas.drawRect(
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.black,
    );

    // Tick labels (x)
    for (final double v in const [0.0, 59.0, 80.0, 100.0]) {
      final double x = r.left + v / 100.0 * r.width;
      _drawText(canvas, '${v.toInt()}', Offset(x, r.bottom + 10), fontSize: 9);
    }
    // Tick labels (y)
    final List<MapEntry<double, String>> yTicks = const [
      MapEntry(50.0, '≤50'),
      MapEntry(90.0, '90'),
      MapEntry(97.0, '97'),
      MapEntry(100.0, '100'),
    ];
    for (final MapEntry<double, String> t in yTicks) {
      final double y = _plotPoint(size, 0, t.key).dy;
      _drawText(
        canvas,
        t.value,
        Offset(r.left - 4, y),
        fontSize: 9,
        align: TextAlign.right,
      );
    }

    // Axis titles
    _drawText(
      canvas,
      'Comprehension %',
      Offset(r.center.dx, r.bottom + 23),
      fontSize: 10,
      weight: FontWeight.w900,
    );
    canvas.save();
    canvas.translate(9, r.center.dy);
    canvas.rotate(-math.pi / 2);
    _drawText(
      canvas,
      'Word Reading %',
      Offset.zero,
      fontSize: 10,
      weight: FontWeight.w900,
    );
    canvas.restore();

    // Points (ang napili ay huling iginuhit para nasa ibabaw)
    void drawPoint(int i, {required bool isSelected}) {
      final _Learner l = learners[i];
      final Offset p = _plotPoint(size, l.comp, l.wr);
      canvas.drawCircle(
        p,
        isSelected ? 9 : 6,
        Paint()..color = PhilIriTheme.colorOf(l.level),
      );
      canvas.drawCircle(
        p,
        isSelected ? 9 : 6,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = isSelected ? 2.5 : 1.5
          ..color = Colors.black,
      );
    }

    for (int i = 0; i < learners.length; i++) {
      if (i != selected) drawPoint(i, isSelected: false);
    }
    final int? sel = selected;
    if (sel != null && sel < learners.length) drawPoint(sel, isSelected: true);
  }

  @override
  bool shouldRepaint(covariant _ScatterPainter old) =>
      old.learners != learners || old.selected != selected;
}

// ------------------------------------------------------------
// 4. DONUT: kabuuang bilang kada level
// ------------------------------------------------------------
class _DonutCard extends StatelessWidget {
  final Map<String, dynamic> summary;

  const _DonutCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final List<int> values = [
      _asInt(summary['frustration_count']),
      _asInt(summary['instructional_count']),
      _asInt(summary['independent_count']),
    ];
    final int total = values.fold<int>(0, (a, b) => a + b);

    return _PanelCard(
      title: 'Kabuuang bilang ng mga bata',
      subtitle: 'Isang bata = isang bilang (average ng lahat ng stories niya).',
      child: Column(
        children: [
          SizedBox(
            width: 190,
            height: 190,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(190, 190),
                  painter: _DonutPainter(
                    values.map((v) => v.toDouble()).toList(),
                    PhilIriTheme.levels
                        .map((l) => PhilIriTheme.colorOf(l))
                        .toList(),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$total',
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Text(
                      'bata',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          for (int i = 0; i < 3; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: PhilIriTheme.colorOf(PhilIriTheme.levels[i]),
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: Colors.black, width: 1.5),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      PhilIriTheme.labelOf(PhilIriTheme.levels[i]),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    total == 0
                        ? '${values[i]}'
                        : '${values[i]}  (${(values[i] * 100 / total).round()}%)',
                    style: const TextStyle(
                      fontSize: 13,
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
}

class _DonutPainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;

  _DonutPainter(this.values, this.colors);

  @override
  void paint(Canvas canvas, Size size) {
    final double total = values.fold<double>(0, (a, b) => a + b);
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = math.min(size.width, size.height) / 2 - 2;
    final double stroke = radius * 0.38;
    final Rect rect = Rect.fromCircle(
      center: center,
      radius: radius - stroke / 2,
    );

    final Paint ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;

    if (total <= 0) {
      ring.color = Colors.black12;
      canvas.drawArc(rect, 0, math.pi * 2, false, ring);
    } else {
      double start = -math.pi / 2;
      for (int i = 0; i < values.length; i++) {
        if (values[i] <= 0) continue;
        final double sweep = values[i] / total * math.pi * 2;
        ring.color = colors[i];
        canvas.drawArc(rect, start, sweep, false, ring);
        start += sweep;
      }
    }

    final Paint outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = Colors.black;
    canvas.drawCircle(center, radius, outline);
    canvas.drawCircle(center, radius - stroke, outline);
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.values != values || old.colors != colors;
}

// ------------------------------------------------------------
// 5. BUOD BAWAT KLASE (100% stacked bar + average ng computation)
// ------------------------------------------------------------
class _ClassSummaryCard extends StatelessWidget {
  final Map<String, dynamic> summary;

  const _ClassSummaryCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final List raw = (summary['class_breakdown'] as List?) ?? const [];

    Widget segment(int count, String level) {
      if (count <= 0) return const SizedBox.shrink();
      return Expanded(
        flex: count,
        child: Container(
          alignment: Alignment.center,
          color: PhilIriTheme.colorOf(level),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: PhilIriTheme.onColor(level),
            ),
          ),
        ),
      );
    }

    final List<Widget> rows = [];
    for (final item in raw) {
      if (item is! Map) continue;
      final String label = '${item['label'] ?? ''}'.isEmpty
          ? 'Class ${item['class_id'] ?? ''}'
          : '${item['label']}';
      final int fr = _asInt(item['frustration']);
      final int ins = _asInt(item['instructional']);
      final int ind = _asInt(item['independent']);
      final int total = fr + ins + ind;
      final double? avgWr = _asDouble(item['avg_accuracy']);
      final double? avgComp = _asDouble(item['avg_comprehension']);

      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Text(
                    '$total bata',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Container(
                height: 28,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black, width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: total == 0
                      ? const Center(
                          child: Text(
                            'Wala pang resulta',
                            style: TextStyle(fontSize: 11),
                          ),
                        )
                      : Row(
                          children: [
                            segment(fr, 'frustration'),
                            segment(ins, 'instructional'),
                            segment(ind, 'independent'),
                          ],
                        ),
                ),
              ),
              if (avgWr != null && avgComp != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Average Word Reading ${avgWr.toStringAsFixed(1)}% • '
                  'Average Comprehension ${avgComp.round()}%',
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return _PanelCard(
      title: 'Buod ng bawat klase',
      subtitle:
          'Hati ng mga level sa loob ng klase, kasama ang average na score.',
      child: rows.isEmpty
          ? const Text(
              'Wala pang datos ng klase.',
              style: TextStyle(fontSize: 13),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: rows,
            ),
    );
  }
}
