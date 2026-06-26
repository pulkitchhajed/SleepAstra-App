import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/journal_provider.dart';
import '../models/journal_entry.dart';
import '../../rewards/providers/rewards_provider.dart';

class EveningJournalScreen extends StatefulWidget {
  const EveningJournalScreen({super.key});
  @override
  State<EveningJournalScreen> createState() => _EveningJournalScreenState();
}

class _EveningJournalScreenState extends State<EveningJournalScreen> {
  int _caffeine = 0;
  int _alcohol = 0;
  int _stress = 5;
  int _hoursBeforeMeal = 2;
  final _notesCtrl = TextEditingController();

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Evening Journal'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(DateFormat('EEEE, MMMM d').format(DateTime.now()),
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppTheme.accentTeal)),
          const SizedBox(height: 6),
          Text('Before you sleep', style: Theme.of(context).textTheme.displayMedium),
          const SizedBox(height: 28),

          _sectionHeader('☕ Caffeine Drinks Today'),
          _counterRow(_caffeine, 5, (v) => setState(() => _caffeine = v),
              ['0', '1', '2', '3', '4', '5+']),
          const SizedBox(height: 24),

          _sectionHeader('🍷 Alcohol Units Today'),
          _counterRow(_alcohol, 5, (v) => setState(() => _alcohol = v),
              ['0', '1', '2', '3', '4', '5+']),
          const SizedBox(height: 24),

          _sectionHeader('😰 Stress Level'),
          Row(children: [
            const Text('😌', style: TextStyle(fontSize: 20)),
            Expanded(
              child: Slider(
                value: _stress.toDouble(),
                min: 1, max: 10, divisions: 9,
                activeColor: _stressColor(_stress),
                onChanged: (v) => setState(() => _stress = v.round()),
              ),
            ),
            const Text('😤', style: TextStyle(fontSize: 20)),
          ]),
          Center(
              child: Text('$_stress / 10',
                  style: TextStyle(
                      color: _stressColor(_stress),
                      fontWeight: FontWeight.w700,
                      fontSize: 18))),
          const SizedBox(height: 24),

          _sectionHeader('🍽️ Last Meal (hours before bed)'),
          Slider(
            value: _hoursBeforeMeal.toDouble(),
            min: 0, max: 6, divisions: 6,
            label: '$_hoursBeforeMeal h',
            activeColor: AppTheme.primaryGold,
            onChanged: (v) => setState(() => _hoursBeforeMeal = v.round()),
          ),
          Center(
              child: Text('$_hoursBeforeMeal hours before bed',
                  style: const TextStyle(
                      color: AppTheme.primaryGold, fontWeight: FontWeight.w600))),
          const SizedBox(height: 24),

          _sectionHeader('📝 Notes (optional)'),
          TextField(
            controller: _notesCtrl,
            maxLines: 3,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: InputDecoration(
              hintText: 'Anything notable today?',
              hintStyle: const TextStyle(color: AppTheme.textSecondary),
              filled: true,
              fillColor: AppTheme.surface,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.cardBorder)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.cardBorder)),
            ),
          ),
          const SizedBox(height: 36),

          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGold,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Save Evening Entry',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      ),
    );
  }

  Future<void> _save() async {
    final p = context.read<JournalProvider>();
    p.updateEveningDraft(JournalEntry.newEvening().copyWith(
      caffeineUnits: _caffeine,
      alcoholUnits: _alcohol,
      stressLevel: _stress,
      hoursBeforeBedMeal: _hoursBeforeMeal,
      notes: _notesCtrl.text.trim(),
    ));
    await p.saveEvening();
    if (mounted) {
      context.read<RewardsProvider>().earn('journal_entry', 'journal_evening_${DateTime.now().toIso8601String().substring(0, 10)}');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Evening journal saved! Sleep tight 😴'),
        backgroundColor: AppTheme.success,
      ));
      Navigator.pop(context);
    }
  }

  Widget _sectionHeader(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text,
            style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 15)),
      );

  Widget _counterRow(int selected, int max, ValueChanged<int> onSelect,
      List<String> labels) {
    return Row(
      children: List.generate(labels.length, (i) {
        final active = selected == i;
        return Expanded(
          child: GestureDetector(
            onTap: () => onSelect(i),
            child: Container(
              margin: const EdgeInsets.only(right: 4),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: active
                    ? AppTheme.primaryIndigo.withValues(alpha: 0.2)
                    : AppTheme.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: active ? AppTheme.primaryIndigo : AppTheme.cardBorder),
              ),
              child: Text(labels[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: active
                          ? AppTheme.primaryIndigo
                          : AppTheme.textSecondary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13)),
            ),
          ),
        );
      }),
    );
  }

  Color _stressColor(int s) {
    if (s <= 3) return AppTheme.success;
    if (s <= 6) return AppTheme.primaryGold;
    return AppTheme.error;
  }
}
