import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/providers/theme_provider.dart';
import '../providers/journal_provider.dart';
import '../models/journal_entry.dart';
import '../../sleep_analysis/providers/sleep_analysis_provider.dart';
import '../../sleep_analysis/models/sleep_report.dart';

class MorningJournalScreen extends StatefulWidget {
  const MorningJournalScreen({super.key});
  @override
  State<MorningJournalScreen> createState() => _MorningJournalScreenState();
}

class _MorningJournalScreenState extends State<MorningJournalScreen> {
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();

  int _mood = 7;
  String _energy = 'Medium';
  String _notes = '';

  @override
  void initState() {
    super.initState();
    _loadDataForDay(_selectedDay);
  }

  void _loadDataForDay(DateTime day) {
    final jp = context.read<JournalProvider>();
    final existing = jp.entries.cast<JournalEntry?>().firstWhere(
      (e) => e != null && e.type == JournalType.morning && isSameDay(e.date, day),
      orElse: () => null,
    );
    if (existing != null) {
      setState(() {
        _mood = existing.moodScore;
        _energy = existing.energyLevel;
        _notes = existing.notes.isNotEmpty ? existing.notes : 'No notes added.';
      });
    } else {
      setState(() {
        _mood = 7;
        _energy = 'Medium';
        _notes = 'No notes added.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final sp = context.watch<SleepAnalysisProvider>();
    final history = sp.history;
    final isLight = context.watch<ThemeProvider>().isDarkMode == false;
    final bg = isLight ? AppTheme.backgroundLight : const Color(0xFF0D0F1E);
    final cardBg = isLight ? AppTheme.surfaceLight : const Color(0xFF1A1D33);
    final cardBorder = isLight ? AppTheme.cardBorderLight : Colors.white.withValues(alpha: 0.05);
    final textPrimary = isLight ? AppTheme.textPrimaryLight : Colors.white;
    final textSec = isLight ? AppTheme.textSecondaryLight : Colors.white.withValues(alpha: 0.5);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text('Sleep Diary', style: TextStyle(color: textPrimary)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Date
            Center(
              child: Text(
                'Today, ${DateFormat('MMM d').format(_selectedDay)}',
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Week Calendar Strip
            _buildCalendarStrip(cardBg, cardBorder, textPrimary),
            const SizedBox(height: 24),

            // Duration Chart for the week
            _buildWeeklyDurationChart(history, cardBg, cardBorder, textPrimary, textSec),
            const SizedBox(height: 32),

            // Read-Only List items exactly as in image
            _buildJournalItem(
              Icons.bedtime_rounded,
              AppTheme.primaryIndigo,
              'How did you sleep?',
              _getMoodText(_mood),
              textPrimary,
              textSec,
            ),
            _buildJournalItem(
              Icons.bolt_rounded,
              AppTheme.accentTeal,
              'Energy Level',
              _energy,
              textPrimary,
              textSec,
            ),
            _buildJournalItem(
              Icons.sticky_note_2_rounded,
              AppTheme.primaryGold,
              'Notes',
              _notes,
              textPrimary,
              textSec,
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  String _getMoodText(int mood) {
    if (mood >= 8) return 'Good';
    if (mood >= 5) return 'Fair';
    return 'Poor';
  }

  Widget _buildJournalItem(IconData icon, Color color, String title, String value, Color textPrimary, Color textSec) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: textSec, fontSize: 13)),
                const SizedBox(height: 4),
                Text(value, style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarStrip(Color cardBg, Color cardBorder, Color textPrimary) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorder),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TableCalendar(
        firstDay: DateTime.utc(2024, 1, 1),
        lastDay: DateTime.now().add(const Duration(days: 7)),
        focusedDay: _focusedDay,
        calendarFormat: CalendarFormat.week,
        startingDayOfWeek: StartingDayOfWeek.monday,
        headerVisible: false,
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        onDaySelected: (selected, focused) {
          setState(() {
            _selectedDay = selected;
            _focusedDay = focused;
          });
          _loadDataForDay(selected);
        },
        calendarStyle: CalendarStyle(
          todayDecoration: const BoxDecoration(
            color: Colors.transparent,
            shape: BoxShape.circle,
          ),
          todayTextStyle: const TextStyle(
            color: AppTheme.primaryIndigo,
            fontWeight: FontWeight.w700,
          ),
          selectedDecoration: const BoxDecoration(
            color: AppTheme.primaryIndigo,
            shape: BoxShape.circle,
          ),
          selectedTextStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
          defaultTextStyle: TextStyle(color: textPrimary.withValues(alpha: 0.7)),
          weekendTextStyle: TextStyle(color: textPrimary.withValues(alpha: 0.4)),
          outsideTextStyle: TextStyle(color: textPrimary.withValues(alpha: 0.2)),
        ),
        daysOfWeekStyle: DaysOfWeekStyle(
          weekdayStyle: TextStyle(
            color: textPrimary.withValues(alpha: 0.4),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          weekendStyle: TextStyle(
            color: textPrimary.withValues(alpha: 0.25),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildWeeklyDurationChart(List<SleepReport> history, Color cardBg, Color cardBorder, Color textPrimary, Color textSec) {
    final monday = _selectedDay.subtract(Duration(days: _selectedDay.weekday - 1));
    final weekReports = <int, SleepReport?>{};
    double maxHours = 8.0;

    for (int i = 0; i < 7; i++) {
      final day = monday.add(Duration(days: i));
      final report = history.cast<SleepReport?>().firstWhere(
        (r) => r != null && isSameDay(r.recordedAt, day),
        orElse: () => null,
      );
      weekReports[i] = report;
      if (report != null) {
        final hrs = report.totalDuration.inMinutes / 60.0;
        if (hrs > maxHours) maxHours = hrs;
      }
    }

    final selectedWeekdayIdx = _selectedDay.weekday - 1;
    final selectedReport = weekReports[selectedWeekdayIdx];
    final selectedHrs = selectedReport != null ? selectedReport.totalDuration.inMinutes / 60.0 : 0.0;
    
    final startTimeStr = selectedReport != null 
        ? DateFormat('h:mm a').format(selectedReport.recordedAt.subtract(selectedReport.totalDuration))
        : '--:--';
    final endTimeStr = selectedReport != null 
        ? DateFormat('h:mm a').format(selectedReport.recordedAt)
        : '--:--';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sleep Duration',
                    style: TextStyle(fontSize: 12, color: textSec),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    selectedHrs > 0 
                      ? '${selectedHrs.floor()}h ${((selectedHrs - selectedHrs.floor()) * 60).round()}m'
                      : '-- h -- m',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: textPrimary),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (selectedHrs >= 7 ? AppTheme.accentTeal : AppTheme.error).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  selectedHrs >= 7 ? 'Goal Met' : 'Below Goal',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: selectedHrs >= 7 ? AppTheme.accentTeal : AppTheme.error,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
          SizedBox(
            height: 120,
            child: BarChart(
              BarChartData(
                minY: 0,
                maxY: maxHours * 1.2,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(color: cardBorder, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, m) {
                        final labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                        final isSel = v.toInt() == selectedWeekdayIdx;
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            labels[v.toInt()],
                            style: TextStyle(
                              color: isSel ? AppTheme.primaryIndigo : textSec,
                              fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                              fontSize: 12,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: List.generate(7, (i) {
                  final isSel = i == selectedWeekdayIdx;
                  final r = weekReports[i];
                  final val = r != null ? r.totalDuration.inMinutes / 60.0 : 0.0;
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: val,
                        color: isSel ? AppTheme.primaryIndigo : AppTheme.primaryIndigo.withValues(alpha: 0.15),
                        width: 14,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(startTimeStr, style: TextStyle(color: textSec, fontSize: 11, fontWeight: FontWeight.w600)),
              Text(endTimeStr, style: TextStyle(color: textSec, fontSize: 11, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }
}
