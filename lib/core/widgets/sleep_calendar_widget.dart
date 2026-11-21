import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

import '../../modules/sleep_analysis/models/sleep_report.dart';
import '../theme/app_theme.dart';
import '../providers/theme_provider.dart';
import 'package:provider/provider.dart';
import '../router/app_router.dart';

/// A premium sleep calendar widget that shows color-coded dots for each day
/// that has a recording. Tapping a day opens the report (or lets the user
/// pick from multiple recordings on that day).
class SleepCalendarWidget extends StatefulWidget {
  final List<SleepReport> reports;
  final void Function(DateTime month)? onMonthChanged;

  const SleepCalendarWidget({super.key, required this.reports, this.onMonthChanged});

  @override
  State<SleepCalendarWidget> createState() => _SleepCalendarWidgetState();
}

class _SleepCalendarWidgetState extends State<SleepCalendarWidget> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.week;

  // Map from normalised date → list of reports on that day
  late Map<DateTime, List<SleepReport>> _eventMap;

  @override
  void initState() {
    super.initState();
    _buildEventMap();
  }

  @override
  void didUpdateWidget(SleepCalendarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reports != widget.reports) _buildEventMap();
  }

  void _buildEventMap() {
    _eventMap = {};
    for (final r in widget.reports) {
      final key = _normalise(r.recordedAt);
      _eventMap.putIfAbsent(key, () => []).add(r);
    }
  }

  DateTime _normalise(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  List<SleepReport> _eventsForDay(DateTime day) =>
      _eventMap[_normalise(day)] ?? [];

  Color _dotColor(SleepReport r) {
    final s = r.qualityScore;
    if (s >= 80) return AppTheme.accentTeal;
    if (s >= 60) return AppTheme.primaryGold;
    return AppTheme.error;
  }

  void _onDayTapped(DateTime day) {
    final reports = _eventsForDay(day);
    if (reports.isEmpty) return;

    setState(() => _selectedDay = day);

    if (reports.length == 1) {
      Navigator.pushNamed(
        context,
        AppRouter.sleepReport,
        arguments: reports.first,
      );
    } else {
      _showPickerSheet(reports);
    }
  }

  void _showPickerSheet(List<SleepReport> reports) {
    final fmt = DateFormat('h:mm a');
    final isLight = context.read<ThemeProvider>().isDarkMode == false;
    final cardBg = isLight ? AppTheme.surfaceLight : AppTheme.surface;
    final textPrimary = isLight ? AppTheme.textPrimaryLight : AppTheme.textPrimary;
    final textSec = isLight ? AppTheme.textSecondaryLight : AppTheme.textSecondary; // ignore: unused_local_variable

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        decoration: BoxDecoration(
          color: cardBg,
          gradient: isLight ? null : const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A1D33), Color(0xFF111428)],
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: textPrimary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Multiple Recordings',
              style: TextStyle(
                color: textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Select a recording to view its report',
              style: TextStyle(
                color: textSec,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 20),
            ...reports.map((r) {
              final color = _dotColor(r);
              final duration = r.totalDuration;
              return GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(
                    context,
                    AppRouter.sleepReport,
                    arguments: r,
                  );
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        color.withValues(alpha: 0.08),
                        Colors.transparent,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: color.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            r.qualityEmoji,
                            style: const TextStyle(fontSize: 22),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fmt.format(r.recordedAt),
                              style: TextStyle(
                                color: textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${duration.inHours}h ${duration.inMinutes % 60}m · Score ${r.qualityScore.toInt()}',
                              style: TextStyle(
                                color: textSec,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios_rounded,
                          size: 14, color: color.withValues(alpha: 0.7)),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _dayCell(
    DateTime day,
    Color textPrimary,
    bool isLight, {
    required bool isToday,
    required bool isSelected,
  }) {
    final events = _eventsForDay(day);
    final bool hasEvents = events.isNotEmpty;

    Color numColor;
    BoxDecoration? decoration;

    if (isSelected) {
      numColor = Colors.white;
      decoration = const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryIndigo, Color(0xFF8B5CF6)],
        ),
        shape: BoxShape.circle,
      );
    } else if (isToday) {
      numColor = isLight ? AppTheme.primaryIndigo : Colors.white;
      decoration = BoxDecoration(
        color: AppTheme.primaryIndigo.withValues(alpha: 0.15),
        shape: BoxShape.circle,
        border: Border.all(
          color: AppTheme.primaryIndigo.withValues(alpha: 0.65),
          width: 1.5,
        ),
      );
    } else {
      numColor = textPrimary.withValues(alpha: 0.8);
      decoration = null;
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: decoration,
          alignment: Alignment.center,
          child: Text(
            '${day.day}',
            style: TextStyle(
              color: numColor,
              fontWeight: (isToday || isSelected) ? FontWeight.w700 : FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ),
        if (hasEvents)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: events.take(3).map((r) {
                final c = _dotColor(r);
                return Container(
                  width: 5,
                  height: 5,
                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                  ),
                );
              }).toList(),
            ),
          )
        else
          const SizedBox(height: 8), // keep height consistent
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLight = context.watch<ThemeProvider>().isDarkMode == false;
    final cardBg = isLight ? AppTheme.surfaceLight : AppTheme.surface;
    final textPrimary = isLight ? AppTheme.textPrimaryLight : AppTheme.textPrimary;
    final textSec = isLight ? AppTheme.textSecondaryLight : AppTheme.textSecondary; // ignore: unused_local_variable
    final cardBorder = isLight ? AppTheme.cardBorderLight : AppTheme.primaryIndigo.withValues(alpha: 0.18);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        gradient: isLight ? null : const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1D33), Color(0xFF111428)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: cardBorder,
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryIndigo.withValues(alpha: 0.08),
            blurRadius: 24,
            spreadRadius: 2,
            offset: const Offset(0, 6),
          ),
          if (!isLight)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: TableCalendar<SleepReport>(
          firstDay: DateTime.utc(2024, 1, 1),
          lastDay: DateTime.now().add(const Duration(days: 1)),
          focusedDay: _focusedDay,
          calendarFormat: _calendarFormat,
          rowHeight: 56, // increased to give room for dots
          daysOfWeekHeight: 32,
          selectedDayPredicate: (day) =>
              _selectedDay != null && isSameDay(_selectedDay, day),
          eventLoader: _eventsForDay,
          startingDayOfWeek: StartingDayOfWeek.monday,
          // Callbacks
          onFormatChanged: (format) {
            if (_calendarFormat != format) {
              setState(() => _calendarFormat = format);
            }
          },
          onDaySelected: (selected, focused) {
            setState(() => _focusedDay = focused);
            _onDayTapped(selected);
          },
          onPageChanged: (focused) {
            setState(() => _focusedDay = focused);
            widget.onMonthChanged?.call(DateTime(focused.year, focused.month, 1));
          },
          // Calendar style
          calendarStyle: CalendarStyle(
            // Today
            todayDecoration: BoxDecoration(
              color: AppTheme.primaryIndigo.withValues(alpha: 0.18),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppTheme.primaryIndigo.withValues(alpha: 0.65),
                width: 1.5,
              ),
            ),
            todayTextStyle: TextStyle(
              color: isLight ? AppTheme.primaryIndigo : Colors.white,
              fontWeight: FontWeight.w700,
            ),
            // Selected
            selectedDecoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.primaryIndigo, Color(0xFF8B5CF6)],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryIndigo.withValues(alpha: 0.5),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
            selectedTextStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
            // Default day
            defaultTextStyle: TextStyle(color: textPrimary.withValues(alpha: 0.75)),
            weekendTextStyle: TextStyle(color: textPrimary.withValues(alpha: 0.5)),
            outsideTextStyle: TextStyle(color: textPrimary.withValues(alpha: 0.2)),
            disabledTextStyle: TextStyle(color: textPrimary.withValues(alpha: 0.15)),
            // Marker dots — turned off (we use custom builder below)
            markersMaxCount: 0,
            // Cell padding
            cellMargin: const EdgeInsets.all(4),
            cellPadding: EdgeInsets.zero,
          ),
          // Use custom day builders — dots are rendered inside _dayCell
          calendarBuilders: CalendarBuilders(
            defaultBuilder: (context, day, focusedDay) {
              return _dayCell(day, textPrimary, isLight, isToday: false, isSelected: false);
            },
            todayBuilder: (context, day, focusedDay) {
              return _dayCell(day, textPrimary, isLight, isToday: true, isSelected: false);
            },
            selectedBuilder: (context, day, focusedDay) {
              return _dayCell(day, textPrimary, isLight, isToday: false, isSelected: true);
            },
          ),
          // Header style
          headerStyle: HeaderStyle(
            formatButtonVisible: true,
            formatButtonShowsNext: false,
            formatButtonDecoration: BoxDecoration(
              color: AppTheme.primaryIndigo.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primaryIndigo.withValues(alpha: 0.5)),
            ),
            formatButtonTextStyle: TextStyle(
              color: textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            titleCentered: true,
            titleTextStyle: TextStyle(
              color: textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
            leftChevronIcon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: textPrimary.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.chevron_left_rounded,
                  color: textPrimary.withValues(alpha: 0.7), size: 18),
            ),
            rightChevronIcon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: textPrimary.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.chevron_right_rounded,
                  color: textPrimary.withValues(alpha: 0.7), size: 18),
            ),
            headerPadding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: AppTheme.primaryIndigo.withValues(alpha: 0.15),
                  width: 0.8,
                ),
              ),
            ),
          ),
          // Days of week style
          daysOfWeekStyle: DaysOfWeekStyle(
            weekdayStyle: TextStyle(
              color: textPrimary.withValues(alpha: 0.4),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
            weekendStyle: TextStyle(
              color: textPrimary.withValues(alpha: 0.25),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

/// A dedicated rolling 7-day sleep pattern calendar strip.
/// Shows today and the 6 preceding days with score badges, duration,
/// quality indicators, and tap-to-view report functionality.
class Rolling7DayPatternWidget extends StatelessWidget {
  final List<SleepReport> reports;
  final void Function(SleepReport report)? onReportTapped;

  const Rolling7DayPatternWidget({
    super.key,
    required this.reports,
    this.onReportTapped,
  });

  DateTime _normalise(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  @override
  Widget build(BuildContext context) {
    final isLight = context.watch<ThemeProvider>().isDarkMode == false;
    final cardBg = isLight ? AppTheme.surfaceLight : AppTheme.surface;
    final textPrimary = isLight ? AppTheme.textPrimaryLight : AppTheme.textPrimary;
    final textSec = isLight ? AppTheme.textSecondaryLight : AppTheme.textSecondary;
    final cardBorder = isLight ? AppTheme.cardBorderLight : AppTheme.primaryIndigo.withValues(alpha: 0.18);

    // Group reports by normalised date
    final Map<DateTime, List<SleepReport>> eventMap = {};
    for (final r in reports) {
      final key = _normalise(r.recordedAt);
      eventMap.putIfAbsent(key, () => []).add(r);
    }

    // Generate rolling last 7 days (today and preceding 6 days)
    final now = DateTime.now();
    final todayNorm = _normalise(now);
    final days = List.generate(7, (i) {
      final d = now.subtract(Duration(days: 6 - i));
      return _normalise(d);
    });

    // Compute rolling 7-day stats
    int recordedDaysCount = 0;
    double totalScore = 0;
    int totalMinutes = 0;

    for (final day in days) {
      final dayReports = eventMap[day];
      if (dayReports != null && dayReports.isNotEmpty) {
        recordedDaysCount++;
        totalScore += dayReports.first.qualityScore;
        totalMinutes += dayReports.first.totalDuration.inMinutes;
      }
    }

    final double avgScore = recordedDaysCount > 0 ? (totalScore / recordedDaysCount) : 0;
    final int avgMinutes = recordedDaysCount > 0 ? (totalMinutes ~/ recordedDaysCount) : 0;
    final String avgDurationStr = '${avgMinutes ~/ 60}h ${avgMinutes % 60}m';

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        gradient: isLight ? null : const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1D33), Color(0xFF111428)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cardBorder, width: 0.8),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryIndigo.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
          if (!isLight)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryIndigo.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.date_range_rounded,
                  color: AppTheme.primaryIndigo,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '7-Day Sleep Pattern',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      recordedDaysCount > 0
                          ? 'Avg Score: ${avgScore.toInt()} • Avg: $avgDurationStr'
                          : 'No sleep sessions in the last 7 days',
                      style: TextStyle(color: textSec, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: recordedDaysCount >= 5
                      ? AppTheme.accentTeal.withValues(alpha: 0.15)
                      : AppTheme.primaryGold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: recordedDaysCount >= 5
                        ? AppTheme.accentTeal.withValues(alpha: 0.5)
                        : AppTheme.primaryGold.withValues(alpha: 0.5),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  '$recordedDaysCount/7 Days',
                  style: TextStyle(
                    color: recordedDaysCount >= 5 ? AppTheme.accentTeal : AppTheme.primaryGold,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // 7-Day Day Columns
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: days.map((day) {
              final isToday = day == todayNorm;
              final dayReports = eventMap[day] ?? [];
              final hasData = dayReports.isNotEmpty;
              final report = hasData ? dayReports.first : null;

              final weekdayName = _weekdayAbbrev(day.weekday);

              Color dotColor;
              String scoreLabel;
              String durationLabel;

              if (hasData && report != null) {
                final s = report.qualityScore;
                if (s >= 80) {
                  dotColor = AppTheme.accentTeal;
                } else if (s >= 65) {
                  dotColor = const Color(0xFF3B82F6);
                } else if (s >= 50) {
                  dotColor = AppTheme.primaryGold;
                } else {
                  dotColor = AppTheme.error;
                }
                scoreLabel = '${s.toInt()}';
                final h = report.totalDuration.inHours;
                final m = report.totalDuration.inMinutes % 60;
                durationLabel = h > 0 ? '${h}h' : '${m}m';
              } else {
                dotColor = textSec.withValues(alpha: 0.2);
                scoreLabel = '--';
                durationLabel = '-';
              }

              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    if (hasData && report != null) {
                      if (onReportTapped != null) {
                        onReportTapped!(report);
                      } else if (dayReports.length == 1) {
                        Navigator.pushNamed(context, AppRouter.sleepReport, arguments: report);
                      } else {
                        _showMultiReportPicker(context, dayReports, isLight, textPrimary, textSec);
                      }
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('No sleep session recorded on ${day.day}/${day.month}.'),
                          duration: const Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
                    decoration: BoxDecoration(
                      color: isToday
                          ? AppTheme.primaryIndigo.withValues(alpha: 0.12)
                          : (hasData
                              ? (isLight ? const Color(0xFFF3F4F6) : AppTheme.surfaceElevated)
                              : Colors.transparent),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isToday
                            ? AppTheme.primaryIndigo.withValues(alpha: 0.6)
                            : (hasData
                                ? dotColor.withValues(alpha: 0.35)
                                : cardBorder.withValues(alpha: 0.4)),
                        width: isToday ? 1.5 : 0.8,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Weekday
                        Text(
                          isToday ? 'Today' : weekdayName,
                          style: TextStyle(
                            color: isToday
                                ? (isLight ? AppTheme.primaryIndigo : Colors.white)
                                : textSec,
                            fontSize: isToday ? 10 : 11,
                            fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        // Day of month
                        Text(
                          '${day.day}',
                          style: TextStyle(
                            color: isToday
                                ? (isLight ? AppTheme.primaryIndigo : Colors.white)
                                : textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Score Circle Badge
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: hasData
                                ? dotColor.withValues(alpha: 0.18)
                                : textSec.withValues(alpha: 0.08),
                            border: Border.all(
                              color: hasData ? dotColor : Colors.transparent,
                              width: 1.2,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            scoreLabel,
                            style: TextStyle(
                              color: hasData ? dotColor : textSec.withValues(alpha: 0.5),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Duration string
                        Text(
                          durationLabel,
                          style: TextStyle(
                            color: textSec,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),

          // Pattern Legend & Tap hint
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  _legendDot(AppTheme.accentTeal, '≥80', textSec),
                  const SizedBox(width: 8),
                  _legendDot(const Color(0xFF3B82F6), '65-79', textSec),
                  const SizedBox(width: 8),
                  _legendDot(AppTheme.primaryGold, '50-64', textSec),
                  const SizedBox(width: 8),
                  _legendDot(AppTheme.error, '<50', textSec),
                ],
              ),
              Text(
                'Tap day to view',
                style: TextStyle(
                  color: isLight ? AppTheme.primaryIndigo : AppTheme.accentTeal,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _legendDot(Color color, String label, Color textSec) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(color: textSec, fontSize: 10)),
      ],
    );
  }

  static String _weekdayAbbrev(int weekday) {
    switch (weekday) {
      case DateTime.monday: return 'Mon';
      case DateTime.tuesday: return 'Tue';
      case DateTime.wednesday: return 'Wed';
      case DateTime.thursday: return 'Thu';
      case DateTime.friday: return 'Fri';
      case DateTime.saturday: return 'Sat';
      case DateTime.sunday: return 'Sun';
      default: return '';
    }
  }

  static void _showMultiReportPicker(
    BuildContext context,
    List<SleepReport> reports,
    bool isLight,
    Color textPrimary,
    Color textSec,
  ) {
    final fmt = DateFormat('h:mm a');
    final cardBg = isLight ? AppTheme.surfaceLight : AppTheme.surface;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: textPrimary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Recordings on this day',
              style: TextStyle(
                color: textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Select a session to view detailed analysis',
              style: TextStyle(color: textSec, fontSize: 13),
            ),
            const SizedBox(height: 16),
            ...reports.map((r) {
              final color = r.qualityScore >= 80
                  ? AppTheme.accentTeal
                  : (r.qualityScore >= 60 ? AppTheme.primaryGold : AppTheme.error);
              return GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, AppRouter.sleepReport, arguments: r);
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isLight ? const Color(0xFFF3F4F6) : AppTheme.surfaceElevated,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: color.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(r.qualityEmoji, style: const TextStyle(fontSize: 20)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fmt.format(r.recordedAt),
                              style: TextStyle(
                                color: textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${r.totalDuration.inHours}h ${r.totalDuration.inMinutes % 60}m • Score ${r.qualityScore.toInt()} (${r.qualityLabel})',
                              style: TextStyle(color: textSec, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: textSec, size: 20),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
