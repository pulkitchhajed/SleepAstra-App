import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/journal_provider.dart';
import '../models/journal_entry.dart';
import 'evening_journal_screen.dart';
import 'morning_journal_screen.dart';
import '../../../core/router/app_router.dart';

class JournalListScreen extends StatefulWidget {
  const JournalListScreen({super.key});
  @override
  State<JournalListScreen> createState() => _JournalListScreenState();
}

class _JournalListScreenState extends State<JournalListScreen> {
  late bool isLight;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    isLight = Theme.of(context).brightness == Brightness.light;
  }

  @override
  void initState() {
    super.initState();
    // Data is synced centrally in MainGate
  }

  @override
  Widget build(BuildContext context) {
    final entries = context.watch<JournalProvider>().entries;

    return Scaffold(
      backgroundColor: isLight ? AppTheme.backgroundLight : AppTheme.background,
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
      body: entries.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('assets/images/empty_journal.png', width: 140, height: 140),
                  const SizedBox(height: 16),
                  Text('No journal entries yet',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text('Log your evening or morning habits to\ncorrelate them with sleep quality.',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => _showAddMenu(context),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add First Entry'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGold,
                        foregroundColor: Colors.black),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: entries.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) => _entryCard(entries[i]),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, AppRouter.nidraChat),
        backgroundColor: AppTheme.primaryIndigo,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        label: const Text('Ask Nidra', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        icon: const Text('🤖', style: TextStyle(fontSize: 22)),
      ),
    );
  }

  Widget _entryCard(JournalEntry e) {
    final isEvening = e.type == JournalType.evening;
    final color = isEvening ? AppTheme.primaryIndigo : AppTheme.primaryGold;
    final icon = isEvening ? '🌙' : '☀️';
    final label = isEvening ? 'Evening' : 'Morning';

    return Dismissible(
      key: Key(e.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppTheme.error.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: AppTheme.error),
      ),
      onDismissed: (_) =>
          context.read<JournalProvider>().deleteEntry(e.id),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isLight ? AppTheme.surfaceLight : AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isLight ? AppTheme.cardBorderLight : AppTheme.cardBorder),
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
                Text(DateFormat('MMM d, h:mm a').format(e.date),
                    style: Theme.of(context).textTheme.bodyMedium),
              ]),
              const SizedBox(height: 6),
              if (isEvening)
                Text(
                  '☕ ${e.caffeineUnits}  🍷 ${e.alcoholUnits}  😰 ${e.stressLevel}/10',
                  style: TextStyle(
                      color: isLight ? AppTheme.textSecondaryLight : AppTheme.textSecondary, fontSize: 13),
                )
              else
                Text(
                  '${_moodEmoji(e.moodScore)} Mood ${e.moodScore}/10  🛏️ ${e.sleepPosition}${e.hadCongestion ? '  🤧' : ''}',
                  style: TextStyle(
                      color: isLight ? AppTheme.textSecondaryLight : AppTheme.textSecondary, fontSize: 13),
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
      backgroundColor: isLight ? AppTheme.surfaceLight : AppTheme.surfaceElevated,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              leading: const Text('🌙', style: TextStyle(fontSize: 26)),
              title: Text('Evening Entry',
                  style: TextStyle(color: isLight ? AppTheme.textPrimaryLight : AppTheme.textPrimary, fontWeight: FontWeight.w600)),
              subtitle: Text('Log before sleep',
                  style: Theme.of(context).textTheme.bodyMedium),
              onTap: () {
                if (ctx.mounted) Navigator.pop(ctx);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const EveningJournalScreen()));
              },
            ),
            ListTile(
              leading: const Text('☀️', style: TextStyle(fontSize: 26)),
              title: Text('Morning Entry',
                  style: TextStyle(color: isLight ? AppTheme.textPrimaryLight : AppTheme.textPrimary, fontWeight: FontWeight.w600)),
              subtitle: Text('Log after waking up',
                  style: Theme.of(context).textTheme.bodyMedium),
              onTap: () {
                if (ctx.mounted) Navigator.pop(ctx);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const MorningJournalScreen()));
              },
            ),
          ]),
        ),
      ),
    );
  }

  String _moodEmoji(int m) {
    if (m <= 2) return '😫';
    if (m <= 4) return '😕';
    if (m <= 6) return '😐';
    if (m <= 8) return '😊';
    return '😄';
  }
}
