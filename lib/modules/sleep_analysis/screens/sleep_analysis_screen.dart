import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:just_audio/just_audio.dart';

import 'package:provider/provider.dart';
import '../providers/sleep_analysis_provider.dart';
import '../../onboarding/providers/onboarding_provider.dart';
import '../../rewards/providers/rewards_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/file_reader.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/recording_logger.dart';
import '../services/actigraphy_service.dart';
import '../models/sleep_report.dart';

class SleepAnalysisScreen extends StatefulWidget {
  final bool autoStart;
  final TimeOfDay? initialAlarmTime;
  const SleepAnalysisScreen({super.key, this.autoStart = false, this.initialAlarmTime});

  @override
  State<SleepAnalysisScreen> createState() => _SleepAnalysisScreenState();
}

class _SleepAnalysisScreenState extends State<SleepAnalysisScreen>
    with TickerProviderStateMixin {
  final AudioRecorder _recorder = AudioRecorder();
  final ActigraphyService _actigraphy = ActigraphyService();
  Timer? _recordingTimer;
  Timer? _alarmTimer;

  late AnimationController _pulseController;
  late AnimationController _rippleController;
  late Animation<double> _pulseAnim;
  late Animation<double> _rippleAnim;

  double _wakeUpProgress = 0.0;
  Timer? _holdProgressTimer;
  Timer? _vibrateTimer;

  final AudioPlayer _soundsPlayer = AudioPlayer();
  final AudioPlayer _alarmPlayer = AudioPlayer();
  TimeOfDay? _alarmTime;
  String? _activeSoundName;
  bool _isAlarmRinging = false;
  bool _isProcessing = false;
  // Static flag so the orphan-check guard survives widget dispose/rebuild.
  // Without this, a screen rebuild (e.g. triggered by the orphan dialog itself)
  // resets the flag to false and the popup fires twice.
  static bool _isCheckingOrphan = false;

  DateTime? _recordingStartTime;
  StreamSubscription<Amplitude>? _amplitudeSubscription;
  final ValueNotifier<double> _liveAmplitude = ValueNotifier(0.0);
  
  final List<Map<String, String>> _sleepSounds = [
    {'name': 'Brown Noise',        'url': 'https://archive.org/download/WhiteBrownNoise/BrownNoise.ogg'},
    {'name': 'Soft Rain',          'url': 'https://archive.org/download/RelaxingRainAndLoudThunderFreeFieldRecordingOfNatureSoundsForSleepOrMeditation/soft.ogg'},
    {'name': 'Waterfalls',         'url': 'https://archive.org/download/WhiteBrownNoise/VirtualWaterfalls.ogg'},
    {'name': 'Guided Meditation',  'url': 'https://archive.org/download/swmp167/SWMP167.mp3'},
    {'name': 'Calm Piano',         'url': 'https://archive.org/download/DreamlandByMikeHuber/16%20The%20End%20Of%20The%20Day%20Revox.mp3'},
    {'name': 'Instrumental Sleep', 'url': 'https://archive.org/download/sunflowertracks/sunflowertracks.mp3'},
    {'name': 'Forest Night',       'url': 'https://archive.org/download/QuietForestNightSoundEffects/Quiet%20Forest%20Night.mp3'},
    {'name': 'Ocean Waves',        'url': 'https://archive.org/download/OceanWaves_447/OceanWaves.mp3'},
  ];

  @override
  void initState() {
    super.initState();
    _alarmTime = widget.initialAlarmTime;

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    _pulseAnim = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _rippleAnim = Tween<double>(begin: 1.0, end: 1.6).animate(
      CurvedAnimation(parent: _rippleController, curve: Curves.easeOut),
    );
    
    if (widget.autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startRecording(context.read<SleepAnalysisProvider>());
      });
    } else {
      _checkAndShowPopups();
      // Check whether a previous recording was interrupted by a crash
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkOrphanedRecording();
      });
    }
    
    // Note: Alarm audio is loaded lazily when the alarm fires, not eagerly on init.
    // This avoids unnecessary network errors when starting a recording session.

    // Only start the alarm timer if an alarm was actually set — avoids
    // firing a 1-second tick on every idle screen open with no alarm.
    if (_alarmTime != null) {
      _alarmTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        _checkAlarm();
      });
    }
  }

  Future<void> _checkAndShowPopups() async {
    final prefs = await SharedPreferences.getInstance();
    final hideTips = prefs.getBool('hideRecordingTips') ?? false;
    
    if (!hideTips && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showTipsPopup(prefs);
      });
    }
  }

  void _showTipsPopup(SharedPreferences prefs) {
    bool dontShowAgain = false;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          padding: const EdgeInsets.fromLTRB(28, 20, 28, 36),
          decoration: const BoxDecoration(
            color: Color(0xFF151728),
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 24)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: (Theme.of(context).brightness == Brightness.light ? AppTheme.cardBorderLight : AppTheme.cardBorder),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Icon + Title
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.primaryIndigo.withValues(alpha: 0.18),
                      border: Border.all(
                        color: AppTheme.primaryIndigo.withValues(alpha: 0.4),
                        width: 1.2,
                      ),
                    ),
                    child: const Center(child: Text('💡', style: TextStyle(fontSize: 22))),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    'Recording Tips',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: (Theme.of(context).brightness == Brightness.light ? AppTheme.textPrimaryLight : AppTheme.textPrimary),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Tips list
              ...[
                (Icons.phone_android_rounded, 'Place phone face-down', 'Lay it beside your pillow for the best microphone pickup.'),
                (Icons.bolt_rounded, 'Keep it plugged in', 'An overnight recording needs your device charged throughout.'),
                (Icons.notifications_off_rounded, 'Silence notifications', 'Avoid interruptions for more accurate sleep analysis.'),
              ].map((tip) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: (Theme.of(context).brightness == Brightness.light ? AppTheme.surfaceLight : AppTheme.surfaceElevated),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: (Theme.of(context).brightness == Brightness.light ? AppTheme.cardBorderLight : AppTheme.cardBorder)),
                      ),
                      child: Icon(tip.$1, color: AppTheme.accentTeal, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tip.$2,
                            style: TextStyle(
                              color: (Theme.of(context).brightness == Brightness.light ? AppTheme.textPrimaryLight : AppTheme.textPrimary),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            tip.$3,
                            style: TextStyle(
                              color: (Theme.of(context).brightness == Brightness.light ? AppTheme.textSecondaryLight : AppTheme.textSecondary),
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
              const SizedBox(height: 8),
              // Don't show again
              GestureDetector(
                onTap: () => setSheetState(() => dontShowAgain = !dontShowAgain),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        color: dontShowAgain
                            ? AppTheme.primaryIndigo
                            : Colors.transparent,
                        border: Border.all(
                          color: dontShowAgain
                              ? AppTheme.primaryIndigo
                              : (Theme.of(context).brightness == Brightness.light ? AppTheme.cardBorderLight : AppTheme.cardBorder),
                          width: 1.5,
                        ),
                      ),
                      child: dontShowAgain
                          ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      "Don't show again",
                      style: TextStyle(color: (Theme.of(context).brightness == Brightness.light ? AppTheme.textSecondaryLight : AppTheme.textSecondary), fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Got it button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () {
                    if (dontShowAgain) prefs.setBool('hideRecordingTips', true);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentTeal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Got it!',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showInterferencePopup() async {
    final prefs = await SharedPreferences.getInstance();
    final hideInterference = prefs.getBool('hideInterferenceWarning') ?? false;
    
    if (hideInterference) return;

    bool dontShowAgain = false;
    if (mounted) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            backgroundColor: Theme.of(context).brightness == Brightness.light ? AppTheme.surfaceLight : AppTheme.surface,
            title: Text('Audio Interference', style: TextStyle(color: (Theme.of(context).brightness == Brightness.light ? AppTheme.textPrimaryLight : AppTheme.textPrimary))),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Background audio or music may interfere with snoring detection. We recommend turning off all other audio for accurate results.',
                  style: TextStyle(color: (Theme.of(context).brightness == Brightness.light ? AppTheme.textSecondaryLight : AppTheme.textSecondary), height: 1.5)),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Checkbox(
                      value: dontShowAgain,
                      activeColor: AppTheme.primaryIndigo,
                      onChanged: (v) => setDialogState(() => dontShowAgain = v ?? false),
                    ),
                    Text("Don't show again", style: TextStyle(color: (Theme.of(context).brightness == Brightness.light ? AppTheme.textSecondaryLight : AppTheme.textSecondary), fontSize: 13)),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  if (dontShowAgain) prefs.setBool('hideInterferenceWarning', true);
                  Navigator.pop(context);
                },
                child: const Text('Continue', style: TextStyle(color: AppTheme.accentTeal, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      );
    }
  }
  @override
  void dispose() {
    _pulseController.dispose();
    _rippleController.dispose();
    _recordingTimer?.cancel();
    _alarmTimer?.cancel();
    _holdProgressTimer?.cancel();
    _vibrateTimer?.cancel();
    _amplitudeSubscription?.cancel();
    _recorder.dispose();
    _soundsPlayer.dispose();
    _alarmPlayer.dispose();
    super.dispose();
  }

  // ── Recording ─────────────────────────────────────────────────────

  Future<void> _startRecording(SleepAnalysisProvider provider) async {
    if (_isProcessing) return;
    HapticFeedback.mediumImpact();
    await _doStartRecording(provider);
  }

  Future<void> _doStartRecording(SleepAnalysisProvider provider) async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      _showPermissionSnack();
      return;
    }

    // Show Interference warning if not suppressed
    await _showInterferencePopup();

    if (!kIsWeb) {
      final isIgnoring = await FlutterForegroundTask.isIgnoringBatteryOptimizations;
      if (!isIgnoring && mounted) {
        // Ask the user to grant battery optimization exemption via the system
        // Settings page. This is the ONLY reliable way to prevent Android from
        // killing the foreground service overnight on most OEMs (Samsung, Xiaomi,
        // OnePlus, etc.). A soft tip dialog does NOT actually grant the exemption.
        final bool? shouldRequest = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: Theme.of(context).brightness == Brightness.light ? AppTheme.surfaceLight : (Theme.of(context).brightness == Brightness.light ? AppTheme.surfaceLight : AppTheme.surfaceElevated),
            title: Text('🔋 Allow Overnight Recording',
                style: TextStyle(color: (Theme.of(context).brightness == Brightness.light ? AppTheme.textPrimaryLight : AppTheme.textPrimary))),
            content: Text(
              'To prevent Android from stopping your recording overnight, '
              'please tap "Allow" on the next screen to disable battery optimization for SnoreClinics AI.\n\n'
              'Without this, your phone may kill the app while you sleep.',
              style: TextStyle(color: (Theme.of(context).brightness == Brightness.light ? AppTheme.textSecondaryLight : AppTheme.textSecondary), height: 1.5),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Skip',
                    style: TextStyle(color: (Theme.of(context).brightness == Brightness.light ? AppTheme.textSecondaryLight : AppTheme.textSecondary))),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Open Settings',
                    style: TextStyle(color: AppTheme.accentTeal, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
        if (shouldRequest == true) {
          // Opens the system battery optimization exemption page for this app.
          await FlutterForegroundTask.requestIgnoreBatteryOptimization();
        }
      }
    }

    String path;
    if (kIsWeb) {
      // On web, record package uses a temp path
      path = 'sleep_recording.pcm';
    } else {
      final dir = await getApplicationDocumentsDirectory();
      path = '${dir.path}/sleep_${DateTime.now().millisecondsSinceEpoch}.pcm';
    }

    // ── Start foreground service to keep recording alive overnight ──
    if (!kIsWeb) {
      FlutterForegroundTask.init(
        androidNotificationOptions: AndroidNotificationOptions(
          channelId: 'sleep_recording',
          channelName: 'Sleep Recording',
          channelDescription: 'Keeps the app running while recording your sleep.',
          // Use DEFAULT importance — LOW allows Android to deprioritize and
          // eventually kill the service on aggressive OEMs like Samsung/Xiaomi.
          channelImportance: NotificationChannelImportance.DEFAULT,
          priority: NotificationPriority.DEFAULT,
        ),
        iosNotificationOptions: const IOSNotificationOptions(
          showNotification: true,
          playSound: false,
        ),
        foregroundTaskOptions: ForegroundTaskOptions(
          autoRunOnBoot: false,
          autoRunOnMyPackageReplaced: false,
          allowWakeLock: true,
          allowWifiLock: false,
          // Repeat every 15 minutes to keep the process alive and refresh
          // the wake lock on devices that aggressively manage background tasks.
          eventAction: ForegroundTaskEventAction.repeat(900000),
        ),
      );
      await FlutterForegroundTask.startService(
        notificationTitle: 'Recording Sleep...',
        notificationText: 'SnoreClinics AI is listening for snoring.',
        callback: startCallback,
      );
      RecordingLogger().info('Foreground service started');
      debugPrint('[Recording] Foreground service started');
    }

    RecordingLogger().info('Starting AudioRecorder at path: $path');
    try {
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1, // mono is enough for sleep analysis
          autoGain: false,
          echoCancel: false,
          noiseSuppress: false,
        ),
        path: path,
      );
    } catch (e) {
      RecordingLogger().error('AudioRecorder failed to start', e);
      // Stop the foreground service — it was started above but the recorder failed
      if (!kIsWeb) {
        await FlutterForegroundTask.stopService();
        RecordingLogger().info('Foreground service stopped after recorder failure');
      }
      if (mounted) _showError('Could not start microphone recording. Please check permissions and try again.');
      return;
    }

    // Persist the path so we can recover the file if the app is killed overnight
    if (!kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('active_recording_path', path);
      await prefs.setInt('active_recording_start_ms', DateTime.now().millisecondsSinceEpoch);
    }

    RecordingLogger().info('AudioRecorder started successfully');
    provider.setRecordingActive(true);
    _recordingStartTime = DateTime.now();
    _listenToAmplitude(provider);
    _rippleController.repeat(reverse: false);

    // Start actigraphy alongside audio recording (best-effort — optional)
    if (!kIsWeb) {
      try {
        await _actigraphy.startRecording();
        RecordingLogger().info('Actigraphy started');
      } catch (e) {
        RecordingLogger().warning('Actigraphy failed to start (sensor not available): $e');
      }
    }

    if (_alarmTime != null) {
      DateTime alarmDt = DateTime(
          _recordingStartTime!.year, _recordingStartTime!.month, _recordingStartTime!.day,
          _alarmTime!.hour, _alarmTime!.minute);
      if (alarmDt.isBefore(_recordingStartTime!)) alarmDt = alarmDt.add(const Duration(days: 1));
      NotificationService().scheduleBackupAlarm(alarmDt);
    }

    // Update the displayed timer every second for a smooth clock display.
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_recordingStartTime != null) {
        provider.updateRecordingDuration(
          DateTime.now().difference(_recordingStartTime!),
        );
      }
    });
  }

  void _listenToAmplitude(SleepAnalysisProvider provider) {
    // Cancel any existing subscription before creating a new one
    _amplitudeSubscription?.cancel();
    // Poll every 100ms for smooth live UI animation.
    // We update a local ValueNotifier instead of the global provider to avoid
    // triggering heavy screen rebuilds thousands of times overnight.
    _amplitudeSubscription = _recorder.onAmplitudeChanged(const Duration(milliseconds: 100)).listen((amp) {
      if (!mounted) return;
      // Normalize from approx -60dB..0dB to 0.0..1.0
      final normalized = (amp.current + 60).clamp(0, 60) / 60.0;
      _liveAmplitude.value = normalized;
    });
  }

  Future<void> _stopAndAnalyse(SleepAnalysisProvider provider) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    
    try {
      HapticFeedback.heavyImpact();
      NotificationService().cancelBackupAlarm();
    _recordingTimer?.cancel();
    _rippleController.stop();
    _rippleController.reset();
    await _soundsPlayer.stop();
    await _alarmPlayer.stop();
    _isAlarmRinging = false;

    if (!mounted) return;
    // Capture the navigator and context variables before any async gaps to ensure they're still valid
    final nav = Navigator.of(context);
    final onboarding = context.read<OnboardingProvider>();
    final goalMinutes = onboarding.profile.goalDurationMinutes;
    final healthEnabled = onboarding.profile.healthIntegrationEnabled;

    RecordingLogger().info('User initiated stop recording. Duration: ${provider.recordingDuration.inSeconds}s');

    // ── First, grab the path from SharedPreferences BEFORE stopping.
    // If the app was killed and restored, _recorder is a brand-new instance
    // that was never started, so _recorder.stop() will return null.
    // We must read the persisted path before anything clears it.
    String? fallbackPath;
    if (!kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      fallbackPath = prefs.getString('active_recording_path');
    }

    String? stoppedPath;
    try {
      stoppedPath = await _recorder.stop();
    } catch (e) {
      RecordingLogger().warning('_recorder.stop() threw (likely never started): $e');
    }
    RecordingLogger().info('AudioRecorder stopped, saved to: $stoppedPath');

    // ── Fallback: if _recorder.stop() returns null, recover from SharedPreferences.
    if (stoppedPath == null && fallbackPath != null && !kIsWeb) {
      if (File(fallbackPath).existsSync()) {
        stoppedPath = fallbackPath;
        RecordingLogger().info('Recovered recording path from SharedPreferences: $fallbackPath');
      }
    }

    if (!kIsWeb) {
      // Clear the crash-recovery flag — normal stop means no orphan to recover
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('active_recording_path');
      await prefs.remove('active_recording_start_ms');

      await FlutterForegroundTask.stopService();
      RecordingLogger().info('Foreground service stopped');
    }

    // Stop actigraphy and collect motion samples
    List<SleepMotionSample> motionSamples = [];
    if (!kIsWeb && _actigraphy.isRecording) {
      try {
        motionSamples = _actigraphy.stopRecording();
        RecordingLogger().info('Actigraphy stopped. Collected ${motionSamples.length} motion samples.');
      } catch (e) {
        RecordingLogger().warning('Actigraphy stop error (non-fatal): $e');
      }
    }

    provider.setRecordingActive(false);

    if (stoppedPath == null) {
      RecordingLogger().error('Recording stopped but no file was saved.');
      _showError('Recording stopped but no file was saved.');
      return;
    }

    if (provider.recordingDuration.inSeconds < 30) {
      RecordingLogger().warning('Recording too short (<30s), discarding file: $stoppedPath');
      if (!context.mounted) {
        if (!kIsWeb) await PlatformFileReader.deleteFile(stoppedPath);
        return;
      }
      _showMinimumDurationWarning();
      if (!kIsWeb) {
        await PlatformFileReader.deleteFile(stoppedPath);
      }
      return;
    }

    if (provider.recordingDuration.inMinutes < 10) {
      if (!mounted) return;
      final bool? shouldSave = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Short Recording'),
          content: const Text('This recording is under 10 minutes. A full sleep cycle usually takes over an hour. Do you still want to save and analyze it?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Discard'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Analyze Anyway'),
            ),
          ],
        ),
      );
      if (shouldSave != true) {
        if (!kIsWeb) {
          await PlatformFileReader.deleteFile(stoppedPath);
        }
        return;
      }
    }

    final name = stoppedPath.split('/').last.split('\\').last;

    if (kIsWeb) {
      _showError('Web platform does not support real audio analysis. Please use the Android app.');
      return;
    } else {
      provider.setRecordedFile(stoppedPath, name);
      // Always pass the precise recording start time so that charts
      // show the correct clock-based X-axis labels (not an approximation).
      if (_recordingStartTime != null) {
        provider.setExplicitStartTime(_recordingStartTime!);
      }
      if (!mounted) return;

      // Context variables were captured synchronously before the async gap at the start of the method

      RecordingLogger().info('Calling analyzeCurrentFile()...');
      final report = await provider.analyzeCurrentFile(
        goalMinutes: goalMinutes,
        healthIntegrationEnabled: healthEnabled,
        motionSamples: motionSamples,
      );
      
      if (!mounted) return;
      
      if (report != null) {
        // EARN REWARD
        context.read<RewardsProvider>().earn('sleep_log_complete', 'sleep_${report.recordedAt.millisecondsSinceEpoch}');

        // ── Automated Cleanup (only on success — preserve file if analysis failed) ──
        if (!kIsWeb) {
          await PlatformFileReader.deleteFile(stoppedPath);
        }
        nav.pushNamed(AppRouter.sleepReport, arguments: report);
      } else if (provider.state == AnalysisState.error) {
        _showError('Analysis failed: ${provider.errorMessage ?? 'Unknown error'}');
      }
    } // end else (non-web)
  } catch (e, stack) {
    RecordingLogger().error('Error during stop/analysis', e, stack);
    if (mounted) _showError('Error during analysis: $e');
  } finally {
    if (mounted) setState(() => _isProcessing = false);
  }
}



  void _showPermissionSnack() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Microphone permission is required to record sleep audio.'),
      backgroundColor: AppTheme.error,
    ));
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppTheme.error,
    ));
  }

  void _showMinimumDurationWarning() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: (Theme.of(context).brightness == Brightness.light ? AppTheme.surfaceLight : AppTheme.surfaceElevated),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 20)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🥱', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text(
              'Recording too short',
              style: Theme.of(context).textTheme.displaySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Recording should be more than 30s to provide accurate analysis. Please go back to sleep and try again later!',
              style: TextStyle(color: (Theme.of(context).brightness == Brightness.light ? AppTheme.textSecondaryLight : AppTheme.textSecondary), fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryIndigo,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Back to Sleep', style: TextStyle(fontSize: 18)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Crash recovery ───────────────────────────────────────────────

  /// Checks whether a previous recording session was interrupted by a crash.
  /// If an active_recording_path is found in SharedPreferences and the file
  /// exists on disk, offers the user the option to analyze it.
  Future<void> _checkOrphanedRecording() async {
    if (kIsWeb || !mounted) return;
    // Guard: prevent re-entrant calls (e.g. screen re-created while popup is showing)
    if (_isCheckingOrphan) return;
    _isCheckingOrphan = true;
    try {
      // Guard: if the recorder is actively recording, the file in prefs is LIVE, not orphaned
      if (await _recorder.isRecording()) {
        _isCheckingOrphan = false;
        return;
      }
      // Also check the provider state — recording may have started but isRecording() may lag
      if (mounted && context.read<SleepAnalysisProvider>().isRecording) {
        _isCheckingOrphan = false;
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      
      // Guard: Check if the background service is still running.
      // If it is, Android killed the UI overnight but kept the recording alive.
      // We silently restore the UI state instead of showing the orphan dialog.
      if (await FlutterForegroundTask.isRunningService) {
        final startMs = prefs.getInt('active_recording_start_ms');
        if (startMs != null && mounted) {
          final provider = context.read<SleepAnalysisProvider>();
          final startTime = DateTime.fromMillisecondsSinceEpoch(startMs);
          provider.setExplicitStartTime(startTime);
          // Restore the recording duration so _stopAndAnalyse has the correct elapsed time
          provider.updateRecordingDuration(DateTime.now().difference(startTime));
          provider.setRecordingActive(true);
          // Also restore _recordingStartTime so the 1-second timer displays correctly
          _recordingStartTime = startTime;
          _recordingTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
            if (_recordingStartTime != null) {
              provider.updateRecordingDuration(
                DateTime.now().difference(_recordingStartTime!),
              );
            }
          });
        }
        _isCheckingOrphan = false;
        return;
      }

      final orphanPath = prefs.getString('active_recording_path');
      if (orphanPath == null) return;

      final file = File(orphanPath);
      if (!await file.exists()) {
        // File is gone — clean up the stale key
        await prefs.remove('active_recording_path');
        await prefs.remove('active_recording_start_ms');
        return;
      }

      int startMs = prefs.getInt('active_recording_start_ms') ?? 0;
      if (startMs == 0) {
        try {
          final stat = file.statSync();
          startMs = stat.changed.millisecondsSinceEpoch;
        } catch (_) {
          startMs = DateTime.now().subtract(const Duration(hours: 1)).millisecondsSinceEpoch;
        }
      }
      final startTime = DateTime.fromMillisecondsSinceEpoch(startMs);
      final elapsed = DateTime.now().difference(startTime);

      // Only offer recovery for recordings ≥ 1 minute
      if (elapsed.inSeconds < 60) {
        await prefs.remove('active_recording_path');
        await prefs.remove('active_recording_start_ms');
        await file.delete();
        return;
      }

      RecordingLogger().warning(
        'Orphaned recording detected: $orphanPath (duration: ~${elapsed.inMinutes}m). App was likely killed overnight.',
      );

      if (!mounted) {
        _isCheckingOrphan = false;
        return;
      }
      final nav = Navigator.of(context);
      // Keep _isCheckingOrphan = true for the ENTIRE duration of the bottom sheet
      // so that widget rebuilds don't trigger a second orphan popup.
      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.transparent,
        isDismissible: false,
        builder: (ctx) => Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: (Theme.of(context).brightness == Brightness.light ? AppTheme.surfaceLight : AppTheme.surfaceElevated),
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 20)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('😴', style: TextStyle(fontSize: 56)),
              const SizedBox(height: 16),
              Text(
                'Incomplete Recording Found',
                style: Theme.of(ctx).textTheme.displaySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'It looks like recording was interrupted last night (~${elapsed.inHours}h ${elapsed.inMinutes % 60}m captured). '
                'Would you like to analyze this recording?',
                style: TextStyle(color: (Theme.of(context).brightness == Brightness.light ? AppTheme.textSecondaryLight : AppTheme.textSecondary), fontSize: 15, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        // Clean up prefs AND file only on explicit discard
                        await prefs.remove('active_recording_path');
                        await prefs.remove('active_recording_start_ms');
                        try { await file.delete(); } catch (_) {}
                      },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: (Theme.of(context).brightness == Brightness.light ? AppTheme.textSecondaryLight : AppTheme.textSecondary)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text('Discard', style: TextStyle(color: (Theme.of(context).brightness == Brightness.light ? AppTheme.textSecondaryLight : AppTheme.textSecondary))),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        if (!mounted) return;
                        final provider = context.read<SleepAnalysisProvider>();
                        final onboarding = context.read<OnboardingProvider>();
                        final name = orphanPath.split('/').last;
                        provider.setRecordedFile(orphanPath, name);
                        provider.setExplicitStartTime(startTime);
                        // Set the actual elapsed duration so analysis uses correct time
                        provider.updateRecordingDuration(elapsed);
                        RecordingLogger().info('Analyzing orphaned recording: $orphanPath (start time: $startTime, duration: $elapsed)');
                        final report = await provider.analyzeCurrentFile(
                          goalMinutes: onboarding.profile.goalDurationMinutes,
                          healthIntegrationEnabled: onboarding.profile.healthIntegrationEnabled,
                        );
                        // Clear prefs AFTER analysis, not before
                        await prefs.remove('active_recording_path');
                        await prefs.remove('active_recording_start_ms');
                        if (!mounted) return;
                        if (report != null) {
                          try { await file.delete(); } catch (_) {}
                          if (!context.mounted) return;
                          nav.pushNamed(AppRouter.sleepReport, arguments: report);
                        } else {
                          try { await file.delete(); } catch (_) {}
                          _showError('Analysis failed: ${provider.errorMessage ?? 'Unknown error'}');
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryIndigo,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Analyze Recording'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    } catch (e) {
      RecordingLogger().error('Orphan check failed', e);
    } finally {
      _isCheckingOrphan = false;
    }
  }

  String _formatDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  // ── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Consumer<SleepAnalysisProvider>(
      builder: (context, provider, _) {
        if (provider.isRecording) {
          return _buildRecordingView(provider);
        }
        if (provider.state == AnalysisState.analysing) {
          return _buildAnalysingView();
        }
        return _buildIdleView(provider);
      },
    );
  }

  Widget _buildAnalysingView() {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Scaffold(
      backgroundColor: isLight ? AppTheme.backgroundLight : AppTheme.background,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pulsing brain icon
              AnimatedBuilder(
                animation: _pulseAnim,
                builder: (_, __) => Transform.scale(
                  scale: _pulseAnim.value,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [
                        AppTheme.primaryIndigo.withValues(alpha: 0.4),
                        AppTheme.primaryIndigo.withValues(alpha: 0.05),
                      ]),
                      border: Border.all(
                          color: AppTheme.primaryIndigo.withValues(alpha: 0.6),
                          width: 1.5),
                    ),
                    child: const Center(
                        child: Text('🧠', style: TextStyle(fontSize: 52))),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              Text(
                'Analysing Your Sleep',
                style: Theme.of(context).textTheme.displaySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Our AI is processing your recording.\nThis usually takes a few seconds…',
                style: TextStyle(
                    color: (Theme.of(context).brightness == Brightness.light ? AppTheme.textSecondaryLight : AppTheme.textSecondary),
                    fontSize: 15,
                    height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              const SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                  color: AppTheme.primaryIndigo,
                  strokeWidth: 3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Recording (active) view ───────────────────────────────────────

  Widget _buildRecordingView(SleepAnalysisProvider provider) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Scaffold(
      backgroundColor: isLight ? AppTheme.backgroundLight : AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Icon(
                      _alarmTime == null ? Icons.alarm_rounded : Icons.alarm_on_rounded, 
                      color: _alarmTime == null ? AppTheme.textPrimary : AppTheme.accentTeal,
                    ),
                    onPressed: _showAlarmSheet,
                  ),
                  Row(
                    children: [
                      const Icon(Icons.mic, color: AppTheme.error, size: 20),
                      const SizedBox(width: 6),
                      Text('REC', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppTheme.error)),
                    ],
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.music_note_rounded, 
                      color: _activeSoundName == null ? AppTheme.textPrimary : AppTheme.accentTeal,
                    ),
                    onPressed: _showSoundsSheet,
                  ),
                ],
              ),
            ),
            const Spacer(),
            Text(
              'Recording Sleep...',
              style: Theme.of(context).textTheme.displayMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Keep your phone nearby and go to sleep 😴',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 56),
            _buildPulsingMic(provider),
            const SizedBox(height: 40),
            Text(
              _formatDuration(provider.recordingDuration),
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.w700,
                color: (Theme.of(context).brightness == Brightness.light ? AppTheme.textPrimaryLight : AppTheme.textPrimary),
                letterSpacing: 2,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Recording in progress',
              style: TextStyle(color: (Theme.of(context).brightness == Brightness.light ? AppTheme.textSecondaryLight : AppTheme.textSecondary), fontSize: 14),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: StatefulBuilder(
                builder: (context, setState) {
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onForcePressStart: (_) {},
                    onLongPressStart: (_) {
                      _wakeUpProgress = 0.0;
                      _holdProgressTimer?.cancel();
                      _holdProgressTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
                        setState(() {
                          _wakeUpProgress += 50 / 2000; // 2 seconds to fill
                          if (_wakeUpProgress >= 1.0) {
                            _wakeUpProgress = 1.0;
                            timer.cancel();
                            _stopAndAnalyse(provider);
                          }
                        });
                      });
                    },
                    onLongPressEnd: (_) {
                      _holdProgressTimer?.cancel();
                      setState(() {
                        _wakeUpProgress = 0.0;
                      });
                    },
                    child: Container(
                      width: double.infinity,
                      height: 70,
                      decoration: BoxDecoration(
                        color: (Theme.of(context).brightness == Brightness.light ? AppTheme.surfaceLight : AppTheme.surfaceElevated),
                        borderRadius: BorderRadius.circular(35),
                        border: Border.all(color: AppTheme.primaryIndigo),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(35),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Positioned(
                              left: 0,
                              top: 0,
                              bottom: 0,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 50),
                                width: MediaQuery.of(context).size.width * _wakeUpProgress,
                                color: AppTheme.primaryIndigo.withValues(alpha: 0.8),
                              ),
                            ),
                            Text(
                              'Hold To Wake Up',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: _wakeUpProgress > 0.5 ? Colors.white : (Theme.of(context).brightness == Brightness.light ? AppTheme.textPrimaryLight : AppTheme.textPrimary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPulsingMic(SleepAnalysisProvider provider) {
    return ValueListenableBuilder<double>(
      valueListenable: _liveAmplitude,
      builder: (context, amplitude, child) {
        return AnimatedBuilder(
          animation: Listenable.merge([_pulseController, _rippleController]),
          builder: (_, __) {
            // Apply smoothing for a fluid UI response to loud noises
            final double activeScale = amplitude * 1.5;
            final bool isLoud = amplitude > 0.3;

            return SizedBox(
              width: 180,
              height: 180,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer Ripple (expands heavily on sound)
                  AnimatedScale(
                    scale: _rippleAnim.value + activeScale,
                    duration: const Duration(milliseconds: 100),
                    curve: Curves.easeOut,
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.error.withValues(
                              alpha: (1 - _rippleController.value) * 0.6),
                          width: 2 + (amplitude * 6),
                        ),
                      ),
                    ),
                  ),
                  // Inner Base Pulse
                  AnimatedScale(
                    scale: _pulseAnim.value + (activeScale * 0.5),
                    duration: const Duration(milliseconds: 100),
                    curve: Curves.easeOut,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isLoud 
                            ? AppTheme.error.withValues(alpha: 0.6) 
                            : AppTheme.error.withValues(alpha: 0.15),
                        border: Border.all(
                          color: AppTheme.error.withValues(alpha: 0.7), 
                          width: 2
                        ),
                      ),
                      child: AnimatedScale(
                        scale: 1.0 + (amplitude * 0.6),
                        duration: const Duration(milliseconds: 100),
                        child: Icon(
                          Icons.mic_rounded,
                          color: isLoud ? Colors.white : AppTheme.error,
                          size: 52,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ── Idle view ─────────────────────────────────────────────────────

  Widget _buildIdleView(SleepAnalysisProvider provider) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Scaffold(
      backgroundColor: isLight ? AppTheme.backgroundLight : AppTheme.background,
      appBar: AppBar(
        backgroundColor: isLight ? AppTheme.backgroundLight : AppTheme.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Sleep Analysis',
          style: TextStyle(
            color: isLight ? AppTheme.textPrimaryLight : (Theme.of(context).brightness == Brightness.light ? AppTheme.textPrimaryLight : AppTheme.textPrimary),
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_rounded,
            color: isLight ? AppTheme.textPrimaryLight : (Theme.of(context).brightness == Brightness.light ? AppTheme.textPrimaryLight : AppTheme.textPrimary),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeroCard(provider),
              const SizedBox(height: 28),
              _buildHowItWorksSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroCard(SleepAnalysisProvider provider) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isLight
              ? [const Color(0xFF4F46E5), const Color(0xFF7C3AED)]
              : [const Color(0xFF1A1D3A), const Color(0xFF0F1120)],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isLight
              ? const Color(0xFF4F46E5).withValues(alpha: 0.35)
              : (Theme.of(context).brightness == Brightness.light ? AppTheme.cardBorderLight : AppTheme.cardBorder),
          width: isLight ? 0 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isLight
                ? const Color(0xFF4F46E5).withValues(alpha: 0.28)
                : Colors.black.withValues(alpha: 0.5),
            blurRadius: isLight ? 32 : 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Moon icon with glow ring
          ScaleTransition(
            scale: _pulseAnim,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: isLight ? 0.15 : 0.08),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.35),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.12),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Center(
                child: Text('🌙', style: TextStyle(fontSize: 40)),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Title
          Text(
            'Sleep Sound Analyser',
            style: TextStyle(
              color: Theme.of(context).brightness == Brightness.light ? AppTheme.textPrimaryLight : Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          // Subtitle
          Text(
            'Start recording before you sleep. Stop when you wake up — we\'ll generate a full sleep quality report.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.78),
              fontSize: 14,
              height: 1.55,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          // Start button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _isProcessing ? null : () => _startRecording(provider),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: isLight ? const Color(0xFF4F46E5) : AppTheme.primaryIndigo,
                disabledBackgroundColor: Colors.white.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                elevation: 0,
              ),
              icon: Icon(
                Icons.mic_rounded,
                size: 22,
                color: isLight ? const Color(0xFF4F46E5) : AppTheme.primaryIndigo,
              ),
              label: Text(
                'Start Recording',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: isLight ? const Color(0xFF4F46E5) : AppTheme.primaryIndigo,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildHowItWorksSection() {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final textPrimary = isLight ? AppTheme.textPrimaryLight : (Theme.of(context).brightness == Brightness.light ? AppTheme.textPrimaryLight : AppTheme.textPrimary);
    final textSec = isLight ? AppTheme.textSecondaryLight : (Theme.of(context).brightness == Brightness.light ? AppTheme.textSecondaryLight : AppTheme.textSecondary);
    final cardBg = isLight ? Colors.white : const Color(0xFF151728);
    final cardBorder = isLight ? const Color(0xFFE2E8F0) : (Theme.of(context).brightness == Brightness.light ? AppTheme.cardBorderLight : AppTheme.cardBorder);

    final steps = [
      (
        Icons.bedtime_rounded,
        const Color(0xFF6366F1),
        'Tap "Start Recording"',
        'Place your phone face-down beside your pillow and drift off to sleep.',
      ),
      (
        Icons.alarm_on_rounded,
        const Color(0xFF10B981),
        'Wake Up & Hold to Stop',
        'In the morning, hold the "Hold To Wake Up" button for 2 seconds to stop and analyse.',
      ),
      (
        Icons.bar_chart_rounded,
        const Color(0xFF8B5CF6),
        'Get Your Report',
        'View your snoring score, sleep quality, detected events, and personalised tips.',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'How It Works',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: textPrimary,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 16),
        ...steps.asMap().entries.map((entry) {
          final i = entry.key;
          final step = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: cardBorder),
                boxShadow: isLight
                    ? [
                        BoxShadow(
                          color: step.$2.withValues(alpha: 0.08),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : [],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Step number + icon
                  Column(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: step.$2.withValues(alpha: isLight ? 0.12 : 0.18),
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(
                            color: step.$2.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Icon(step.$1, color: step.$2, size: 22),
                      ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: step.$2.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Center(
                                child: Text(
                                  '${i + 1}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: step.$2,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                step.$3,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          step.$4,
                          style: TextStyle(
                            fontSize: 13,
                            color: textSec,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
  // ── Audio Feature Modals ──────────────────────────────────────────

  void _checkAlarm() {
    if (_alarmTime == null || _isAlarmRinging) return;
    final now = TimeOfDay.now();
    if (now.hour == _alarmTime!.hour && now.minute == _alarmTime!.minute) {
      // Cancel timer immediately so it doesn't fire 60 times during this minute
      _alarmTimer?.cancel();
      _alarmTimer = null;
      _triggerAlarm();
    }
  }

  /// Loads and plays the alarm audio lazily when the alarm fires.
  /// Falls back to repeating haptic vibration if audio is unavailable.
  Future<void> _playAlarmWithFallback() async {
    const alarmUrl = 'https://assets.mixkit.co/sfx/preview/mixkit-alarm-digital-clock-beep-989.mp3';
    try {
      await _alarmPlayer.setUrl(alarmUrl);
      await _alarmPlayer.setVolume(1.0);
      await _alarmPlayer.setLoopMode(LoopMode.one);
      await _alarmPlayer.play();
    } catch (e) {
      debugPrint('[Alarm] Audio playback failed, using vibration fallback: $e');
      // Vibration fallback — repeat every second while alarm is ringing
      _vibrateTimer?.cancel();
      _vibrateTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!_isAlarmRinging) {
          _vibrateTimer?.cancel();
          return;
        }
        HapticFeedback.heavyImpact();
      });
    }
  }


  void _triggerAlarm() {
    // Set flag immediately (direct assignment, not via setState) to prevent
    // the 1-second _alarmTimer from calling _triggerAlarm a second time
    // before setState has rebuilt the widget tree.
    _isAlarmRinging = true;
    if (mounted) setState(() {});

    // Stop any active sleep sounds and start the alarm ringtone
    _soundsPlayer.stop();
    _playAlarmWithFallback();

    if (mounted) {
      showGeneralDialog(
        context: context,
        barrierDismissible: false,
        transitionDuration: const Duration(milliseconds: 400),
        transitionBuilder: (ctx, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
        pageBuilder: (context, anim1, anim2) {
          return Scaffold(
            backgroundColor: Theme.of(context).brightness == Brightness.light ? AppTheme.backgroundLight : const Color(0xFF050510),
            body: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('⏰', style: TextStyle(fontSize: 90)),
                      const SizedBox(height: 28),
                      Text(
                        'Good Morning!',
                        style: TextStyle(
                          color: Theme.of(context).brightness == Brightness.light ? AppTheme.textPrimaryLight : Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Your alarm is ringing 🌅',
                        style: TextStyle(
                            color: Theme.of(context).brightness == Brightness.light ? AppTheme.textSecondaryLight : Colors.white.withValues(alpha: 0.55),
                            fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 60),
                      // ── Wake Up button ────────────────────────────
                      SizedBox(
                        width: double.infinity,
                        height: 60,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accentTeal,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20)),
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.wb_sunny_rounded, size: 20),
                          label: Text(
                            context.read<SleepAnalysisProvider>().isRecording 
                                ? 'Wake Up & Analyze Sleep' 
                                : 'Stop Alarm',
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                          onPressed: () {
                            _alarmPlayer.stop();
                            setState(() {
                              _isAlarmRinging = false;
                              _alarmTime = null;
                            });
                            Navigator.pop(context);
                            final provider = context.read<SleepAnalysisProvider>();
                            if (provider.isRecording) {
                              _stopAndAnalyse(provider);
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 14),
                      // ── Snooze button ─────────────────────────────
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Theme.of(context).brightness == Brightness.light ? AppTheme.textPrimaryLight : Colors.white70,
                            side: BorderSide(
                                color: Theme.of(context).brightness == Brightness.light ? AppTheme.cardBorderLight : Colors.white.withValues(alpha: 0.25),
                                width: 1.5),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20)),
                          ),
                          icon: const Icon(Icons.snooze_rounded, size: 20),
                          label: const Text('Snooze 10 minutes',
                              style: TextStyle(fontSize: 15)),
                          onPressed: () {
                            _alarmPlayer.stop();
                            Navigator.pop(context);
                            _snoozeAlarm();
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    }
  }

  void _snoozeAlarm() {
    final snoozeTime =
        DateTime.now().add(const Duration(minutes: 10));
    setState(() {
      _isAlarmRinging = false;
      _alarmTime =
          TimeOfDay(hour: snoozeTime.hour, minute: snoozeTime.minute);
    });
    NotificationService().scheduleBackupAlarm(snoozeTime);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('⏰  Snoozed for 10 minutes — recording continues'),
        backgroundColor: AppTheme.primaryIndigo,
        duration: Duration(seconds: 3),
      ));
    }
  }

  void _syncBackupAlarm() {
    if (_alarmTime != null) {
      final now = DateTime.now();
      var alarmDateTime = DateTime(now.year, now.month, now.day, _alarmTime!.hour, _alarmTime!.minute);
      if (alarmDateTime.isBefore(now)) {
        alarmDateTime = alarmDateTime.add(const Duration(days: 1));
      }
      NotificationService().scheduleBackupAlarm(alarmDateTime);
    } else {
      NotificationService().cancelBackupAlarm();
    }
  }

  void _showAlarmSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final isOn = _alarmTime != null;
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: (Theme.of(context).brightness == Brightness.light ? AppTheme.surfaceLight : AppTheme.surfaceElevated),
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: (Theme.of(context).brightness == Brightness.light ? AppTheme.cardBorderLight : AppTheme.cardBorder), borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Smart Alarm', style: TextStyle(fontSize: 20, color: Theme.of(context).brightness == Brightness.light ? AppTheme.textPrimaryLight : Colors.white, fontWeight: FontWeight.bold)),
                    Switch(
                      value: isOn,
                      activeThumbColor: AppTheme.accentTeal,
                      onChanged: (val) async {
                        if (val) {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.now(),
                            builder: (context, child) => Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: ColorScheme.dark(
                                  primary: AppTheme.accentTeal,
                                  surface: (Theme.of(context).brightness == Brightness.light ? AppTheme.surfaceLight : AppTheme.surfaceElevated),
                                ),
                              ),
                              child: child!,
                            ),
                          );
                          if (time != null && mounted) {
                            setState(() => _alarmTime = time);
                            _syncBackupAlarm();
                            setSheetState(() {});
                            _alarmTimer ??= Timer.periodic(const Duration(seconds: 1), (_) => _checkAlarm());
                          }
                        } else {
                          setState(() => _alarmTime = null);
                          _syncBackupAlarm();
                          setSheetState(() {});
                          _alarmTimer?.cancel();
                          _alarmTimer = null;
                        }
                      },
                    ),
                  ],
                ),
                if (isOn) ...[
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: _alarmTime ?? TimeOfDay.now(),
                        builder: (context, child) => Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: ColorScheme.dark(
                              primary: AppTheme.accentTeal,
                              surface: (Theme.of(context).brightness == Brightness.light ? AppTheme.surfaceLight : AppTheme.surfaceElevated),
                            ),
                          ),
                          child: child!,
                        ),
                      );
                      if (time != null && mounted) {
                        setState(() => _alarmTime = time);
                        _syncBackupAlarm();
                        setSheetState(() {});
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryIndigo.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.primaryIndigo.withValues(alpha: 0.3)),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _alarmTime!.format(context),
                        style: TextStyle(fontSize: 40, color: Theme.of(context).brightness == Brightness.light ? AppTheme.textPrimaryLight : Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showSoundsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: (Theme.of(context).brightness == Brightness.light ? AppTheme.surfaceLight : AppTheme.surfaceElevated),
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 20)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: (Theme.of(context).brightness == Brightness.light ? AppTheme.cardBorderLight : AppTheme.cardBorder), borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 24),
              Text('Sleep Sounds', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 16),
              ..._sleepSounds.map((snd) {
                final isPlaying = _activeSoundName == snd['name'];
                return ListTile(
                  title: Text(snd['name']!, style: TextStyle(color: (Theme.of(context).brightness == Brightness.light ? AppTheme.textPrimaryLight : AppTheme.textPrimary))),
                  trailing: isPlaying ? const Icon(Icons.stop_circle, color: AppTheme.accentTeal) : Icon(Icons.play_circle_outline, color: (Theme.of(context).brightness == Brightness.light ? AppTheme.textSecondaryLight : AppTheme.textSecondary)),
                  onTap: () async {
                    if (isPlaying) {
                      await _soundsPlayer.stop();
                      setState(() => _activeSoundName = null);
                      setSheetState(() => _activeSoundName = null);
                    } else {
                      setState(() => _activeSoundName = snd['name']);
                      setSheetState(() => _activeSoundName = snd['name']);
                      try {
                        await _soundsPlayer.setUrl(snd['url']!);
                        _soundsPlayer.setLoopMode(LoopMode.one); // loop infinitely
                        _soundsPlayer.setVolume(1.0);
                        _soundsPlayer.play();
                      } catch (e) {
                         debugPrint('Sound error: $e');
                      }
                    }
                  },
                );
              }),
              const SizedBox(height: 24),
              if (_activeSoundName != null)
                TextButton.icon(
                  onPressed: () async {
                    await _soundsPlayer.stop();
                    setState(() => _activeSoundName = null);
                    setSheetState(() => _activeSoundName = null);
                    if (!context.mounted) return;
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.stop, color: AppTheme.error),
                  label: const Text('Turn Off Sound', style: TextStyle(color: AppTheme.error)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(SleepTaskHandler());
}

class SleepTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}

  @override
  void onReceiveData(Object data) {}

  @override
  void onNotificationButtonPressed(String id) {}

  @override
  void onNotificationPressed() {
    FlutterForegroundTask.launchApp();
  }

  @override
  void onNotificationDismissed() {}
}
