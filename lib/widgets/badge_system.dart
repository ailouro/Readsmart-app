// lib/widgets/badge_system.dart
//
// Self-contained XP + Badges feature for the student dashboard.
//
//   * ReadingBadge      -> the "shape" of one badge (icon, color, XP needed)
//   * kAllBadges        -> the full badge roster (add more here anytime)
//   * calculateXpFromProgress() -> turns completed-story logs into XP
//   * XpAndBadgesSection -> the widget you drop into a screen: XP bar on
//     top + a checklist-style grid of badges below (locked ones are greyed
//     out with a padlock, like a physical badge-checklist card).
//   * maybeShowBadgeUnlockedDialog() -> pops a small celebration dialog the
//     first time a badge is newly earned (remembered via SharedPreferences
//     so it only shows once per badge per student).
//
// Nothing here talks to the network -- pass it whatever progress list you
// already have (e.g. the same list used for "My Library").

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// -----------------------------------------------------------------------
// 1. BADGE DEFINITIONS
// -----------------------------------------------------------------------

/// One badge: how it looks, its name, the hint shown while locked, and the
/// XP total needed to unlock it.
class ReadingBadge {
  final String id;
  final String title;
  final String hint;
  final IconData icon;
  final Color color;
  final int xpRequired;

  const ReadingBadge({
    required this.id,
    required this.title,
    required this.hint,
    required this.icon,
    required this.color,
    required this.xpRequired,
  });
}

/// The full badge roster, ordered from easiest to hardest. Everything else
/// (locking, the XP bar, the grid) reads from this list automatically, so
/// adding a 13th badge is just adding one more line here.
const List<ReadingBadge> kAllBadges = [
  ReadingBadge(
    id: 'first_chapter',
    title: 'First Chapter',
    hint: 'Finish your very first story',
    icon: Icons.menu_book_rounded,
    color: Color(0xFF66BB6A), // green
    xpRequired: 20,
  ),
  ReadingBadge(
    id: 'story_starter',
    title: 'Story Starter',
    hint: 'Earn 60 XP',
    icon: Icons.bookmark_rounded,
    color: Color(0xFF42A5F5), // blue
    xpRequired: 60,
  ),
  ReadingBadge(
    id: 'bookworm',
    title: 'Bookworm',
    hint: 'Earn 120 XP',
    icon: Icons.auto_stories_rounded,
    color: Color(0xFF8D6E63), // brown
    xpRequired: 120,
  ),
  ReadingBadge(
    id: 'quiz_whiz',
    title: 'Quiz Whiz',
    hint: 'Earn 200 XP',
    icon: Icons.fact_check_rounded,
    color: Color(0xFF26A69A), // teal
    xpRequired: 200,
  ),
  ReadingBadge(
    id: 'word_wizard',
    title: 'Word Wizard',
    hint: 'Earn 300 XP',
    icon: Icons.auto_fix_high_rounded,
    color: Color(0xFFAB47BC), // purple
    xpRequired: 300,
  ),
  ReadingBadge(
    id: 'speedy_reader',
    title: 'Speedy Reader',
    hint: 'Earn 420 XP',
    icon: Icons.bolt_rounded,
    color: Color(0xFFFFCA28), // amber
    xpRequired: 420,
  ),
  ReadingBadge(
    id: 'brave_reader',
    title: 'Brave Reader',
    hint: 'Earn 560 XP',
    icon: Icons.shield_rounded,
    color: Color(0xFF9B0505), // maroon
    xpRequired: 560,
  ),
  ReadingBadge(
    id: 'explorer',
    title: 'Library Explorer',
    hint: 'Earn 720 XP',
    icon: Icons.explore_rounded,
    color: Color(0xFFFF8A65), // coral
    xpRequired: 720,
  ),
  ReadingBadge(
    id: 'streak',
    title: 'Reading Streak',
    hint: 'Earn 900 XP',
    icon: Icons.local_fire_department_rounded,
    color: Color(0xFFFF7043), // deep orange
    xpRequired: 900,
  ),
  ReadingBadge(
    id: 'independent',
    title: 'Independent Explorer',
    hint: 'Earn 1100 XP',
    icon: Icons.rocket_launch_rounded,
    color: Color(0xFF29B6F6), // sky blue
    xpRequired: 1100,
  ),
  ReadingBadge(
    id: 'super_reader',
    title: 'Super Reader',
    hint: 'Earn 1350 XP',
    icon: Icons.star_rounded,
    color: Color(0xFFEF5350), // red
    xpRequired: 1350,
  ),
  ReadingBadge(
    id: 'champion',
    title: 'Class Champion',
    hint: 'Earn 1600 XP',
    icon: Icons.emoji_events_rounded,
    color: Color(0xFFFFD54F), // gold
    xpRequired: 1600,
  ),
];

// -----------------------------------------------------------------------
// 2. XP CALCULATION
// -----------------------------------------------------------------------

/// Turns a list of completed-story progress logs (the same shape returned
/// by `/api/student/<id>/completed-stories`, i.e. what StudentProgress::
/// completedStoriesFor() returns) into a single XP total.
///
/// Points awarded per finished story -- tweak these weights freely, they
/// only need fields that already exist on StudentProgress:
///   +10  just for finishing the story
///   +2   per correct quiz answer (quiz_score)
///   +10  bonus if the quiz was a perfect score
///   +20 / +10 / +5  bonus depending on reading_level
///       (independent / instructional / frustration)
int calculateXpFromProgress(List<dynamic> progressLogs) {
  int xp = 0;

  for (final raw in progressLogs) {
    if (raw is! Map) continue;
    final log = raw;

    xp += 10; // base credit for finishing a story

    final int quizScore = int.tryParse('${log['quiz_score'] ?? 0}') ?? 0;
    final int totalQuestions =
        int.tryParse('${log['total_questions'] ?? 0}') ?? 0;
    xp += quizScore * 2;
    if (totalQuestions > 0 && quizScore >= totalQuestions) {
      xp += 10; // perfect quiz bonus
    }

    final String level = (log['reading_level'] ?? '').toString();
    switch (level) {
      case 'independent':
        xp += 20;
        break;
      case 'instructional':
        xp += 10;
        break;
      case 'frustration':
        xp += 5; // still credit for trying
        break;
    }
  }

  return xp;
}

/// The badge just below/at [totalXp], or null if every badge is unlocked.
ReadingBadge? nextBadgeToUnlock(int totalXp) {
  for (final b in kAllBadges) {
    if (totalXp < b.xpRequired) return b;
  }
  return null;
}

// -----------------------------------------------------------------------
// 3. WIDGETS
// -----------------------------------------------------------------------

/// Drop-in section: XP bar + badge checklist grid. Give it the student's
/// completed-story logs; it does the XP math and the locking itself.
class XpAndBadgesSection extends StatelessWidget {
  final List<dynamic> progressLogs;
  final Color accentColor;
  final Color themeColor;

  const XpAndBadgesSection({
    super.key,
    required this.progressLogs,
    this.accentColor = const Color(0xFFFDE047),
    this.themeColor = const Color(0xFF9B0505),
  });

  @override
  Widget build(BuildContext context) {
    final int totalXp = calculateXpFromProgress(progressLogs);
    final ReadingBadge? next = nextBadgeToUnlock(totalXp);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _XpBar(
          totalXp: totalXp,
          next: next,
          themeColor: themeColor,
          accentColor: accentColor,
        ),
        const SizedBox(height: 14),
        _BadgeGrid(totalXp: totalXp, accentColor: accentColor),
      ],
    );
  }
}

class _XpBar extends StatelessWidget {
  final int totalXp;
  final ReadingBadge? next;
  final Color themeColor;
  final Color accentColor;

  const _XpBar({
    required this.totalXp,
    required this.next,
    required this.themeColor,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    // Progress toward the next badge (0..1). If every badge is unlocked,
    // just show a full bar.
    final int prevThreshold = _prevThreshold();
    final double progress = next == null
        ? 1.0
        : ((totalXp - prevThreshold) / (next!.xpRequired - prevThreshold))
              .clamp(0.0, 1.0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black, width: 3),
        boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(4, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black, width: 2),
                ),
                child: const Icon(
                  Icons.star_rounded,
                  size: 20,
                  color: Colors.black,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                "$totalXp XP",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: themeColor,
                ),
              ),
              const Spacer(),
              if (next != null)
                Text(
                  "${next!.xpRequired - totalXp} XP to ${next!.title}",
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.black54,
                  ),
                )
              else
                const Text(
                  "All badges unlocked! 🎉",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.black54,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 14,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation(themeColor),
            ),
          ),
        ],
      ),
    );
  }

  int _prevThreshold() {
    int prev = 0;
    for (final b in kAllBadges) {
      if (next != null && b.id == next!.id) break;
      prev = b.xpRequired;
    }
    return prev;
  }
}

class _BadgeGrid extends StatelessWidget {
  final int totalXp;
  final Color accentColor;

  const _BadgeGrid({required this.totalXp, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black, width: 3),
        boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(4, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "🏅 My Badges",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 2),
          const Text(
            "Keep reading to unlock the ones still locked!",
            style: TextStyle(fontSize: 11, color: Colors.black54),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: kAllBadges.map((b) {
              final bool unlocked = totalXp >= b.xpRequired;
              return _BadgeTile(badge: b, unlocked: unlocked);
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _BadgeTile extends StatelessWidget {
  final ReadingBadge badge;
  final bool unlocked;

  const _BadgeTile({required this.badge, required this.unlocked});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 84,
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              _BadgeIcon(badge: badge, unlocked: unlocked),
              if (unlocked)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF43A047),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: const Icon(
                      Icons.check,
                      size: 11,
                      color: Colors.white,
                    ),
                  ),
                )
              else
                Positioned(
                  bottom: -2,
                  right: -2,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade700,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: const Icon(
                      Icons.lock_rounded,
                      size: 11,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            badge.title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
              color: unlocked ? Colors.black : Colors.grey.shade500,
            ),
          ),
          if (!unlocked)
            Text(
              badge.hint,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9,
                fontStyle: FontStyle.italic,
                color: Colors.grey.shade500,
              ),
            ),
        ],
      ),
    );
  }
}

/// The circular "patch" itself. Unlocked = full color; locked = greyed out
/// silhouette (same shape/icon, just desaturated) so the student can still
/// tell what the badge *will* look like once earned, matching a printed
/// badge-checklist card where every slot is visible from day one.
class _BadgeIcon extends StatelessWidget {
  final ReadingBadge badge;
  final bool unlocked;

  const _BadgeIcon({required this.badge, required this.unlocked});

  static const List<double> _grayscale = <double>[
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ];

  @override
  Widget build(BuildContext context) {
    final Widget patch = Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: badge.color,
        border: Border.all(color: Colors.black, width: 3),
        boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(2, 2))],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.85),
                width: 2,
              ),
            ),
          ),
          Icon(
            badge.icon,
            color: Colors.white,
            size: 28,
            shadows: const [
              Shadow(color: Colors.black38, offset: Offset(1, 1)),
            ],
          ),
        ],
      ),
    );

    if (unlocked) return patch;

    return Opacity(
      opacity: 0.55,
      child: ColorFiltered(
        colorFilter: const ColorFilter.matrix(_grayscale),
        child: patch,
      ),
    );
  }
}

// -----------------------------------------------------------------------
// 4. "NEWLY UNLOCKED" CELEBRATION
// -----------------------------------------------------------------------

String _seenBadgesKey(int studentId) => 'seen_badges_$studentId';

/// Call this after loading progress (e.g. right after _fetchMyLibrary
/// finishes). Diffs the currently-unlocked badges against the ones already
/// shown before (saved per-student in SharedPreferences) and, if there are
/// new ones, pops a small celebration dialog for each -- this is the
/// "biglang lalabas sa dashboard" moment the student sees the first time
/// they cross a badge's XP threshold.
Future<void> maybeShowBadgeUnlockedDialog(
  BuildContext context,
  int studentId,
  List<dynamic> progressLogs,
) async {
  final int totalXp = calculateXpFromProgress(progressLogs);
  final unlockedNow = kAllBadges.where((b) => totalXp >= b.xpRequired).toList();

  final prefs = await SharedPreferences.getInstance();
  final key = _seenBadgesKey(studentId);
  final List<String> seen = prefs.getStringList(key) ?? <String>[];
  final Set<String> seenSet = seen.toSet();

  final newlyUnlocked = unlockedNow
      .where((b) => !seenSet.contains(b.id))
      .toList();

  // Mark everything currently unlocked as "seen" right away so the dialog
  // never repeats, even if the student backs out mid-celebration.
  await prefs.setStringList(key, unlockedNow.map((b) => b.id).toList());

  if (newlyUnlocked.isEmpty || !context.mounted) return;

  for (final badge in newlyUnlocked) {
    if (!context.mounted) return;
    await showDialog(
      context: context,
      builder: (_) => _BadgeUnlockedDialog(badge: badge),
    );
  }
}

class _BadgeUnlockedDialog extends StatelessWidget {
  final ReadingBadge badge;
  const _BadgeUnlockedDialog({required this.badge});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Colors.black, width: 3.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "BADGE UNLOCKED!",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: Color(0xFF9B0505),
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 16),
            _BadgeIcon(badge: badge, unlocked: true),
            const SizedBox(height: 16),
            Text(
              badge.title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              badge.hint,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: badge.color,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: const BorderSide(color: Colors.black, width: 2),
                ),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text(
                "Yay!",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
