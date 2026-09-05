import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../providers/onboarding_provider.dart';
import '../utils/circadian_utils.dart';
import 'setup_completed_screen.dart';

class SetupFlowScreen extends StatefulWidget {
  const SetupFlowScreen({super.key});

  @override
  State<SetupFlowScreen> createState() => _SetupFlowScreenState();
}

class _SetupFlowScreenState extends State<SetupFlowScreen> with TickerProviderStateMixin {
  int _currentStep = 1;
  final PageController _pageController = PageController();

  // Local state for the fields
  String _name = '';
  String _dateOfBirth = '1998-06-14';
  String _gender = 'Female';
  
  double _heightCm = 172.0;
  double _weightKg = 68.0;
  String _heightUnit = 'cm';
  String _weightUnit = 'kg';
  
  String _currentBedtime = '00:00';
  String _currentWakeTime = '06:30';
  
  String _targetBedtime = '22:30';
  String _targetWakeTime = '07:00';
  
  List<String> _primarySleepGoals = ['Improve deep sleep'];
  
  final Map<String, bool> _stopAnswers = {
    'snoring': false,
    'tiredness': true,
    'observed': false,
    'pressure': false,
  };

  // Welcome Step 2 animation
  late AnimationController _typingController;
  late Animation<int> _typingAnimation;
  bool _showSubtitle = false;

  final List<Map<String, dynamic>> _sleepGoalOptions = [
    {'label': 'Improve deep sleep', 'icon': Icons.nights_stay_rounded, 'desc': 'Enhance stage 3 restorative rest'},
    {'label': 'Fall asleep faster', 'icon': Icons.bolt_rounded, 'desc': 'Reduce sleep onset latency & tossing'},
    {'label': 'Wake up refreshed', 'icon': Icons.wb_sunny_rounded, 'desc': 'Optimize awakening circadian cycle'},
    {'label': 'Fix circadian rhythm', 'icon': Icons.access_time_rounded, 'desc': 'Harmonize schedule with natural light'},
    {'label': 'Reduce snoring & fatigue', 'icon': Icons.volume_up_rounded, 'desc': 'Target airway health & daytime vitality'},
  ];

  @override
  void initState() {
    super.initState();
    _typingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _setupTypingAnimation();
  }

  void _setupTypingAnimation() {
    final targetName = _name.trim().isNotEmpty ? _name.trim().split(' ')[0] : 'friend';
    final fullText = 'Hi, $targetName.';
    _typingAnimation = StepTween(begin: 0, end: fullText.length).animate(
      CurvedAnimation(parent: _typingController, curve: Curves.linear),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          Future.delayed(const Duration(milliseconds: 350), () {
            if (mounted) setState(() => _showSubtitle = true);
          });
        }
      });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _typingController.dispose();
    super.dispose();
  }

  bool get _canContinue {
    switch (_currentStep) {
      case 1:
        return _name.trim().length > 1;
      case 2:
        return true;
      case 3:
        return _dateOfBirth.isNotEmpty && _gender.isNotEmpty;
      case 4:
        return _heightCm >= 90 && _heightCm <= 250 && _weightKg >= 30 && _weightKg <= 250;
      case 5:
        return _currentBedtime.isNotEmpty && _currentWakeTime.isNotEmpty;
      case 6:
        return _targetBedtime.isNotEmpty && _targetWakeTime.isNotEmpty;
      case 7:
        return _primarySleepGoals.isNotEmpty;
      case 8:
        return true;
      default:
        return false;
    }
  }

  void _handleNext() async {
    if (!_canContinue) return;
    
    if (_currentStep == 1) {
      _setupTypingAnimation();
      _typingController.forward(from: 0.0);
      _showSubtitle = false;
    }

    if (_currentStep < 8) {
      setState(() => _currentStep++);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    } else {
      // Finalize and save to provider
      final provider = context.read<OnboardingProvider>();
      
      final analysis = CircadianAnalysisResult.compute(
        _currentBedtime, _currentWakeTime, _targetBedtime, _targetWakeTime,
      );

      // BMI calculation
      final hMeter = _heightCm / 100;
      final rawBmi = _weightKg / (hMeter * hMeter);
      String bmiCategory = 'Optimal';
      if (rawBmi < 18.5) bmiCategory = 'Underweight';
      else if (rawBmi < 25) bmiCategory = 'Optimal';
      else if (rawBmi < 30) bmiCategory = 'Overweight';
      else bmiCategory = 'Elevated';

      int stopScore = _stopAnswers.values.where((v) => v).length;

      provider.updateName(_name.trim());
      provider.updateDateOfBirth(_dateOfBirth);
      provider.updateGender(_gender);
      provider.updateHeight(_heightCm);
      provider.updateWeight(_weightKg);
      provider.updateBmiCategory(bmiCategory);
      provider.updateCurrentSchedule(_currentBedtime, _currentWakeTime, analysis.currentDuration);
      provider.updateTargetSchedule(_targetBedtime, _targetWakeTime, analysis.targetDuration);
      provider.updateCircadianRecommendations(
        sleepDebtHours: analysis.dailyDebt,
        weeklySleepDebtHours: analysis.weeklyDebt,
        recommendedBedtime: analysis.recommendedBedtime,
        recommendedWakeTime: analysis.recommendedWakeTime,
        recommendedDurationHours: analysis.recommendedDuration,
        transitionStrategy: analysis.transitionStrategy,
      );
      provider.updatePrimarySleepGoals(_primarySleepGoals);
      provider.updateStopAnswers(_stopAnswers, stopScore);
      
      await provider.completeOnboarding();
      
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const SetupCompletedScreen(),
            transitionsBuilder: (_, anim, __, child) => 
                FadeTransition(opacity: anim, child: child),
            transitionDuration: const Duration(milliseconds: 600),
          ),
        );
      }
    }
  }

  void _handleBack() {
    if (_currentStep > 1) {
      setState(() => _currentStep--);
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _pickTime(bool isBedtime, bool isCurrent) async {
    final currentTimeStr = isCurrent 
      ? (isBedtime ? _currentBedtime : _currentWakeTime)
      : (isBedtime ? _targetBedtime : _targetWakeTime);
      
    final parts = currentTimeStr.split(':');
    final initialTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));

    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF3B5BDB),
              surface: Color(0xFF1A1A2E),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final formatted = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      setState(() {
        if (isCurrent) {
          if (isBedtime) _currentBedtime = formatted;
          else _currentWakeTime = formatted;
        } else {
          if (isBedtime) _targetBedtime = formatted;
          else _targetWakeTime = formatted;
        }
      });
    }
  }

  Future<void> _pickDate() async {
    final parts = _dateOfBirth.split('-');
    final initialDate = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF3B5BDB),
              surface: Color(0xFF1A1A2E),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _dateOfBirth = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFF07111F),
        body: SafeArea(
          child: Column(
            children: [
              _buildTopNav(),
              _buildProgressBar(),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildStep1Name(),
                    _buildStep2Greeting(),
                    _buildStep3DOBGender(),
                    _buildStep4Body(),
                    _buildStep5CurrentRoutine(),
                    _buildStep6TargetRoutine(),
                    _buildStep7Goals(),
                    _buildStep8Stop(),
                  ],
                ),
              ),
              _buildBottomAction(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopNav() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: _handleBack,
            icon: const Icon(Icons.chevron_left_rounded, color: Colors.white, size: 28),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.1),
            ),
          ),
          Text(
            '$_currentStep / 8',
            style: GoogleFonts.inter(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: List.generate(8, (index) {
          final step = index + 1;
          final isActive = _currentStep >= step;
          return Expanded(
            child: Container(
              height: 4,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: isActive ? const Color(0xFF3B5BDB) : Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildBottomAction() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: _canContinue ? _handleNext : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF3B5BDB),
            disabledBackgroundColor: Colors.white.withValues(alpha: 0.05),
            foregroundColor: Colors.white,
            disabledForegroundColor: Colors.white38,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: _canContinue ? 4 : 0,
            shadowColor: const Color(0xFF3B5BDB).withValues(alpha: 0.4),
          ),
          child: Text(
            _currentStep == 8 ? 'Generate Sleep Synthesis' : 'Continue',
            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _buildStepHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          height: 1.2,
          letterSpacing: -0.5,
        ),
      ),
    );
  }

  // --- Step 1: Name ---
  Widget _buildStep1Name() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader('What should we call you?'),
          TextField(
            autofocus: true,
            style: GoogleFonts.inter(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Type your name...',
              hintStyle: GoogleFonts.inter(color: Colors.white24),
              border: InputBorder.none,
            ),
            onChanged: (val) => setState(() => _name = val),
            onSubmitted: (_) => _handleNext(),
          ),
        ],
      ),
    );
  }

  // --- Step 2: Greeting ---
  Widget _buildStep2Greeting() {
    final targetName = _name.trim().isNotEmpty ? _name.trim().split(' ')[0] : 'friend';
    final fullText = 'Hi, $targetName.';
    
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _typingAnimation,
            builder: (context, child) {
              final text = fullText.substring(0, _typingAnimation.value);
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    text,
                    style: GoogleFonts.inter(fontSize: 42, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  if (!_showSubtitle)
                    Container(
                      width: 4, height: 42,
                      margin: const EdgeInsets.only(left: 4),
                      color: const Color(0xFF3B5BDB),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          AnimatedOpacity(
            opacity: _showSubtitle ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 500),
            child: Text(
              'We\'re delighted to be your personal sleep companion. Let\'s calibrate your circadian rhythm for deeper, more restorative nights.',
              style: GoogleFonts.inter(fontSize: 16, color: Colors.white70, height: 1.6),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  // --- Step 3: DOB & Gender ---
  Widget _buildStep3DOBGender() {
    final dobDisplay = _dateOfBirth.isEmpty ? 'Select Date' : _dateOfBirth; // simplistic format
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader('When were you born?'),
          GestureDetector(
            onTap: _pickDate,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  dobDisplay,
                  style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B5BDB).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.calendar_today_rounded, color: Color(0xFF3B5BDB)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 48),
          Text(
            'Gender',
            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white54, letterSpacing: 1),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: ['Female', 'Male', 'Prefer not to say'].map((opt) {
              final isSelected = _gender == opt;
              return GestureDetector(
                onTap: () => setState(() => _gender = opt),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF3B5BDB) : const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: isSelected ? const Color(0xFF3B5BDB) : Colors.white12),
                  ),
                  child: Text(
                    opt,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? Colors.white : Colors.white70,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // --- Step 4: Body ---
  Widget _buildStep4Body() {
    final hMeter = _heightCm / 100;
    final bmi = _weightKg / (hMeter * hMeter);
    
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader('What is your height & weight?'),
          
          // Height
          _buildMeasurementRow(
            title: 'HEIGHT',
            value: _heightCm,
            unit: 'cm',
            onChanged: (v) => setState(() => _heightCm = v),
          ),
          const SizedBox(height: 32),
          
          // Weight
          _buildMeasurementRow(
            title: 'WEIGHT',
            value: _weightKg,
            unit: 'kg',
            onChanged: (v) => setState(() => _weightKg = v),
          ),
          
          const Spacer(),
          // BMI Display
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('CALCULATED BMI', style: GoogleFonts.inter(fontSize: 11, color: Colors.white54, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(bmi.toStringAsFixed(1), style: GoogleFonts.inter(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    bmi < 18.5 ? 'Underweight' : bmi < 25 ? 'Optimal' : bmi < 30 ? 'Overweight' : 'Elevated',
                    style: GoogleFonts.inter(color: const Color(0xFF34D399), fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMeasurementRow({required String title, required double value, required String unit, required Function(double) onChanged}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white54, letterSpacing: 1)),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(value.toStringAsFixed(0), style: GoogleFonts.inter(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(width: 8),
                Text(unit, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white54)),
              ],
            ),
            Row(
              children: [
                _buildRoundBtn(Icons.remove, () => onChanged(value - 1)),
                const SizedBox(width: 12),
                _buildRoundBtn(Icons.add, () => onChanged(value + 1)),
              ],
            )
          ],
        )
      ],
    );
  }

  Widget _buildRoundBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }

  // --- Step 5: Current Routine ---
  Widget _buildStep5CurrentRoutine() {
    final currentDuration = CircadianUtils.calculateSleepDuration(_currentBedtime, _currentWakeTime);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader('What is your current routine?'),
          Text(
            'Select when you regularly go to bed and wake up currently.',
            style: GoogleFonts.inter(color: Colors.white54, fontSize: 14),
          ),
          const SizedBox(height: 32),
          _buildTimeRow('Current Bedtime', _currentBedtime, Icons.nights_stay_rounded, true, true),
          const Divider(color: Colors.white12, height: 32),
          _buildTimeRow('Current Wake Up', _currentWakeTime, Icons.wb_sunny_rounded, false, true),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFF3B5BDB).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Estimated Rest Window', style: GoogleFonts.inter(color: Colors.white70, fontSize: 13)),
                Text('${CircadianUtils.formatDurationHours(currentDuration)} / night', style: GoogleFonts.inter(color: const Color(0xFF60A5FA), fontWeight: FontWeight.bold)),
              ],
            ),
          )
        ],
      ),
    );
  }

  // --- Step 6: Target Routine ---
  Widget _buildStep6TargetRoutine() {
    final targetDuration = CircadianUtils.calculateSleepDuration(_targetBedtime, _targetWakeTime);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader('What is your target schedule?'),
          Text(
            'Set your ideal bedtime and wake-up time for full cognitive and physical restoration.',
            style: GoogleFonts.inter(color: Colors.white54, fontSize: 14),
          ),
          const SizedBox(height: 32),
          _buildTimeRow('Target Bedtime', _targetBedtime, Icons.nights_stay_rounded, true, false),
          const Divider(color: Colors.white12, height: 32),
          _buildTimeRow('Target Wake Up', _targetWakeTime, Icons.wb_sunny_rounded, false, false),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFFF59E0B).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Target Rest Opportunity', style: GoogleFonts.inter(color: Colors.white70, fontSize: 13)),
                Text('${CircadianUtils.formatDurationHours(targetDuration)} / night', style: GoogleFonts.inter(color: const Color(0xFFFBBF24), fontWeight: FontWeight.bold)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildTimeRow(String label, String timeStr, IconData icon, bool isBedtime, bool isCurrent) {
    return GestureDetector(
      onTap: () => _pickTime(isBedtime, isCurrent),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white38, size: 24),
              const SizedBox(width: 16),
              Text(label, style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(12)),
            child: Text(CircadianUtils.formatTime12H(timeStr), style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
    );
  }

  // --- Step 7: Goals ---
  Widget _buildStep7Goals() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader('What are your sleep goals?'),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Select all that apply', style: GoogleFonts.inter(color: Colors.white54, fontSize: 14)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFF3B5BDB).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                child: Text('${_primarySleepGoals.length} selected', style: GoogleFonts.inter(color: const Color(0xFF818CF8), fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: _sleepGoalOptions.length,
              itemBuilder: (context, i) {
                final opt = _sleepGoalOptions[i];
                final isSelected = _primarySleepGoals.contains(opt['label']);
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        if (_primarySleepGoals.length > 1) _primarySleepGoals.remove(opt['label']);
                      } else {
                        _primarySleepGoals.add(opt['label']);
                      }
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF3B5BDB).withValues(alpha: 0.2) : const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isSelected ? const Color(0xFF3B5BDB) : Colors.white12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF3B5BDB) : const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(opt['icon'], color: isSelected ? Colors.white : Colors.white54, size: 20),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(opt['label'], style: GoogleFonts.inter(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Text(opt['desc'], style: GoogleFonts.inter(color: isSelected ? const Color(0xFF93C5FD) : Colors.white54, fontSize: 12)),
                            ],
                          ),
                        ),
                        Container(
                          width: 24, height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected ? const Color(0xFF3B5BDB) : Colors.transparent,
                            border: Border.all(color: isSelected ? const Color(0xFF3B5BDB) : Colors.white38),
                          ),
                          child: isSelected ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- Step 8: STOP ---
  Widget _buildStep8Stop() {
    final stopQuestions = [
      {'key': 'snoring', 'label': 'Snoring loudly during sleep', 'sub': 'Audible through closed doors'},
      {'key': 'tiredness', 'label': 'Frequent daytime tiredness', 'sub': 'Feeling drowsy or fatigued during the day'},
      {'key': 'observed', 'label': 'Observed breathing pauses', 'sub': 'Gasping or choking during sleep'},
      {'key': 'pressure', 'label': 'High blood pressure', 'sub': 'Diagnosed or treated hypertension'},
    ];

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader('Do you experience any of these?'),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: stopQuestions.length,
              itemBuilder: (context, i) {
                final q = stopQuestions[i];
                final isChecked = _stopAnswers[q['key']] ?? false;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _stopAnswers[q['key'] as String] = !isChecked;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isChecked ? const Color(0xFF3B5BDB).withValues(alpha: 0.2) : const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isChecked ? const Color(0xFF3B5BDB) : Colors.white12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(q['label'] as String, style: GoogleFonts.inter(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Text(q['sub'] as String, style: GoogleFonts.inter(color: isChecked ? const Color(0xFF93C5FD) : Colors.white54, fontSize: 12)),
                            ],
                          ),
                        ),
                        Container(
                          width: 24, height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isChecked ? const Color(0xFF3B5BDB) : Colors.transparent,
                            border: Border.all(color: isChecked ? const Color(0xFF3B5BDB) : Colors.white38),
                          ),
                          child: isChecked ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
