import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/journal_provider.dart';
import '../../sleep_analysis/providers/sleep_analysis_provider.dart';
import '../models/journal_entry.dart';
import 'evening_journal_screen.dart';
import 'morning_journal_screen.dart';
import '../../../core/router/app_router.dart';

class CalendarizedJournalScreen extends StatefulWidget {
  const CalendarizedJournalScreen({super.key});

  @override
  State<CalendarizedJournalScreen> createState() => _CalendarizedJournalScreenState();
}

class _CalendarizedJournalScreenState extends State<CalendarizedJournalScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay = DateTime.now();

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          context.read<JournalProvider>().loadEntries(uid);
          context.read<SleepAnalysisProvider>().loadHistory(uid);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Sleep Journal'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => _showAddMenu(context),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildCalendar(),
            const Divider(color: AppTheme.cardBorder, height: 1),
            Expanded(
              child: _buildDetailsForSelectedDay(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendar() {
    return TableCalendar(
      firstDay: DateTime.now().subtract(const Duration(days: 90)), // Last few months
      lastDay: DateTime.now(),
      focusedDay: _focusedDay,
      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
      onDaySelected: (selectedDay, focusedDay) {
        setState(() {
          _selectedDay = selectedDay;
          _focusedDay = focusedDay;
        });
      },
      calendarFormat: CalendarFormat.twoWeeks,
      headerStyle: const HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
      ),
      calendarStyle: const CalendarStyle(
        todayDecoration: BoxDecoration(
          color: AppTheme.cardBorder,
          shape: BoxShape.circle,
        ),
        selectedDecoration: BoxDecoration(
          color: AppTheme.primaryIndigo,
          shape: BoxShape.circle,
        ),
      ),
      eventLoader: (day) {
        // Return a dummy value if there's a sleep report or journal entry for the day to show a dot
        final provider = context.read<SleepAnalysisProvider>();
        final journalProv = context.read<JournalProvider>();
        
        bool hasReport = provider.history.any((r) => isSameDay(r.recordedAt, day));
        bool hasJournal = journalProv.entries.any((e) => isSameDay(e.date, day));
        
        if (hasReport || hasJournal) return [true];
        return [];
      },
    );
  }

  Widget _buildDetailsForSelectedDay() {
    if (_selectedDay == null) return const SizedBox();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormat('EEEE, MMMM d, yyyy').format(_selectedDay!),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 20),
          _buildSleepReportSummary(),
          const SizedBox(height: 24),
          _buildJournalEntriesSummary(),
        ],
      ),
    );
  }

  Widget _buildSleepReportSummary() {
    final provider = context.watch<SleepAnalysisProvider>();
    final reports = provider.history.where((r) => isSameDay(r.recordedAt, _selectedDay)).toList();

    if (reports.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surfaceElevated,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.cardBorder),
        ),
        child: Column(
          children: [
            const Icon(Icons.nightlight_round, size: 40, color: AppTheme.textSecondary),
            const SizedBox(height: 12),
            Text('No Sleep Recorded', style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      );
    }

    final report = reports.first;

    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, AppRouter.sleepReport, arguments: report),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surfaceElevated,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.primaryIndigo.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(report.qualityEmoji, style: const TextStyle(fontSize: 32)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Sleep Score: ${report.qualityScore.toInt()}/100', style: Theme.of(context).textTheme.labelLarge),
                      Text('${report.totalDuration.inHours}h ${report.totalDuration.inMinutes % 60}m recorded', style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStat('Apnea Risk', report.apneaRiskLevel),
                _buildStat('Snore Events', '${report.snoringEventCount}'),
                _buildStat('Debt', '${report.sleepDebtHours}h'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(String label, String val) {
    return Column(
      children: [
        Text(val, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.primaryIndigo)),
        Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
      ],
    );
  }

  Widget _buildJournalEntriesSummary() {
    final journalProv = context.watch<JournalProvider>();
    final entries = journalProv.entries.where((e) => isSameDay(e.date, _selectedDay)).toList();

    if (entries.isEmpty) {
      return const SizedBox();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Journal Entries', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        ...entries.map((e) => _entryCard(e)),
      ],
    );
  }

  Widget _entryCard(JournalEntry e) {
    final isEvening = e.type == JournalType.evening;
    final color = isEvening ? AppTheme.primaryIndigo : AppTheme.primaryGold;
    final icon = isEvening ? '🌙' : '☀️';
    final label = isEvening ? 'Evening' : 'Morning';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.cardBorder),
        ),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(child: Text(icon, style: const TextStyle(fontSize: 22))),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text('$icon $label',
                    style: TextStyle(
                        color: color, fontWeight: FontWeight.w700, fontSize: 14)),
                const Spacer(),
                Text(DateFormat('h:mm a').format(e.date),
                    style: Theme.of(context).textTheme.bodyMedium),
              ]),
              const SizedBox(height: 6),
              if (isEvening)
                Text(
                  '☕ ${e.caffeineUnits}  🍷 ${e.alcoholUnits}  😰 ${e.stressLevel}/10',
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 13),
                )
              else
                Text(
                  'Mood ${e.moodScore}/10  🛏️ ${e.sleepPosition}${e.hadCongestion ? '  🤧' : ''}',
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 13),
                ),
            ]),
          ),
        ]),
      ),
    );
  }

  void _showAddMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceElevated,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              leading: const Text('🌙', style: TextStyle(fontSize: 26)),
              title: const Text('Evening Entry',
                  style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
              subtitle: Text('Log before sleep',
                  style: Theme.of(context).textTheme.bodyMedium),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const EveningJournalScreen()));
              },
            ),
            ListTile(
              leading: const Text('☀️', style: TextStyle(fontSize: 26)),
              title: const Text('Morning Entry',
                  style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
              subtitle: Text('Log after waking up',
                  style: Theme.of(context).textTheme.bodyMedium),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const MorningJournalScreen()));
              },
            ),
          ]),
        ),
      ),
    );
  }
}
