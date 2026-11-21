import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:just_audio/just_audio.dart';

import 'package:provider/provider.dart';
import '../providers/sleep_analysis_provider.dart';
import '../../onboarding/providers/onboarding_provider.dart';
import '../../rewards/providers/rewards_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/file_reader.dart';
import '../../../core/utils/audio_tracks.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/recording_logger.dart';
import '../services/actigraphy_service.dart';
import '../models/sleep_report.dart';

class SleepAnalysisScreen extends StatefulWidget {
  static bool isScreenVisible = false;
  final bool autoStart;
  final TimeOfDay? initialAlarmTime;
  const SleepAnalysisScreen({super.key, this.autoStart = false, this.initialAlarmTime});

  @override
  State<SleepAnalysisScreen> createState() => _SleepAnalysisScreenState();
}

class _SleepAnalysisScreenState extends State<SleepAnalysisScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
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
  StreamSubscription<RecordState>? _recordStateSubscription;
  final ValueNotifier<double> _liveAmplitude = ValueNotifier(0.0);

  // ── Audio-interruption tracking ───────────────────────────────────
  // When a phone call or another app takes the microphone, the OS stops our
  // AudioRecorder. We track how long the interruption lasted so we can subtract
  // it from the wall-clock duration and feed the analyser the *actual* recorded
  // time rather than an inflated value that causes "recording time 1s" results.
  bool _isInterrupted = false;
  DateTime? _interruptionStartTime;
  Duration _totalInterruptedDuration = Duration.zero;
  OverlayEntry? _interruptionBannerEntry;

  // ── Multi-segment recording ────────────────────────────────────────
  // On Android, when another app takes the mic the OS issues a hard stop.
  // We restart recording to a NEW file and keep a list of all segment paths.
  // At analysis time we derive the total recorded duration by summing the
  // file sizes of every segment — so the analyser always sees the real audio
  // length rather than an inflated wall-clock value.
  final List<String> _recordingSegmentPaths = [];
  Timer? _restartSegmentTimer;
  Timer? _interruptionWatchdogTimer;
  bool _isStartingSegment = false;
  
  // ── Analysis stuck-state detection ─────────────────────────────────
  // Tracks how long analysis has been running so we can show the user
  // an escape option if it seems stuck (> 3 minutes).
  final ValueNotifier<int> _analysisElapsedSeconds = ValueNotifier(0);
  Timer? _analysisStuckTimer;
  final Set<String> _promptedReportFiles = {};
  
  // Sleep sounds are sourced from the shared audio_tracks.dart constant.
  // This avoids duplicating the URL list that wellness_screen.dart also uses.

  @override
  void initState() {
    super.initState();
    SleepAnalysisScreen.isScreenVisible = true;
    WidgetsBinding.instance.addObserver(this);
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
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final provider = context.read<SleepAnalysisProvider>();
        final isRunning = await FlutterForegroundTask.isRunningService;
        if (provider.isRecording || isRunning) {
          await _restoreLiveRecordingIfNeeded(provider);
        } else {
          _checkAndShowPopups();
          _checkOrphanedRecording();
        }
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
        builder: (context, setSheetState) {
          final isLight = Theme.of(context).brightness == Brightness.light;
          final sheetBg = isLight ? AppTheme.surfaceLight : const Color(0xFF151728);
          final textPrimary = isLight ? AppTheme.textPrimaryLight : AppTheme.textPrimary;
          final textSecondary = isLight ? AppTheme.textSecondaryLight : AppTheme.textSecondary;
          final borderColor = isLight ? AppTheme.cardBorderLight : AppTheme.cardBorder;
          final iconBg = isLight ? Colors.white : AppTheme.surfaceElevated;
          final bottomPad = MediaQuery.of(context).padding.bottom;
          return Container(
            padding: EdgeInsets.fromLTRB(28, 20, 28, 24 + bottomPad),
            decoration: BoxDecoration(
              color: sheetBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 24)],
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
                      color: borderColor,
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
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 22,
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
                          color: iconBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: borderColor),
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
                                color: textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              tip.$3,
                              style: TextStyle(
                                color: textSecondary,
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
                          color: dontShowAgain ? AppTheme.primaryIndigo : Colors.transparent,
                          border: Border.all(
                            color: dontShowAgain ? AppTheme.primaryIndigo : borderColor,
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
                        style: TextStyle(color: textSecondary, fontSize: 13),
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
          );
        },
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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      final provider = context.read<SleepAnalysisProvider>();
      if (provider.isRecording) {
        RecordingLogger().info('App resumed. Checking recording status...');
        _checkAndRecoverRecording(provider);
      }
    }
  }

  Future<void> _checkAndRecoverRecording(SleepAnalysisProvider provider) async {
    try {
      final isPaused = await _recorder.isPaused();
      final isRec = await _recorder.isRecording();
      if (_isInterrupted) {
        if (isRec && !isPaused) {
          _onRecordingResumed(provider);
        } else if (isPaused) {
          RecordingLogger().info('Resuming paused recorder on app resume...');
          await _recorder.resume();
          if (!await _recorder.isPaused()) {
            _onRecordingResumed(provider);
          }
        } else if (!isRec) {
          RecordingLogger().info('Recorder was stopped; starting new segment on app resume...');
          await _startNewRecordingSegment(provider);
        }
      } else {
        if (isPaused) {
          _handleInterruptionDetected(provider, 'app_resume_paused');
        } else if (!isRec) {
          _handleInterruptionDetected(provider, 'app_resume_stopped');
          await _startNewRecordingSegment(provider);
        }
      }
    } catch (e) {
      RecordingLogger().warning('Error in _checkAndRecoverRecording: $e');
    }
  }

  @override
  void dispose() {
    SleepAnalysisScreen.isScreenVisible = false;
    WidgetsBinding.instance.removeObserver(this);
    _pulseController.dispose();
    _rippleController.dispose();
    _recordingTimer?.cancel();
    _interruptionWatchdogTimer?.cancel();
    _alarmTimer?.cancel();
    _holdProgressTimer?.cancel();
    _vibrateTimer?.cancel();
    _amplitudeSubscription?.cancel();
    _recordStateSubscription?.cancel();
    _restartSegmentTimer?.cancel();
    _analysisStuckTimer?.cancel();
    _analysisElapsedSeconds.dispose();
    _interruptionBannerEntry?.remove();
    _interruptionBannerEntry = null;
    _recorder.dispose();
    _soundsPlayer.dispose();
    _alarmPlayer.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  Future<void> _restoreLiveRecordingIfNeeded(SleepAnalysisProvider provider) async {
    if (kIsWeb || !mounted) return;
    final isRunning = await FlutterForegroundTask.isRunningService;
    if (isRunning || provider.isRecording) {
      final prefs = await SharedPreferences.getInstance();
      final startMs = prefs.getInt('active_recording_start_ms');
      if (startMs != null && mounted) {
        final startTime = DateTime.fromMillisecondsSinceEpoch(startMs);
        provider.setExplicitStartTime(startTime);
        provider.updateRecordingDuration(DateTime.now().difference(startTime));
        provider.setRecordingActive(true);
        _recordingStartTime = startTime;
        
        final savedSegments = prefs.getStringList('active_recording_segments');
        if (savedSegments != null && savedSegments.isNotEmpty) {
          _recordingSegmentPaths.clear();
          _recordingSegmentPaths.addAll(savedSegments.where((p) => File(p).existsSync()));
        }

        _recordingTimer?.cancel();
        _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (_recordingStartTime != null && mounted) {
            provider.updateRecordingDuration(
              DateTime.now().difference(_recordingStartTime!),
            );
          }
        });
        _listenToAmplitude(provider);
        _listenToRecordState(provider);
      }
    }
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
        // WARNING: This is a critical battery optimization check.
        // On many modern Android devices, failure to grant this means the OS
        // WILL kill the background service within minutes or hours.
        final bool? shouldRequest = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: Theme.of(context).brightness == Brightness.light ? AppTheme.surfaceLight : AppTheme.surface,
            title: Text('🔋 CRITICAL: Allow Overnight Recording',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            content: Text(
              'Your phone has aggressive battery saving enabled. If you do not "Allow" battery optimization to be ignored on the next screen, the OS WILL kill this recording automatically.\n\n'
              'Please select "Allow" or "Unrestricted" to ensure your sleep analysis completes.',
              style: TextStyle(color: (Theme.of(context).brightness == Brightness.light ? AppTheme.textSecondaryLight : AppTheme.textSecondary), height: 1.5),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Open Settings', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
        if (shouldRequest == true) {
          await FlutterForegroundTask.requestIgnoreBatteryOptimization();
          
          final stillIgnoring = await FlutterForegroundTask.isIgnoringBatteryOptimizations;
          if (!stillIgnoring && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('⚠️ Battery Optimization is still active. Your recording may be killed by Android overnight!'),
                backgroundColor: Colors.redAccent,
                duration: Duration(seconds: 5),
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('⚠️ Recording started, but Android may kill the app without battery exemption.'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 5),
              ),
            );
          }
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

    // Reset segment tracking for this brand-new session
    _recordingSegmentPaths.clear();

    // ── Start foreground service to keep recording alive overnight ──
    if (!kIsWeb) {
      FlutterForegroundTask.init(
        androidNotificationOptions: AndroidNotificationOptions(
          channelId: 'sleep_recording',
          channelName: 'Sleep Recording',
          channelDescription: 'Keeps the app running while recording your sleep.',
          // Use MAX importance & HIGH priority so Android OS does NOT demote
          // or suspend the microphone background process during deep sleep (Doze mode).
          channelImportance: NotificationChannelImportance.MAX,
          priority: NotificationPriority.HIGH,
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
          // Repeat every 1 minute (60,000 ms) to keep the CPU awake, refresh
          // the wake lock, and prevent Android OS Doze mode from freezing the recording.
          eventAction: ForegroundTaskEventAction.repeat(60000),
        ),
      );
      await FlutterForegroundTask.startService(
        notificationTitle: 'Recording Sleep...',
        notificationText: 'Sleep Astra is listening for snoring.',
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
          audioInterruption: AudioInterruptionMode.pauseResume,
          androidConfig: AndroidRecordConfig(
            manageBluetooth: true,
            audioSource: AndroidAudioSource.mic,
          ),
          iosConfig: IosRecordConfig(
            allowHapticsAndSystemSoundsDuringRecording: true,
          ),
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
      await prefs.setStringList('active_recording_segments', [path]);
      await prefs.setInt('active_recording_start_ms', DateTime.now().millisecondsSinceEpoch);
    }

    await WakelockPlus.enable();
    RecordingLogger().info('WakelockPlus enabled');

    RecordingLogger().info('AudioRecorder started successfully');
    _recordingStartTime = DateTime.now();
    // Reset interruption state for this new session
    _isInterrupted = false;
    _interruptionStartTime = null;
    _totalInterruptedDuration = Duration.zero;
    // Use resetRecordingState() for brand-new sessions so _recordingDuration
    // is cleanly zeroed and the start time is locked in immediately.
    provider.resetRecordingState();
    provider.setInterrupted(false);
    provider.setExplicitStartTime(_recordingStartTime!);
    // Track first segment
    _recordingSegmentPaths.add(path);
    RecordingLogger().info('Recording segment 1 started: $path');
    _listenToAmplitude(provider);
    _listenToRecordState(provider);
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
    // NOTE: When interrupted, the timer keeps running (wall-clock) but we track
    // _totalInterruptedDuration separately so the analyser gets the real audio time.
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
    }, onError: (e) {
      RecordingLogger().warning('Amplitude stream error: $e');
    });
  }

  /// Listens to [RecordState] changes emitted by the platform recorder.
  ///
  /// On iOS a phone call triggers [RecordState.pause]; on Android it triggers
  /// [RecordState.stop]. Either way we treat it as an interruption: we stop
  /// the live-amplitude indicator, record when the interruption started, show
  /// a persistent banner, and mark the provider as interrupted.
  ///
  /// On Android (stop): after a short delay we restart recording to a NEW
  /// segment file so audio after the interruption is captured.
  ///
  /// When the state returns to [RecordState.record] (iOS resume after pause),
  /// we hide the banner and accumulate the interruption duration.
  /// Listens to [RecordState] changes emitted by the platform recorder.
  ///
  /// On iOS/Android with [AudioInterruptionMode.pauseResume], phone calls or
  /// system audio events trigger [RecordState.pause] (or [RecordState.stop] if the OS kills the mic).
  /// We mark the session as interrupted, pause live indicators, update notifications,
  /// and start an active watchdog to guarantee automatic resumption.
  void _listenToRecordState(SleepAnalysisProvider provider) {
    _recordStateSubscription?.cancel();
    _recordStateSubscription = _recorder.onStateChanged().listen((state) {
      if (!mounted) return;

      if (state == RecordState.pause || state == RecordState.stop) {
        // Only react if we're supposed to be recording (not a user-initiated stop)
        if (!_isInterrupted && provider.isRecording) {
          _handleInterruptionDetected(provider, state.name);
        }
      } else if (state == RecordState.record) {
        if (_isInterrupted) {
          _onRecordingResumed(provider);
        }
      }
    }, onError: (e) {
      RecordingLogger().warning('Record state stream error: $e');
    });
  }

  void _handleInterruptionDetected(SleepAnalysisProvider provider, String source) {
    if (_isInterrupted) return;
    _isInterrupted = true;
    _interruptionStartTime = DateTime.now();
    provider.setInterrupted(true);
    _liveAmplitude.value = 0.0; // freeze waveform
    RecordingLogger().warning(
      'Recording interrupted by external audio event (phone call / other app). '
      'Source: $source',
    );
    _showInterruptionBanner();

    if (!kIsWeb) {
      FlutterForegroundTask.updateService(
        notificationTitle: 'Recording Paused (In Call)',
        notificationText: 'Sleep Astra will resume once the call ends.',
      );
    }

    _startInterruptionWatchdog(provider);
  }

  void _startInterruptionWatchdog(SleepAnalysisProvider provider) {
    _interruptionWatchdogTimer?.cancel();
    // Poll every 3 seconds to check if mic is released and recording has resumed or can resume
    _interruptionWatchdogTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (!mounted || !provider.isRecording) {
        timer.cancel();
        return;
      }

      try {
        final isPaused = await _recorder.isPaused();
        final isRec = await _recorder.isRecording();

        if (isRec && !isPaused) {
          RecordingLogger().info('[Watchdog] Recorder has resumed active recording.');
          _onRecordingResumed(provider);
          return;
        }

        if (isPaused) {
          RecordingLogger().info('[Watchdog] Recorder is paused; attempting to resume...');
          await _recorder.resume();
          final stillPaused = await _recorder.isPaused();
          if (!stillPaused) {
            RecordingLogger().info('[Watchdog] Recorder resumed successfully.');
            _onRecordingResumed(provider);
            return;
          }
        } else if (!isRec) {
          RecordingLogger().info('[Watchdog] Recorder stopped; attempting to start new segment...');
          await _startNewRecordingSegment(provider);
        }
      } catch (e) {
        RecordingLogger().warning('[Watchdog] Auto-resume check failed (mic likely still busy): $e');
      }
    });
  }

  void _onRecordingResumed(SleepAnalysisProvider provider) {
    if (!_isInterrupted) return;
    _interruptionWatchdogTimer?.cancel();
    _restartSegmentTimer?.cancel();

    if (_interruptionStartTime != null) {
      final pausedDuration = DateTime.now().difference(_interruptionStartTime!);
      _totalInterruptedDuration += pausedDuration;
      RecordingLogger().info(
        'Recording resumed after interruption. Interrupted duration: ${pausedDuration.inSeconds}s, '
        'Total interrupted so far: ${_totalInterruptedDuration.inSeconds}s',
      );
    }
    _isInterrupted = false;
    _interruptionStartTime = null;
    provider.setInterrupted(false);
    _hideInterruptionBanner();

    if (!kIsWeb) {
      FlutterForegroundTask.updateService(
        notificationTitle: 'Recording Sleep...',
        notificationText: 'Sleep Astra is listening for snoring.',
      );
    }

    if (mounted) {
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('▶️ Sleep recording resumed.'),
          duration: Duration(seconds: 3),
          backgroundColor: Color(0xFF10B981), // emerald-500
        ),
      );
    }
  }

  /// Starts a new recording segment after the OS stopped the recorder
  /// (Android interruption). The new segment is added to [_recordingSegmentPaths]
  /// so its audio time is counted during analysis.
  Future<void> _startNewRecordingSegment(SleepAnalysisProvider provider) async {
    if (kIsWeb || !mounted || _isStartingSegment || !provider.isRecording) return;
    _isStartingSegment = true;
    _restartSegmentTimer?.cancel();

    try {
      // Check if mic is back (permission still granted)
      final hasPerm = await _recorder.hasPermission();
      if (!hasPerm) {
        RecordingLogger().warning('Mic permission not available yet');
        return;
      }

      final dir = await getApplicationDocumentsDirectory();
      final segPath = '${dir.path}/sleep_${DateTime.now().millisecondsSinceEpoch}.pcm';

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
          autoGain: false,
          echoCancel: false,
          noiseSuppress: false,
          audioInterruption: AudioInterruptionMode.pauseResume,
          androidConfig: AndroidRecordConfig(
            manageBluetooth: true,
            audioSource: AndroidAudioSource.mic,
          ),
          iosConfig: IosRecordConfig(
            allowHapticsAndSystemSoundsDuringRecording: true,
          ),
        ),
        path: segPath,
      );

      _recordingSegmentPaths.add(segPath);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('active_recording_path', segPath);
      await prefs.setStringList('active_recording_segments', _recordingSegmentPaths);

      RecordingLogger().info(
        'New recording segment ${_recordingSegmentPaths.length} started after interruption: $segPath',
      );

      _onRecordingResumed(provider);

      // Re-subscribe to record state for the new recorder instance
      _listenToAmplitude(provider);
      _listenToRecordState(provider);
    } catch (e) {
      RecordingLogger().warning('Segment restart failed (mic likely in use by call): $e');
    } finally {
      _isStartingSegment = false;
    }
  }

  /// Shows a persistent amber banner at the top of the screen informing the
  /// user that their recording was interrupted (e.g. by a phone call).
  void _showInterruptionBanner() {
    if (!mounted) return;
    // Remove any stale banner first
    _interruptionBannerEntry?.remove();
    _interruptionBannerEntry = OverlayEntry(
      builder: (_) => Positioned(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B), // amber-500
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [
                BoxShadow(color: Colors.black38, blurRadius: 12, offset: Offset(0, 4)),
              ],
            ),
            child: const Row(
              children: [
                Text('📵', style: TextStyle(fontSize: 22)),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Recording Paused',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Microphone in use by a call or another app. Sleep Astra will automatically resume recording as soon as the call ends.',
                        style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_interruptionBannerEntry!);
  }

  /// Removes the interruption banner from the overlay.
  void _hideInterruptionBanner() {
    _interruptionBannerEntry?.remove();
    _interruptionBannerEntry = null;
  }

  Future<void> _stopAndAnalyse(SleepAnalysisProvider provider) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    
    try {
      HapticFeedback.heavyImpact();
      NotificationService().cancelBackupAlarm();
      _recordingTimer?.cancel();
      _interruptionWatchdogTimer?.cancel();
      _restartSegmentTimer?.cancel();
      _rippleController.stop();
      _rippleController.reset();
    await _soundsPlayer.stop();
    await _alarmPlayer.stop();
    _isAlarmRinging = false;

    if (!mounted) return;
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
      await prefs.remove('active_recording_segments');

      await FlutterForegroundTask.stopService();
      RecordingLogger().info('Foreground service stopped');
    }

    try {
      await WakelockPlus.disable();
      RecordingLogger().info('WakelockPlus disabled');
    } catch (_) {}

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

    // ── Hide any active interruption banner ──────────────────────────────
    _hideInterruptionBanner();

    // ── Finalize any in-progress interruption ────────────────────────────
    // If the call was still active when the user tapped stop, close out the
    // accumulated interrupted duration.
    if (_isInterrupted && _interruptionStartTime != null) {
      _totalInterruptedDuration += DateTime.now().difference(_interruptionStartTime!);
      _isInterrupted = false;
      _interruptionStartTime = null;
    }

    // ── Compute effective (real audio) recording duration ────────────────
    // Wall-clock duration accurately reflects the real time the user was recording.
    final DateTime now = DateTime.now();
    final Duration wallClockDuration = _recordingStartTime != null
        ? now.difference(_recordingStartTime!)
        : provider.recordingDuration;

    // ── Multi-segment duration calculation & byte-rate detection ─────────
    // If the recording had interruptions that required new segments to be
    // started, collect all unique existing segments.
    final allSegments = {
      ..._recordingSegmentPaths.where((p) => p != stoppedPath && File(p).existsSync()),
      if (stoppedPath != null && File(stoppedPath).existsSync()) stoppedPath,
    }.toList();

    if (stoppedPath == null && allSegments.isNotEmpty) {
      stoppedPath = allSegments.last;
    }

    int totalPcmBytes = 0;
    int detectedByteRate = 32000; // default 16kHz 16-bit mono

    if (stoppedPath != null && !kIsWeb) {
      for (final segPath in allSegments) {
        try {
          final f = File(segPath);
          if (f.existsSync()) {
            final fSize = f.lengthSync();
            if (fSize >= 44) {
              final raf = f.openSync(mode: FileMode.read);
              final headerBuf = Uint8List(44);
              raf.readIntoSync(headerBuf);
              raf.closeSync();
              int dataOffset = 0;
              if (headerBuf[0] == 0x52 && headerBuf[1] == 0x49 && // 'RI'
                  headerBuf[2] == 0x46 && headerBuf[3] == 0x46) { // 'FF'
                final bd = ByteData.sublistView(headerBuf);
                final br = bd.getUint32(28, Endian.little);
                if (br > 0) detectedByteRate = br;
                dataOffset = 44;
              }
              totalPcmBytes += (fSize - dataOffset).clamp(0, fSize);
            } else if (fSize > 0) {
              totalPcmBytes += fSize;
            }
          }
        } catch (_) {}
      }
    }

    final Duration audioDuration = Duration(
      seconds: (totalPcmBytes / detectedByteRate).floor(),
    );

    // Compute effective duration:
    // Subtract true dead time during interruptions, but never drop below zero.
    final netWallClock = wallClockDuration - _totalInterruptedDuration;
    final baseDuration = netWallClock > Duration.zero ? netWallClock : wallClockDuration;
    // Use the maximum of audio duration and wall-clock duration.
    // This prevents buffer-flush delays, timer ticks, or minor sampling drift
    // from causing a 30-minute recording to register as 29m55s and fail.
    final Duration effectiveDuration = audioDuration > Duration.zero
        ? (audioDuration > baseDuration ? audioDuration : baseDuration)
        : baseDuration;

    provider.updateRecordingDuration(effectiveDuration);
    RecordingLogger().info(
      'Stop: wall-clock=${wallClockDuration.inSeconds}s, '
      'interrupted=${_totalInterruptedDuration.inSeconds}s, '
      'audio=${audioDuration.inSeconds}s, '
      'effective=${effectiveDuration.inSeconds}s across ${allSegments.length} segment(s)',
    );

    if (stoppedPath == null) {
      RecordingLogger().error('Recording stopped but no file was saved.');
      _showError('Recording stopped but no file was saved.');
      return;
    }

    // Merge multiple segments into a single cohesive WAV file if interrupted
    String finalRecordingPath = stoppedPath;
    if (allSegments.length > 1 && !kIsWeb) {
      final mergedPath = await _mergeSegmentsIfNeeded(allSegments);
      if (mergedPath.isNotEmpty) {
        finalRecordingPath = mergedPath;
      }
    }

    // ── 1. Accidental Tap Guard (< 30 seconds) ───────────────────────────
    // If the recording was under 30 seconds, it was an accidental tap.
    if (effectiveDuration.inSeconds < 30 && wallClockDuration.inSeconds < 30) {
      RecordingLogger().warning('Recording too short (<30s), discarding: $finalRecordingPath');
      if (!context.mounted) {
        if (!kIsWeb) await _cleanupSegments([...allSegments, finalRecordingPath]);
        return;
      }
      _showAccidentalTapWarning();
      if (!kIsWeb) {
        await _cleanupSegments([...allSegments, finalRecordingPath]);
      }
      return;
    }

    // ── 2. Full Session Check (>= 30 minutes, with 1-min tolerance) ──────
    // A recording of >= 30 minutes (or >= 29 min / 1740s to prevent truncation bugs)
    // is a full sleep session and proceeds straight to analysis.
    // If it's shorter (e.g. 10–25 min nap), we inform the user and give them
    // the option to analyze anyway or discard — NEVER delete without permission!
    final bool isFullSession = wallClockDuration >= const Duration(minutes: 30) ||
        effectiveDuration >= const Duration(minutes: 30) ||
        wallClockDuration.inSeconds >= 1740 ||
        effectiveDuration.inSeconds >= 1740;

    if (!isFullSession) {
      if (!mounted) return;
      final int recordedMins = max(1, (effectiveDuration.inSeconds / 60).round());
      final bool? shouldAnalyze = await _showShortRecordingDialog(recordedMins);
      if (shouldAnalyze != true) {
        RecordingLogger().info('User discarded short recording ($recordedMins min).');
        if (!kIsWeb) {
          await _cleanupSegments([...allSegments, finalRecordingPath]);
        }
        return;
      }
      RecordingLogger().info('User opted to analyze short recording anyway ($recordedMins min).');
    }

    final name = finalRecordingPath.split('/').last.split('\\').last;

    if (kIsWeb) {
      _showError('Web platform does not support real audio analysis. Please use the Android app.');
      return;
    } else {
      provider.setRecordedFile(finalRecordingPath, name);
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
          await _cleanupSegments([...allSegments, finalRecordingPath]);
        }
        _promptedReportFiles.add(report.fileName);
        if (mounted) {
          await _showAnalysisCompletePrompt(context, report);
        }
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

  String _getAnalysisStepMessage(int elapsed) {
    if (elapsed < 6) return 'Extracting audio features & sleep stages…';
    if (elapsed < 14) return 'Filtering ambient noise & detecting snore bursts…';
    if (elapsed < 22) return 'Evaluating breathing continuity & apnea patterns…';
    if (elapsed < 35) return 'Synthesizing sleep architecture & calculating quality score…';
    return 'Finalizing your sleep report & health insights…';
  }

  Future<void> _showAnalysisCompletePrompt(BuildContext context, SleepReport report) async {
    if (!mounted) return;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final durationHours = report.totalDuration.inHours;
    final durationMins = report.totalDuration.inMinutes % 60;
    final durationText = '${durationHours}h ${durationMins}m';
    final snoreMins = report.snoringDuration.inMinutes;

    Color scoreColor;
    if (report.qualityScore >= 80) {
      scoreColor = AppTheme.accentTeal;
    } else if (report.qualityScore >= 65) {
      scoreColor = const Color(0xFF3B82F6);
    } else if (report.qualityScore >= 50) {
      scoreColor = AppTheme.primaryGold;
    } else {
      scoreColor = AppTheme.error;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          decoration: BoxDecoration(
            color: isLight ? AppTheme.surfaceLight : const Color(0xFF151728),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 25)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle pill
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isLight ? AppTheme.cardBorderLight : AppTheme.cardBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Success badge & Title
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.accentTeal.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_circle_rounded, color: AppTheme.accentTeal, size: 26),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Analysis Complete!',
                    style: TextStyle(
                      color: isLight ? AppTheme.textPrimaryLight : Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Your recorded sleep session has been processed successfully.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isLight ? AppTheme.textSecondaryLight : AppTheme.textSecondary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              // Score & Quality Card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                decoration: BoxDecoration(
                  color: isLight ? Colors.white : AppTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isLight ? AppTheme.cardBorderLight : AppTheme.cardBorder,
                  ),
                ),
                child: Row(
                  children: [
                    // Score Circle
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: scoreColor.withValues(alpha: 0.15),
                        border: Border.all(color: scoreColor, width: 2.5),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${report.qualityScore.toInt()}',
                        style: TextStyle(
                          color: scoreColor,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '${report.qualityLabel} Sleep',
                                style: TextStyle(
                                  color: isLight ? AppTheme.textPrimaryLight : Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(report.qualityEmoji, style: const TextStyle(fontSize: 18)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Score: ${report.qualityScore.toInt()}/100 • ${report.recordedAt.day}/${report.recordedAt.month}/${report.recordedAt.year}',
                            style: TextStyle(
                              color: isLight ? AppTheme.textSecondaryLight : AppTheme.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // 3-Metric stats strip
              Row(
                children: [
                  _buildPromptStatTile(
                    label: 'Sleep Duration',
                    value: durationText,
                    icon: Icons.access_time_rounded,
                    isLight: isLight,
                  ),
                  const SizedBox(width: 10),
                  _buildPromptStatTile(
                    label: 'Snoring',
                    value: snoreMins > 0 ? '${snoreMins}m' : 'None',
                    icon: Icons.graphic_eq_rounded,
                    isLight: isLight,
                  ),
                  const SizedBox(width: 10),
                  _buildPromptStatTile(
                    label: 'Apnea Risk',
                    value: report.apneaRiskLevel,
                    icon: Icons.favorite_border_rounded,
                    isLight: isLight,
                  ),
                ],
              ),
              const SizedBox(height: 28),
              // Buttons
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pushNamed(context, AppRouter.sleepReport, arguments: report);
                  },
                  icon: const Icon(Icons.insights_rounded, size: 20),
                  label: const Text(
                    'View Full Report',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryIndigo,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    'Done',
                    style: TextStyle(
                      color: isLight ? AppTheme.textSecondaryLight : AppTheme.textSecondary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPromptStatTile({
    required String label,
    required String value,
    required IconData icon,
    required bool isLight,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isLight ? const Color(0xFFF3F4F6) : AppTheme.surfaceElevated,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isLight ? AppTheme.cardBorderLight : AppTheme.cardBorder,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: AppTheme.accentTeal),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                color: isLight ? AppTheme.textPrimaryLight : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: isLight ? AppTheme.textSecondaryLight : AppTheme.textSecondary,
                fontSize: 11,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
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

  Future<void> _cleanupSegments(List<String> paths, {String? keepPath}) async {
    for (final p in paths.toSet()) {
      if (p != keepPath && p.isNotEmpty) {
        try {
          await PlatformFileReader.deleteFile(p);
        } catch (_) {}
      }
    }
  }

  /// Merges multiple PCM/WAV segments into a single cohesive WAV file.
  Future<String> _mergeSegmentsIfNeeded(List<String> segmentPaths) async {
    final validSegments = segmentPaths.where((p) => File(p).existsSync() && File(p).lengthSync() > 0).toList();
    if (validSegments.isEmpty) return '';
    if (validSegments.length == 1) return validSegments.first;

    try {
      RecordingLogger().info('Merging ${validSegments.length} audio segments into a single file...');
      final dir = await getApplicationDocumentsDirectory();
      final mergedPath = '${dir.path}/sleep_merged_${DateTime.now().millisecondsSinceEpoch}.wav';
      final mergedFile = File(mergedPath);
      final sink = mergedFile.openSync(mode: FileMode.write);

      // Reserve 44 bytes for WAV header
      sink.writeFromSync(Uint8List(44));

      int totalPayloadBytes = 0;
      int sampleRate = 16000;
      int numChannels = 1;
      int bitsPerSample = 16;

      for (int i = 0; i < validSegments.length; i++) {
        final segPath = validSegments[i];
        final file = File(segPath);
        final raf = file.openSync(mode: FileMode.read);
        final fileLen = raf.lengthSync();

        int dataOffset = 0;
        if (fileLen >= 44) {
          final headerBuf = Uint8List(44);
          raf.readIntoSync(headerBuf);
          if (headerBuf[0] == 0x52 && headerBuf[1] == 0x49 && // 'RI'
              headerBuf[2] == 0x46 && headerBuf[3] == 0x46) { // 'FF'
            final bd = ByteData.sublistView(headerBuf);
            if (i == 0) {
              numChannels = bd.getUint16(22, Endian.little);
              sampleRate = bd.getUint32(24, Endian.little);
              bitsPerSample = bd.getUint16(34, Endian.little);
            }
            dataOffset = 44;
          }
        }

        raf.setPositionSync(dataOffset);
        final payloadSize = fileLen - dataOffset;
        if (payloadSize > 0) {
          const chunkSize = 64 * 1024;
          final buf = Uint8List(chunkSize);
          int remaining = payloadSize;
          while (remaining > 0) {
            final toRead = min(chunkSize, remaining);
            final read = raf.readIntoSync(buf, 0, toRead);
            if (read <= 0) break;
            sink.writeFromSync(buf, 0, read);
            remaining -= read;
            totalPayloadBytes += read;
          }
        }
        raf.closeSync();
      }

      // Write true 44-byte WAV header at offset 0
      final byteRate = sampleRate * numChannels * (bitsPerSample ~/ 8);
      final blockAlign = numChannels * (bitsPerSample ~/ 8);
      final headerBytes = Uint8List(44);
      final bd = ByteData.sublistView(headerBytes);

      headerBytes[0] = 0x52; // 'R'
      headerBytes[1] = 0x49; // 'I'
      headerBytes[2] = 0x46; // 'F'
      headerBytes[3] = 0x46; // 'F'
      bd.setUint32(4, 36 + totalPayloadBytes, Endian.little);
      headerBytes[8] = 0x57; // 'W'
      headerBytes[9] = 0x41; // 'A'
      headerBytes[10] = 0x56; // 'V'
      headerBytes[11] = 0x45; // 'E'

      headerBytes[12] = 0x66; // 'f'
      headerBytes[13] = 0x6D; // 'm'
      headerBytes[14] = 0x74; // 't'
      headerBytes[15] = 0x20; // ' '
      bd.setUint32(16, 16, Endian.little);
      bd.setUint16(20, 1, Endian.little);
      bd.setUint16(22, numChannels, Endian.little);
      bd.setUint32(24, sampleRate, Endian.little);
      bd.setUint32(28, byteRate, Endian.little);
      bd.setUint16(32, blockAlign, Endian.little);
      bd.setUint16(34, bitsPerSample, Endian.little);

      headerBytes[36] = 0x64; // 'd'
      headerBytes[37] = 0x61; // 'a'
      headerBytes[38] = 0x74; // 't'
      headerBytes[39] = 0x61; // 'a'
      bd.setUint32(40, totalPayloadBytes, Endian.little);

      sink.setPositionSync(0);
      sink.writeFromSync(headerBytes);
      sink.closeSync();

      RecordingLogger().info('Successfully merged ${validSegments.length} segments into $mergedPath (total: $totalPayloadBytes bytes)');
      return mergedPath;
    } catch (e) {
      RecordingLogger().error('Failed to merge segments: $e');
      return validSegments.last;
    }
  }

  void _showAccidentalTapWarning() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final bottomPad = MediaQuery.of(context).padding.bottom;
        final isLight = Theme.of(context).brightness == Brightness.light;
        return Container(
          padding: EdgeInsets.fromLTRB(32, 32, 32, 24 + bottomPad),
          decoration: BoxDecoration(
            color: isLight ? AppTheme.surfaceLight : AppTheme.surfaceElevated,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 20)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('⏱️', style: TextStyle(fontSize: 56)),
              const SizedBox(height: 16),
              Text(
                'Recording Too Short',
                style: Theme.of(context).textTheme.displaySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Recording was under 30 seconds. Sleep analysis requires sufficient audio to detect sleep cycles and breathing patterns. Please tap Record when you are ready to sleep.',
                style: TextStyle(
                  color: isLight ? AppTheme.textSecondaryLight : AppTheme.textSecondary,
                  fontSize: 15,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryIndigo,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Got it', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<bool?> _showShortRecordingDialog(int recordedMinutes) {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      builder: (context) {
        final bottomPad = MediaQuery.of(context).padding.bottom;
        final isLight = Theme.of(context).brightness == Brightness.light;
        final textColor = isLight ? AppTheme.textPrimaryLight : AppTheme.textPrimary;
        final textSec = isLight ? AppTheme.textSecondaryLight : AppTheme.textSecondary;
        return Container(
          padding: EdgeInsets.fromLTRB(28, 28, 28, 20 + bottomPad),
          decoration: BoxDecoration(
            color: isLight ? AppTheme.surfaceLight : AppTheme.surfaceElevated,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 20)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🥱', style: TextStyle(fontSize: 56)),
              const SizedBox(height: 14),
              Text(
                'Short Sleep Session (~$recordedMinutes min)',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'Sleep cycles typically take 90 minutes, and sessions over 30 minutes give the most accurate snoring, apnea, and sleep stage insights.\n\nWould you like to analyze this recording anyway?',
                style: TextStyle(
                  color: textSec,
                  fontSize: 14,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: textSec.withValues(alpha: 0.4)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text('Discard', style: TextStyle(color: textSec, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryIndigo,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Analyze Anyway', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
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
          final savedSegments = prefs.getStringList('active_recording_segments');
          if (savedSegments != null && savedSegments.isNotEmpty) {
            _recordingSegmentPaths.clear();
            _recordingSegmentPaths.addAll(savedSegments.where((p) => File(p).existsSync()));
          }
          _recordingTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
            if (_recordingStartTime != null) {
              provider.updateRecordingDuration(
                DateTime.now().difference(_recordingStartTime!),
              );
            }
          });
          _listenToAmplitude(provider);
          _listenToRecordState(provider);
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

      int? startMs = prefs.getInt('active_recording_start_ms');
      int? endMs;

      if (startMs == null) {
        // active_recording_start_ms was never persisted (e.g. first-ever crash before prefs write).
        // Derive the recording start from file size ÷ bytes-per-second, subtracted from the
        // file's last-modified time (= closest proxy for when the recording STOPPED).
        // This is far better than using stat.changed as the START time (the old bug).
        try {
          final stat = file.statSync();
          // Use the last-modified time as the approximate END of recording
          endMs = stat.modified.millisecondsSinceEpoch;
          // Compute file-based audio duration (will be refined by the file-size safety net below)
          final isPcmFallback = orphanPath.toLowerCase().endsWith('.pcm');
          final fallbackFileSize = file.lengthSync();
          final fallbackHeaderBytes = isPcmFallback ? 0 : 44;
          const int fallbackBps = 32000;
          final fallbackPcmBytes = max(0, fallbackFileSize - fallbackHeaderBytes);
          final fallbackDurationSec = fallbackPcmBytes > 0 ? fallbackPcmBytes ~/ fallbackBps : 3600;
          // start = end - duration (best-effort reconstruction)
          startMs = endMs - (fallbackDurationSec * 1000);
          RecordingLogger().warning(
            'active_recording_start_ms missing. Reconstructed start from file size: '
            'end=${DateTime.fromMillisecondsSinceEpoch(endMs)}, '
            'durationSec=$fallbackDurationSec, '
            'start=${DateTime.fromMillisecondsSinceEpoch(startMs)}',
          );
        } catch (_) {
          // Absolute last resort: 1 hour ago
          startMs = DateTime.now().subtract(const Duration(hours: 1)).millisecondsSinceEpoch;
          RecordingLogger().warning('Could not stat orphan file; defaulting start to 1h ago.');
        }
      } else {
        // We have a reliable start time. The file stopped growing when the app was killed,
        // so use the file's last-modified time as the end for a tighter elapsed estimate.
        try {
          final stat = file.statSync();
          endMs = stat.modified.millisecondsSinceEpoch;
        } catch (_) {}
      }

      final startTime = DateTime.fromMillisecondsSinceEpoch(startMs);

      Duration elapsed;
      if (endMs != null && endMs > startMs) {
        final endTime = DateTime.fromMillisecondsSinceEpoch(endMs);
        elapsed = endTime.difference(startTime);
        RecordingLogger().info('Orphan file recovered. Using file last-modified time to bound duration. Duration: $elapsed');
      } else {
        elapsed = DateTime.now().difference(startTime);
      }


      // ── File-size safety net for orphans ─────────────────────────────────
      // If the app was killed at 2 AM, but the user opens it at 7 AM, `elapsed`
      // will be 5 hours longer than the actual audio file. We MUST use the file size
      // to determine the real duration so the analyzer doesn't corrupt the sample rate.
      //
      // IMPORTANT: Raw PCM files (.pcm) have NO header — they grow continuously while
      // recording, so they are never "truncated" relative to wall-clock time. For PCM
      // files, always trust elapsed as the actual duration.
      Duration actualFileDuration = elapsed;
      try {
        final isPcm = orphanPath.toLowerCase().endsWith('.pcm');

        if (isPcm) {
          // PCM: no header, file size IS the audio data. Compute from file size
          // using the known recording format: 16-bit (2 bytes) mono 16kHz = 32000 B/s.
          final fileSize = file.lengthSync();
          const int bytesPerSecond = 32000;
          final computedDuration = Duration(seconds: (fileSize / bytesPerSecond).floor());
          if (computedDuration < elapsed - const Duration(seconds: 30)) {
            actualFileDuration = computedDuration;
            RecordingLogger().warning(
              'PCM orphan file-size check: file contains ${actualFileDuration.inSeconds}s of audio '
              '(${bytesPerSecond}B/s), but wall-clock elapsed is ${elapsed.inSeconds}s. Using file-based duration.',
            );
          } else {
            actualFileDuration = elapsed;
            RecordingLogger().info('PCM orphan: using wall-clock elapsed (${elapsed.inSeconds}s).');
          }
        } else {
          // WAV: read the actual byte-rate from the header (bytes 28-31, little-endian).
          // This avoids the previously hardcoded 32000 B/s which was wrong for any
          // recording format other than exactly 16kHz / 16-bit / mono.
          final fileSize = file.lengthSync();
          int bytesPerSecond = 32000; // safe fallback
          try {
            final headerRaf = file.openSync(mode: FileMode.read);
            final headerBuf = Uint8List(44);
            headerRaf.readIntoSync(headerBuf);
            headerRaf.closeSync();
            // WAV byte rate is at offset 28 (4 bytes, little-endian)
            if (headerBuf[0] == 0x52 && headerBuf[1] == 0x49 && // 'RI'
                headerBuf[2] == 0x46 && headerBuf[3] == 0x46) { // 'FF'
              final byteData = ByteData.sublistView(headerBuf);
              final headerByteRate = byteData.getUint32(28, Endian.little);
              if (headerByteRate > 0) {
                bytesPerSecond = headerByteRate;
                RecordingLogger().info('WAV orphan: read byte rate from header = $bytesPerSecond B/s');
              }
            }
          } catch (_) {}

          const int wavHeaderBytes = 44;
          final pcmBytes = fileSize - wavHeaderBytes;
          if (pcmBytes > 0) {
            final computedDuration = Duration(seconds: (pcmBytes / bytesPerSecond).floor());
            // Trust the file size if it's significantly shorter than the wall clock
            if (computedDuration < elapsed - const Duration(seconds: 30)) {
              actualFileDuration = computedDuration;
              RecordingLogger().warning(
                'Orphan file-size check: file contains ${actualFileDuration.inSeconds}s of audio '
                '(${bytesPerSecond}B/s), but wall-clock elapsed is ${elapsed.inSeconds}s. Using file-based duration.',
              );
            }
          }
        }
      } catch (e) {
        RecordingLogger().warning('Orphan file-size check failed (non-fatal): $e');
      }

      // Only offer recovery for recordings ≥ 1 minute of ACTUAL audio
      if (actualFileDuration.inSeconds < 60) {
        RecordingLogger().info('Orphaned file too short (${actualFileDuration.inSeconds}s), discarding silently.');
        await prefs.remove('active_recording_path');
        await prefs.remove('active_recording_start_ms');
        await file.delete();
        return;
      }

      RecordingLogger().warning(
        'Orphaned recording detected: $orphanPath (actual duration: ~${actualFileDuration.inMinutes}m, wall-clock: ${elapsed.inHours}h). App was likely killed overnight.',
      );

      if (!mounted) {
        _isCheckingOrphan = false;
        return;
      }
      // Keep _isCheckingOrphan = true for the ENTIRE duration of the bottom sheet
      // so that widget rebuilds don't trigger a second orphan popup.
      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.transparent,
        isDismissible: false,
        builder: (ctx) => Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: (Theme.of(context).brightness == Brightness.light ? AppTheme.surfaceLight : AppTheme.surface),
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
                'It looks like recording was interrupted last night (~${actualFileDuration.inHours}h ${actualFileDuration.inMinutes % 60}m captured). '
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
                        // Reset stale provider state so the next fresh recording
                        // doesn't accidentally inherit this orphan's duration/startTime
                        if (mounted) {
                          context.read<SleepAnalysisProvider>().setRecordingActive(false);
                        }
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
                        provider.updateRecordingDuration(actualFileDuration);
                        RecordingLogger().info('Analyzing orphaned recording: $orphanPath (start time: $startTime, duration: $actualFileDuration)');
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
                          if (!mounted) return;
                          _promptedReportFiles.add(report.fileName);
                          await _showAnalysisCompletePrompt(context, report);
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
          // Cancel any stale stuck-timer if user is back to recording
          _analysisStuckTimer?.cancel();
          return _buildRecordingView(provider);
        }
        if (provider.state == AnalysisState.analysing) {
          return _buildAnalysingView();
        }
        if (provider.state == AnalysisState.done &&
            provider.report != null &&
            !_promptedReportFiles.contains(provider.report!.fileName)) {
          final doneReport = provider.report!;
          _promptedReportFiles.add(doneReport.fileName);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _showAnalysisCompletePrompt(context, doneReport);
            }
          });
        }
        // Analysis done/error/idle — stop the timer
        _analysisStuckTimer?.cancel();
        return _buildIdleView(provider);
      },
    );
  }

  Widget _buildAnalysingView() {
    final isLight = Theme.of(context).brightness == Brightness.light;
    // Start the stuck-state timer whenever this view is shown
    _startAnalysisStuckTimer();
    return Scaffold(
      backgroundColor: isLight ? AppTheme.backgroundLight : AppTheme.background,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pulsing brain icon
              RepaintBoundary(
                child: AnimatedBuilder(
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
              const SizedBox(height: 32),
              // Show elapsed time and dynamic progress feedback
              ValueListenableBuilder<int>(
                valueListenable: _analysisElapsedSeconds,
                builder: (_, elapsed, __) {
                  final minutes = elapsed ~/ 60;
                  final seconds = elapsed % 60;
                  final timeStr = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
                  final isStuck = elapsed >= 180; // 3 minutes
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: (isLight ? AppTheme.primaryIndigo : AppTheme.accentTeal).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _getAnalysisStepMessage(elapsed),
                          style: TextStyle(
                            color: isLight ? AppTheme.primaryIndigo : AppTheme.accentTeal,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Processing... $timeStr',
                        style: TextStyle(
                          color: isStuck ? Colors.amber : (isLight ? AppTheme.textSecondaryLight : AppTheme.textSecondary),
                          fontSize: 13,
                        ),
                      ),
                      if (elapsed > 30) ...[
                        const SizedBox(height: 6),
                        Text(
                          elapsed < 180
                            ? 'Long recordings take more time to analyze.'
                            : 'This is taking unusually long.',
                          style: TextStyle(
                            color: isLight ? AppTheme.textSecondaryLight : AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                      if (elapsed >= 60 && !isStuck) ...[
                        const SizedBox(height: 18),
                        TextButton.icon(
                          onPressed: () {
                            if (Navigator.canPop(context)) {
                              Navigator.pop(context);
                            }
                          },
                          icon: const Icon(Icons.arrow_back_rounded, size: 16),
                          label: const Text('Continue in App (We\'ll notify when done)'),
                          style: TextButton.styleFrom(
                            foregroundColor: isLight ? AppTheme.primaryIndigo : AppTheme.accentTeal,
                            textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                      if (isStuck) ...[
                        const SizedBox(height: 24),
                        OutlinedButton.icon(
                          onPressed: () {
                            _analysisStuckTimer?.cancel();
                            _analysisElapsedSeconds.value = 0;
                            final provider = context.read<SleepAnalysisProvider>();
                            // Force-reset state so user can retry or go to history
                            provider.reset();
                          },
                          icon: const Icon(Icons.cancel_outlined, size: 18),
                          label: const Text('Cancel & Go Back'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.amber,
                            side: const BorderSide(color: Colors.amber),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Your report may still save in the background.',
                          style: TextStyle(
                            color: isLight ? AppTheme.textSecondaryLight : AppTheme.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _startAnalysisStuckTimer() {
    // Only start once per analysis run
    if (_analysisStuckTimer != null && _analysisStuckTimer!.isActive) return;
    _analysisElapsedSeconds.value = 0;
    _analysisStuckTimer?.cancel();
    _analysisStuckTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        _analysisStuckTimer?.cancel();
        return;
      }
      _analysisElapsedSeconds.value += 1;
    });
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
                  const SizedBox(width: 48), // Hidden alarm icon
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
        return RepaintBoundary(
          child: AnimatedBuilder(
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
          ),
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
        Icons.wb_sunny_rounded,
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
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final isOn = _alarmTime != null;
          final isLight = Theme.of(context).brightness == Brightness.light;
          final cardBg = isLight ? AppTheme.surfaceLight : AppTheme.surfaceElevated;
          final textPrimary = isLight ? AppTheme.textPrimaryLight : Colors.white;
          final textSec = isLight ? AppTheme.textSecondaryLight : Colors.white70;
          final borderCol = isLight ? AppTheme.cardBorderLight : AppTheme.cardBorder;

          // Temporary state for the UI mockup of days
          final List<String> days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

          return Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                )
              ]
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: borderCol, borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 24),
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.wb_twilight_rounded, color: AppTheme.primaryGold, size: 28),
                    const SizedBox(width: 10),
                    Text('Smart Wake', style: TextStyle(fontSize: 22, color: textPrimary, fontWeight: FontWeight.w800)),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Wakes you up gently in your lightest sleep phase.', style: TextStyle(color: textSec, fontSize: 13), textAlign: TextAlign.center),
                const SizedBox(height: 32),
                
                // Clock Display
                GestureDetector(
                  onTap: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: _alarmTime ?? TimeOfDay.now(),
                      builder: (context, child) => Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: ColorScheme.dark(
                            primary: AppTheme.accentTeal,
                            surface: cardBg,
                          ),
                        ),
                        child: child!,
                      ),
                    );
                    if (time != null && mounted) {
                      setState(() => _alarmTime = time);
                      _syncBackupAlarm();
                      setSheetState(() {});
                      if (_alarmTimer == null) {
                         _alarmTimer = Timer.periodic(const Duration(seconds: 1), (_) => _checkAlarm());
                      }
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isOn 
                            ? [AppTheme.primaryIndigo.withValues(alpha: 0.15), AppTheme.accentTeal.withValues(alpha: 0.15)]
                            : [borderCol.withValues(alpha: 0.5), borderCol.withValues(alpha: 0.2)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: isOn ? AppTheme.accentTeal.withValues(alpha: 0.3) : borderCol),
                    ),
                    alignment: Alignment.center,
                    child: Column(
                      children: [
                        Text(
                          _alarmTime?.format(context) ?? '00:00',
                          style: TextStyle(
                            fontSize: 56, 
                            color: isOn ? textPrimary : textSec, 
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1,
                          ),
                        ),
                        if (!isOn)
                          Text('Tap to set time', style: TextStyle(color: textSec, fontSize: 14)),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Days of week UI mockup
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(7, (index) {
                    final isWeekend = index >= 5;
                    final isActive = isOn && !isWeekend; // Just a mock visual
                    return Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isActive ? AppTheme.primaryIndigo : Colors.transparent,
                        border: Border.all(color: isActive ? AppTheme.primaryIndigo : borderCol),
                      ),
                      child: Center(
                        child: Text(
                          days[index],
                          style: TextStyle(
                            color: isActive ? Colors.white : textSec,
                            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    );
                  }),
                ),

                const SizedBox(height: 32),
                
                // Toggle Button
                GestureDetector(
                  onTap: () {
                    if (isOn) {
                      setState(() => _alarmTime = null);
                      _syncBackupAlarm();
                      setSheetState(() {});
                      _alarmTimer?.cancel();
                      _alarmTimer = null;
                    } else {
                      // If turning on, prompt for time if null, else just turn on
                      if (_alarmTime == null) {
                         // trigger tap on clock
                      }
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    decoration: BoxDecoration(
                      gradient: isOn 
                          ? const LinearGradient(colors: [AppTheme.error, Color(0xFFEF4444)])
                          : const LinearGradient(colors: [AppTheme.primaryIndigo, Color(0xFF6366F1)]),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: (isOn ? AppTheme.error : AppTheme.primaryIndigo).withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: Center(
                      child: Text(
                        isOn ? 'Turn Off Alarm' : 'Set Alarm',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ),
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
            color: (Theme.of(context).brightness == Brightness.light ? AppTheme.surfaceLight : AppTheme.surface),
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
              ...kSleepTracks.map((snd) {
                final isPlaying = _activeSoundName == snd.name;
                return ListTile(
                  title: Text(snd.name, style: TextStyle(color: (Theme.of(context).brightness == Brightness.light ? AppTheme.textPrimaryLight : AppTheme.textPrimary))),
                  trailing: isPlaying ? const Icon(Icons.stop_circle, color: AppTheme.accentTeal) : Icon(Icons.play_circle_outline, color: (Theme.of(context).brightness == Brightness.light ? AppTheme.textSecondaryLight : AppTheme.textSecondary)),
                  onTap: () async {
                    if (isPlaying) {
                      await _soundsPlayer.stop();
                      setState(() => _activeSoundName = null);
                      setSheetState(() => _activeSoundName = null);
                    } else {
                      setState(() => _activeSoundName = snd.name);
                      setSheetState(() => _activeSoundName = snd.name);
                      try {
                        await _soundsPlayer.setUrl(snd.url);
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
  void onRepeatEvent(DateTime timestamp) {
    // Periodic 60-second keep-alive tick to refresh foreground task status
    // and prevent Android OS Doze mode from freezing the microphone audio pipeline.
    FlutterForegroundTask.updateService(
      notificationTitle: 'Recording Sleep...',
      notificationText: 'Sleep Astra is actively recording your sleep.',
    );
  }

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
