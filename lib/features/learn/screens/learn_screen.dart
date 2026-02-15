import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../models/lesson_data.dart';
import '../providers/learn_provider.dart';

/// Learn screen — structured learning paths, lesson reader, glossary.
class LearnScreen extends ConsumerStatefulWidget {
  const LearnScreen({super.key});

  @override
  ConsumerState<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends ConsumerState<LearnScreen> {
  /// Currently open lesson (null = browsing paths).
  Lesson? _openLesson;
  LearningPath? _openLessonPath;

  /// Whether the glossary section is expanded.
  bool _glossaryExpanded = false;

  /// Search query for glossary.
  String _glossaryQuery = '';

  void _openLessonDetail(Lesson lesson, LearningPath path) {
    setState(() {
      _openLesson = lesson;
      _openLessonPath = path;
    });
  }

  void _closeLessonDetail() {
    setState(() {
      _openLesson = null;
      _openLessonPath = null;
    });
  }

  /// Returns the next lesson (and its path) after the current one, or null.
  ({Lesson lesson, LearningPath path})? _getNextLesson() {
    if (_openLesson == null || _openLessonPath == null) return null;

    final currentPath = _openLessonPath!;
    final currentIndex =
        currentPath.lessons.indexWhere((l) => l.id == _openLesson!.id);

    // Next lesson in the same path
    if (currentIndex >= 0 && currentIndex < currentPath.lessons.length - 1) {
      return (
        lesson: currentPath.lessons[currentIndex + 1],
        path: currentPath,
      );
    }

    // First lesson of the next path
    final pathIndex =
        allLearningPaths.indexWhere((p) => p.id == currentPath.id);
    if (pathIndex >= 0 && pathIndex < allLearningPaths.length - 1) {
      final nextPath = allLearningPaths[pathIndex + 1];
      if (nextPath.lessons.isNotEmpty) {
        return (lesson: nextPath.lessons.first, path: nextPath);
      }
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final learn = ref.watch(learnProvider);

    if (_openLesson != null) {
      final next = _getNextLesson();
      return _LessonDetailView(
        lesson: _openLesson!,
        path: _openLessonPath!,
        isCompleted: learn.isCompleted(_openLesson!.id),
        onBack: _closeLessonDetail,
        onMarkComplete: () {
          ref.read(learnProvider.notifier).markCompleted(_openLesson!.id);
        },
        onGoToNext: next != null
            ? () => _openLessonDetail(next.lesson, next.path)
            : null,
      );
    }

    return _buildBrowseView(context, learn);
  }

  Widget _buildBrowseView(BuildContext context, LearnState learn) {
    final isMobile = Responsive.isMobile(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 64),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 32),

          // ── Hero ──────────────────────────────────────────────
          Padding(
            padding: Responsive.horizontalPadding(context),
            child: _LearnHero(learn: learn, isMobile: isMobile),
          ),
          const SizedBox(height: 40),

          // ── Learning Paths ────────────────────────────────────
          for (final path in allLearningPaths) ...[
            _PathSection(
              path: path,
              learn: learn,
              isMobile: isMobile,
              onOpenLesson: (lesson) => _openLessonDetail(lesson, path),
            ),
            const SizedBox(height: 32),
          ],

          // ── Quick Tips ────────────────────────────────────────
          Padding(
            padding: Responsive.horizontalPadding(context),
            child: _QuickTips(isMobile: isMobile),
          ),
          const SizedBox(height: 32),

          // ── Glossary ──────────────────────────────────────────
          Padding(
            padding: Responsive.horizontalPadding(context),
            child: _buildGlossary(context),
          ),
        ],
      ),
    );
  }

  Widget _buildGlossary(BuildContext context) {
    final filtered = _glossaryQuery.isEmpty
        ? allGlossaryTerms
        : allGlossaryTerms
            .where((t) =>
                t.term.toLowerCase().contains(_glossaryQuery.toLowerCase()) ||
                t.definition
                    .toLowerCase()
                    .contains(_glossaryQuery.toLowerCase()))
            .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        InkWell(
          onTap: () =>
              setState(() => _glossaryExpanded = !_glossaryExpanded),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.info.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child:
                    const Icon(Icons.menu_book_rounded, color: AppTheme.info, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Trading Glossary',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceAlt,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${allGlossaryTerms.length} terms',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                _glossaryExpanded
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
                color: AppTheme.textTertiary,
              ),
            ],
          ),
        ),

        if (_glossaryExpanded) ...[
          const SizedBox(height: 16),

          // Search
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.border),
            ),
            child: TextField(
              onChanged: (v) => setState(() => _glossaryQuery = v),
              style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search terms...',
                hintStyle: GoogleFonts.inter(
                    fontSize: 13, color: AppTheme.textTertiary),
                prefixIcon: const Icon(Icons.search_rounded,
                    size: 18, color: AppTheme.textTertiary),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Terms
          Container(
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              border: Border.all(color: AppTheme.border),
            ),
            child: filtered.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        'No terms match "$_glossaryQuery"',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppTheme.textTertiary,
                        ),
                      ),
                    ),
                  )
                : Column(
                    children: [
                      for (int i = 0; i < filtered.length; i++) ...[
                        if (i > 0)
                          const Divider(height: 1, color: AppTheme.border),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 140,
                                child: Text(
                                  filtered[i].term,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.solanaPurpleLight,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  filtered[i].definition,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: AppTheme.textSecondary,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Hero Card with Progress
// ═══════════════════════════════════════════════════════════════════════════════

class _LearnHero extends StatelessWidget {
  final LearnState learn;
  final bool isMobile;

  const _LearnHero({required this.learn, required this.isMobile});

  @override
  Widget build(BuildContext context) {
    final pct = (learn.progressPercent * 100).round();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1C1F2E), Color(0xFF1B2D69), Color(0xFF1D3A8E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        boxShadow: [
          BoxShadow(
            color: AppTheme.info.withValues(alpha: 0.12),
            blurRadius: 40,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Decorative orb
          Positioned(
            top: -30,
            right: -20,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.info.withValues(alpha: 0.15),
                    AppTheme.info.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -15,
            left: -15,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.solanaGreen.withValues(alpha: 0.08),
                    AppTheme.solanaGreen.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),

          Padding(
            padding: EdgeInsets.all(isMobile ? 24 : 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.school_rounded,
                        color: Colors.white54, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'SolFight Academy',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white54,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Learn to Trade',
                  style: GoogleFonts.inter(
                    fontSize: isMobile ? 28 : 36,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -1,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Master chart reading, strategies, and risk management to dominate the Arena.',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.5),
                    height: 1.5,
                  ),
                ),
                SizedBox(height: isMobile ? 20 : 24),

                // Progress bar
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Your Progress',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${learn.completedCount}/${learn.totalLessons} lessons',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.info,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: learn.progressPercent,
                          minHeight: 8,
                          backgroundColor:
                              Colors.white.withValues(alpha: 0.08),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            learn.progressPercent == 1
                                ? AppTheme.solanaGreen
                                : AppTheme.info,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        learn.progressPercent == 1
                            ? 'All lessons complete — you\'re a SolFight pro!'
                            : '$pct% complete — keep going!',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.35),
                        ),
                      ),
                    ],
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

// ═══════════════════════════════════════════════════════════════════════════════
// Learning Path Section
// ═══════════════════════════════════════════════════════════════════════════════

class _PathSection extends StatelessWidget {
  final LearningPath path;
  final LearnState learn;
  final bool isMobile;
  final void Function(Lesson) onOpenLesson;

  const _PathSection({
    required this.path,
    required this.learn,
    required this.isMobile,
    required this.onOpenLesson,
  });

  @override
  Widget build(BuildContext context) {
    final completed = learn.completedInPath(path);
    final total = path.lessons.length;

    return Padding(
      padding: Responsive.horizontalPadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Path header
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: path.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(path.icon, color: path.color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            path.title,
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: path.color.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            path.tag,
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: path.color,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      path.description,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppTheme.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Progress chip
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: completed == total
                      ? AppTheme.success.withValues(alpha: 0.1)
                      : AppTheme.surfaceAlt,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$completed/$total',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: completed == total
                        ? AppTheme.success
                        : AppTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Lesson cards
          ...path.lessons.map((lesson) {
            final done = learn.isCompleted(lesson.id);
            return _LessonListItem(
              lesson: lesson,
              pathColor: path.color,
              isCompleted: done,
              onTap: () => onOpenLesson(lesson),
            );
          }),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Lesson List Item
// ═══════════════════════════════════════════════════════════════════════════════

class _LessonListItem extends StatefulWidget {
  final Lesson lesson;
  final Color pathColor;
  final bool isCompleted;
  final VoidCallback onTap;

  const _LessonListItem({
    required this.lesson,
    required this.pathColor,
    required this.isCompleted,
    required this.onTap,
  });

  @override
  State<_LessonListItem> createState() => _LessonListItemState();
}

class _LessonListItemState extends State<_LessonListItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: _hovered ? AppTheme.surfaceAlt : AppTheme.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(
                color: _hovered
                    ? widget.pathColor.withValues(alpha: 0.2)
                    : AppTheme.border,
              ),
            ),
            child: Row(
              children: [
                // Completed checkmark or lesson number
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: widget.isCompleted
                        ? AppTheme.success.withValues(alpha: 0.15)
                        : widget.pathColor.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: widget.isCompleted
                        ? const Icon(Icons.check_rounded,
                            size: 16, color: AppTheme.success)
                        : Icon(Icons.play_arrow_rounded,
                            size: 16, color: widget.pathColor),
                  ),
                ),
                const SizedBox(width: 14),

                // Title + subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.lesson.title,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: widget.isCompleted
                              ? AppTheme.textSecondary
                              : AppTheme.textPrimary,
                          decoration: widget.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                          decorationColor: AppTheme.textTertiary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.lesson.subtitle,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppTheme.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),

                // Read time
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceAlt,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${widget.lesson.readMinutes} min',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textTertiary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: _hovered ? widget.pathColor : AppTheme.textTertiary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Quick Tips Section
// ═══════════════════════════════════════════════════════════════════════════════

class _QuickTips extends StatelessWidget {
  final bool isMobile;
  const _QuickTips({required this.isMobile});

  static const _tips = [
    (
      icon: Icons.lightbulb_rounded,
      color: AppTheme.warning,
      text: 'Check the trend on a higher timeframe before entering a match.',
    ),
    (
      icon: Icons.speed_rounded,
      color: AppTheme.info,
      text: 'In 15m matches, scalp with 10-20x leverage and tight stop losses.',
    ),
    (
      icon: Icons.shield_rounded,
      color: AppTheme.error,
      text: 'Never risk more than 25% of your match balance on a single trade.',
    ),
    (
      icon: Icons.psychology_rounded,
      color: AppTheme.solanaPurple,
      text: 'When ahead, play defense. When behind, find one high-conviction setup.',
    ),
    (
      icon: Icons.trending_up_rounded,
      color: AppTheme.success,
      text: 'SOL moves the most in percentage terms — use it for aggressive plays.',
    ),
    (
      icon: Icons.timer_rounded,
      color: AppTheme.solanaGreen,
      text: 'Close positions manually before match end if you\'re protecting a lead.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.tips_and_updates_rounded,
                  color: AppTheme.warning, size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              'Quick Tips',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _tips.map((tip) {
            final cardWidth = Responsive.value<double>(context,
                mobile: MediaQuery.sizeOf(context).width - 32,
                tablet: (MediaQuery.sizeOf(context).width - 80) / 2,
                desktop: (MediaQuery.sizeOf(context).width - 144) / 3);

            return Container(
              width: cardWidth.clamp(0, 420),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(tip.icon, size: 18, color: tip.color),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      tip.text,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Lesson Detail View (full-screen reader)
// ═══════════════════════════════════════════════════════════════════════════════

class _LessonDetailView extends StatelessWidget {
  final Lesson lesson;
  final LearningPath path;
  final bool isCompleted;
  final VoidCallback onBack;
  final VoidCallback onMarkComplete;
  final VoidCallback? onGoToNext;

  const _LessonDetailView({
    required this.lesson,
    required this.path,
    required this.isCompleted,
    required this.onBack,
    required this.onMarkComplete,
    this.onGoToNext,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final contentWidth = Responsive.value<double>(context,
        mobile: double.infinity, tablet: 680, desktop: 740);

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 64),
      child: Center(
        child: Container(
          width: contentWidth,
          padding: Responsive.horizontalPadding(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),

              // Back button
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: onBack,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.arrow_back_rounded,
                          size: 18, color: path.color),
                      const SizedBox(width: 6),
                      Text(
                        'Back to ${path.title}',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: path.color,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Lesson header
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: path.color.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      path.tag,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: path.color,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceAlt,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.schedule_rounded,
                            size: 12, color: AppTheme.textTertiary),
                        const SizedBox(width: 4),
                        Text(
                          '${lesson.readMinutes} min read',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isCompleted) ...[
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_rounded,
                              size: 12, color: AppTheme.success),
                          const SizedBox(width: 4),
                          Text(
                            'Completed',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.success,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),

              // Title
              Text(
                lesson.title,
                style: GoogleFonts.inter(
                  fontSize: isMobile ? 28 : 34,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.5,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                lesson.subtitle,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  color: AppTheme.textSecondary,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 32),
              Divider(
                  height: 1,
                  color: AppTheme.border),
              const SizedBox(height: 32),

              // Content sections
              for (final section in lesson.sections) ...[
                Text(
                  section.heading,
                  style: GoogleFonts.inter(
                    fontSize: isMobile ? 18 : 20,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  section.body,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                    height: 1.75,
                  ),
                ),
                const SizedBox(height: 28),
              ],

              // Key takeaways
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: path.color.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  border:
                      Border.all(color: path.color.withValues(alpha: 0.15)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.lightbulb_rounded,
                            size: 18, color: path.color),
                        const SizedBox(width: 8),
                        Text(
                          'Key Takeaways',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: path.color,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    for (final takeaway in lesson.keyTakeaways) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Icon(Icons.check_circle_rounded,
                                  size: 16, color: path.color),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                takeaway,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: AppTheme.textPrimary,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Mark complete / Next lesson button
              Center(
                child: isCompleted
                    ? onGoToNext != null
                        ? MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: GestureDetector(
                              onTap: onGoToNext,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 12),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      AppTheme.solanaPurple,
                                      AppTheme.solanaPurpleDark,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.solanaPurple
                                          .withValues(alpha: 0.3),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Next Lesson',
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(Icons.arrow_forward_rounded,
                                        size: 20, color: Colors.white),
                                  ],
                                ),
                              ),
                            ),
                          )
                        : Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                            decoration: BoxDecoration(
                              color: AppTheme.success.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color:
                                      AppTheme.success.withValues(alpha: 0.2)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.check_circle_rounded,
                                    size: 20, color: AppTheme.success),
                                const SizedBox(width: 8),
                                Text(
                                  'All Lessons Complete!',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.success,
                                  ),
                                ),
                              ],
                            ),
                          )
                    : MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: onMarkComplete,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  AppTheme.solanaPurple,
                                  AppTheme.solanaPurpleDark,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.solanaPurple
                                      .withValues(alpha: 0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.check_rounded,
                                    size: 20, color: Colors.white),
                                const SizedBox(width: 8),
                                Text(
                                  'Mark as Complete',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
              ),

              const SizedBox(height: 24),

              // Back to paths
              Center(
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: onBack,
                    child: Text(
                      'Back to all lessons',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textTertiary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
