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

  const SleepCalendarWidget({super.key, required this.reports});

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
          onPageChanged: (focused) => setState(() => _focusedDay = focused),
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
