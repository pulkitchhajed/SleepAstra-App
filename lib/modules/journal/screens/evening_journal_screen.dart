import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/theme_provider.dart';
import '../providers/journal_provider.dart';
import '../models/journal_entry.dart';
import '../../rewards/providers/rewards_provider.dart';
import '../../ai/services/gemini_service.dart';

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
  int _screenTimeHours = 2;
  bool _workedOut = false;
  final _notesCtrl = TextEditingController();
  
  bool _isSaving = false;
  String? _aiProjection;

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLight = context.watch<ThemeProvider>().isDarkMode == false;
    final bg = isLight ? AppTheme.backgroundLight : AppTheme.background;
    final cardBg = isLight ? AppTheme.surfaceLight : AppTheme.surface;
    final cardBorder = isLight ? AppTheme.cardBorderLight : AppTheme.cardBorder;
    final textPrimary = isLight ? AppTheme.textPrimaryLight : AppTheme.textPrimary;
    final textSec = isLight ? AppTheme.textSecondaryLight : AppTheme.textSecondary;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Evening Journal', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w700)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(DateFormat('EEEE, MMMM d').format(DateTime.now()),
              style: TextStyle(color: AppTheme.accentTeal, fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          Text('Before you sleep',
              style: TextStyle(color: textPrimary, fontSize: 24, fontWeight: FontWeight.w700)),
          const SizedBox(height: 28),

          _sectionHeader('☕ Caffeine Drinks Today', textPrimary),
          _counterRow(_caffeine, 5, (v) => setState(() => _caffeine = v),
              ['0', '1', '2', '3', '4', '5+'], cardBg, cardBorder, textSec),
          const SizedBox(height: 24),

          _sectionHeader('🍷 Alcohol Units Today', textPrimary),
          _counterRow(_alcohol, 5, (v) => setState(() => _alcohol = v),
              ['0', '1', '2', '3', '4', '5+'], cardBg, cardBorder, textSec),
          const SizedBox(height: 24),

          _sectionHeader('📱 Screen Time (hours)', textPrimary),
          Slider(
            value: _screenTimeHours.toDouble(),
            min: 0, max: 10, divisions: 10,
            label: '$_screenTimeHours h',
            activeColor: AppTheme.primaryIndigo,
            inactiveColor: AppTheme.primaryIndigo.withValues(alpha: 0.2),
            onChanged: (v) => setState(() => _screenTimeHours = v.round()),
          ),
          Center(
              child: Text('$_screenTimeHours hours of screen time',
                  style: const TextStyle(
                      color: AppTheme.primaryIndigo, fontWeight: FontWeight.w600))),
          const SizedBox(height: 24),

          _sectionHeader('💪 Did you workout today?', textPrimary),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _workedOut = true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _workedOut ? AppTheme.success.withValues(alpha: 0.15) : cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _workedOut ? AppTheme.success : cardBorder),
                    ),
                    child: Center(child: Text('Yes', style: TextStyle(color: _workedOut ? AppTheme.success : textSec, fontWeight: FontWeight.w700))),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _workedOut = false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: !_workedOut ? AppTheme.error.withValues(alpha: 0.15) : cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: !_workedOut ? AppTheme.error : cardBorder),
                    ),
                    child: Center(child: Text('No', style: TextStyle(color: !_workedOut ? AppTheme.error : textSec, fontWeight: FontWeight.w700))),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          _sectionHeader('😰 Stress Level', textPrimary),
          Row(children: [
            const Text('😌', style: TextStyle(fontSize: 20)),
            Expanded(
              child: Slider(
                value: _stress.toDouble(),
                min: 1, max: 10, divisions: 9,
                activeColor: _stressColor(_stress),
                inactiveColor: _stressColor(_stress).withValues(alpha: 0.2),
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

          _sectionHeader('🍽️ Last Meal (hours before bed)', textPrimary),
          Slider(
            value: _hoursBeforeMeal.toDouble(),
            min: 0, max: 6, divisions: 6,
            label: '$_hoursBeforeMeal h',
            activeColor: AppTheme.primaryGold,
            inactiveColor: AppTheme.primaryGold.withValues(alpha: 0.2),
            onChanged: (v) => setState(() => _hoursBeforeMeal = v.round()),
          ),
          Center(
              child: Text('$_hoursBeforeMeal hours before bed',
                  style: const TextStyle(
                      color: AppTheme.primaryGold, fontWeight: FontWeight.w600))),
          const SizedBox(height: 24),

          _sectionHeader('📝 Notes (optional)', textPrimary),
          TextField(
            controller: _notesCtrl,
            maxLines: 3,
            style: TextStyle(color: textPrimary),
            decoration: InputDecoration(
              hintText: 'Anything notable today?',
              hintStyle: TextStyle(color: textSec),
              filled: true,
              fillColor: cardBg,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: cardBorder)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: cardBorder)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.primaryIndigo, width: 1.5)),
            ),
          ),
          const SizedBox(height: 36),

          if (_aiProjection != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryIndigo.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.primaryIndigo.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome, color: AppTheme.primaryIndigo, size: 20),
                      const SizedBox(width: 8),
                      Text('Nidra\'s Projection for Tonight',
                          style: TextStyle(color: textPrimary, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(_aiProjection!, style: TextStyle(color: textSec, height: 1.4)),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGold,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: _isSaving 
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.black))
                  : const Text('Save & Get Projection', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 32),
        ]),
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final p = context.read<JournalProvider>();
    
    // Create the entry
    JournalEntry entry = JournalEntry.newEvening().copyWith(
      caffeineUnits: _caffeine,
      alcoholUnits: _alcohol,
      stressLevel: _stress,
      hoursBeforeBedMeal: _hoursBeforeMeal,
      screenTimeHours: _screenTimeHours,
      workedOut: _workedOut,
      notes: _notesCtrl.text.trim(),
    );

    // Call Gemini for a projection if we don't have one yet
    if (_aiProjection == null) {
      try {
        final gemini = GeminiService();
        final projection = await gemini.projectSleepQuality(entry);
        if (!mounted) return;
        setState(() {
          _aiProjection = projection;
          entry = entry.copyWith(aiProjection: projection);
          _isSaving = false;
        });
        // We stop here to let them read the projection, they can press save again to exit
        p.updateEveningDraft(entry);
        await p.saveEvening();
        return;
      } catch (e) {
        // Silently fail projection on error and just save
      }
    }

    p.updateEveningDraft(entry);
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

  Widget _sectionHeader(String text, Color textPrimary) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text,
            style: TextStyle(
                color: textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 15)),
      );

  Widget _counterRow(int selected, int max, ValueChanged<int> onSelect,
      List<String> labels, Color cardBg, Color cardBorder, Color textSec) {
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
                    ? AppTheme.primaryIndigo.withValues(alpha: 0.15)
                    : cardBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: active ? AppTheme.primaryIndigo : cardBorder),
              ),
              child: Text(labels[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: active
                          ? AppTheme.primaryIndigo
                          : textSec,
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
