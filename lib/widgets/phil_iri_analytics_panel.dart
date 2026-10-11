import 'package:flutter/material.dart';

// ============================================================
// Phil-IRI analytics panel (simple version)
//
// Dalawang malinaw na card lang, malalaking letra, walang acronym:
//   1. "Saan kailangan ng tulong?"  -> pangalan ng mga bata, hiwalay ang
//      Word Reading (pagbasa) at Comprehension (pag-unawa)
//   2. "Bawat klase"                -> hati ng level + average ng bawat klase
//
// Ang lahat ng level ay galing sa backend (PhilIriService); dito lang ito
// ipinapakita.
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
// Guide kung paano nakukuwenta ang Phil-IRI level: lalabas lang
// bilang pop-out kapag pinindot ang (i) para hindi abala sa analytics.
// ------------------------------------------------------------
void showPhilIriGuide(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Colors.black, width: 3),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                tooltip: 'Close',
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: const _FlowCard(),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// ------------------------------------------------------------
// Pre/Post filter (pamalit sa SegmentedButton na nagsisingit ang text)
// ------------------------------------------------------------
class PhilIriTestTypeFilter extends StatelessWidget {
  final String value; // 'pre_test' | 'post_test'
  final ValueChanged<String> onChanged;

  /// true = patayong "side tabs" (para sa malapad na screen, nasa gilid).
  final bool vertical;

  const PhilIriTestTypeFilter({
    super.key,
    required this.value,
    required this.onChanged,
    this.vertical = false,
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
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: selected ? Colors.white : PhilIriTheme.ink,
          ),
        ),
        selected: selected,
        showCheckmark: false,
        labelPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        selectedColor: PhilIriTheme.maroon,
        backgroundColor: Colors.white,
        side: const BorderSide(color: Colors.black, width: 2),
        onSelected: (_) => onChanged(key),
      );
    }

    if (vertical) {
      Widget tab(String key, String label) {
        final bool selected = value == key;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: selected ? PhilIriTheme.maroon : Colors.white,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => onChanged(key),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black, width: 2),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: selected ? Colors.white : PhilIriTheme.ink,
                  ),
                ),
              ),
            ),
          ),
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          tab('pre_test', 'Pre-Test'),
          tab('post_test', 'Post-Test'),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: PhilIriTheme.maroon,
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
              icon: const Icon(Icons.info_outline_rounded, size: 18),
              label: const Text(
                'Paano nakukuwenta?',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
              ),
              onPressed: () => showPhilIriGuide(context),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Average ng lahat ng natapos na stories ng bawat bata.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.black87,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            chip('pre_test', 'Pre-Test'),
            chip('post_test', 'Post-Test'),
            IconButton(
              tooltip: 'Paano nakukuwenta ang level',
              visualDensity: VisualDensity.compact,
              color: PhilIriTheme.maroon,
              icon: const Icon(Icons.info_outline_rounded),
              onPressed: () => showPhilIriGuide(context),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Average ng lahat ng natapos na stories ng bawat bata.',
          style: TextStyle(
            fontSize: 14,
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
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

    if (learners.isEmpty) {
      return _PanelCard(
        title: 'Wala pang resulta para sa $testLabel',
        subtitle: null,
        child: const Text(
          'Lalabas dito ang resulta kapag may natapos nang kuwento at '
          'pagsusulit ang mga bata.',
          style: TextStyle(fontSize: 16, height: 1.4),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _NeedHelpCard(learners: learners),
        const SizedBox(height: 16),
        _ClassSummaryCard(summary: summary),
      ],
    );
  }
}

// ------------------------------------------------------------
// Puting card (nababasa kahit magulo ang background)
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black, width: 2.5),
        boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(4, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: PhilIriTheme.ink,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: const TextStyle(
                fontSize: 15,
                color: Colors.black87,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

// ------------------------------------------------------------
// Kahulugan ng kulay (laging nakikita, hindi kailangang hulaan)
// ------------------------------------------------------------
class _LevelLegend extends StatelessWidget {
  const _LevelLegend();

  @override
  Widget build(BuildContext context) {
    Widget item(String level, String meaning) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: PhilIriTheme.colorOf(level),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.black, width: 1.5),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${PhilIriTheme.labelOf(level)} - $meaning',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ],
    );

    return Wrap(
      spacing: 18,
      runSpacing: 8,
      children: [
        item('frustration', 'kailangan ng tulong'),
        item('instructional', 'kailangan ng gabay'),
        item('independent', 'magaling na'),
      ],
    );
  }
}

// ------------------------------------------------------------
// 1. SAAN KAILANGAN NG TULONG? (pangalan agad, hindi na kailangang pindutin)
// ------------------------------------------------------------
class _NeedHelpCard extends StatelessWidget {
  final List<_Learner> learners;

  const _NeedHelpCard({required this.learners});

  Widget _section({
    required String title,
    required String hint,
    required IconData icon,
    required List<_Learner> weak,
    required String Function(_Learner) levelOf,
  }) {
    final bool none = weak.isEmpty;
    final List<_Learner> sorted = [...weak]
      ..sort((a, b) {
        final c = PhilIriTheme.rank(
          levelOf(a),
        ).compareTo(PhilIriTheme.rank(levelOf(b)));
        return c != 0 ? c : a.name.compareTo(b.name);
      });

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: none ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 32, color: PhilIriTheme.ink),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: none
                      ? PhilIriTheme.independent
                      : PhilIriTheme.frustration,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.black, width: 2),
                ),
                child: Text(
                  '${weak.length}',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: none ? Colors.black : Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(hint, style: const TextStyle(fontSize: 15, height: 1.3)),
          const SizedBox(height: 12),
          if (none)
            const Text(
              'Magaling ang lahat ng bata dito.',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final l in sorted)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: PhilIriTheme.colorOf(levelOf(l)),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.black, width: 1.5),
                    ),
                    child: Text(
                      l.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: PhilIriTheme.onColor(levelOf(l)),
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final weakWr = learners
        .where((l) => PhilIriTheme.rank(l.wrLevel) < 2)
        .toList();
    final weakComp = learners
        .where((l) => PhilIriTheme.rank(l.compLevel) < 2)
        .toList();

    return _PanelCard(
      title: 'Saan kailangan ng tulong?',
      subtitle: 'Ang kulay ng pangalan ay ang level ng bata sa bahaging iyon.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _LevelLegend(),
          const SizedBox(height: 14),
          _section(
            title: 'Word Reading',
            hint: 'Mga batang kailangang tulungan sa pagbasa ng mga salita.',
            icon: Icons.record_voice_over_rounded,
            weak: weakWr,
            levelOf: (l) => l.wrLevel,
          ),
          _section(
            title: 'Comprehension',
            hint: 'Mga batang kailangang tulungan sa pag-unawa ng binasa.',
            icon: Icons.lightbulb_rounded,
            weak: weakComp,
            levelOf: (l) => l.compLevel,
          ),
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
      title: 'Paano nakukuwenta ang level',
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
                radius: 14,
                backgroundColor: Colors.black,
                child: Text(
                  '$number',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(formula, style: const TextStyle(fontSize: 14, height: 1.35)),
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
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Row(
          children: List.generate(3, (i) {
            final String level = PhilIriTheme.levels[i];
            return Expanded(
              child: Container(
                height: 58,
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
                      fontSize: 14,
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
// 2. BAWAT KLASE
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
              fontSize: 22,
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
      String label = '${item['label'] ?? ''}'.isEmpty
          ? 'Class ${item['class_id'] ?? ''}'
          : '${item['label']}';
      // "Grade Grade 5 - AQUINO" -> "Grade 5 - AQUINO"
      label = label.replaceFirst(
        RegExp(r'^Grade\s+Grade\s+', caseSensitive: false),
        'Grade ',
      );
      final int fr = _asInt(item['frustration']);
      final int ins = _asInt(item['instructional']);
      final int ind = _asInt(item['independent']);
      final int total = fr + ins + ind;
      final double? avgWr = _asDouble(item['avg_accuracy']);
      final double? avgComp = _asDouble(item['avg_comprehension']);

      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Text(
                    '$total bata',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                height: 52,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black, width: 2.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: total == 0
                      ? const Center(
                          child: Text(
                            'Wala pang resulta',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
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
                const SizedBox(height: 8),
                Text(
                  'Average Word Reading: ${avgWr.toStringAsFixed(1)}%',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Average Comprehension: ${avgComp.round()}%',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return _PanelCard(
      title: 'Bawat klase',
      subtitle: 'Ilang bata sa bawat level, at ang average na score ng klase.',
      child: rows.isEmpty
          ? const Text(
              'Wala pang datos ng klase.',
              style: TextStyle(fontSize: 16),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _LevelLegend(),
                const SizedBox(height: 16),
                ...rows,
              ],
            ),
    );
  }
}
