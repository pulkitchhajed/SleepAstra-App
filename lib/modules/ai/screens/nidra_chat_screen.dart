import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../sleep_analysis/services/sleep_storage_service.dart';
import '../../sleep_analysis/models/sleep_report.dart';
import '../../journal/models/journal_entry.dart';
import '../../onboarding/models/user_profile.dart';
import '../../journal/providers/journal_provider.dart';
import '../../onboarding/providers/onboarding_provider.dart';
import '../services/gemini_service.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart' show compute;
import '../../../core/services/firestore_service.dart';

/// Top-level helper needed by compute() — must have exactly one parameter.
List<dynamic> _decodeJsonList(String source) => jsonDecode(source) as List<dynamic>;

class _Message {
  final String text;
  final bool isUser;
  final bool isLoading;
  _Message(this.text, {this.isUser = false, this.isLoading = false});

  Map<String, dynamic> toJson() => {'text': text, 'isUser': isUser, 'isLoading': isLoading};
  factory _Message.fromJson(Map<String, dynamic> json) => _Message(
    json['text'] as String? ?? '',
    isUser: json['isUser'] as bool? ?? false,
    isLoading: json['isLoading'] as bool? ?? false,
  );
}

class NidraChatScreen extends StatefulWidget {
  final bool isModal;
  const NidraChatScreen({super.key, this.isModal = false});
  @override
  State<NidraChatScreen> createState() => _NidraChatScreenState();
}

class _NidraChatScreenState extends State<NidraChatScreen>
    with TickerProviderStateMixin {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  final _gemini = GeminiService();
  final List<_Message> _messages = [];
  SleepReport? _latestReport;
  List<SleepReport> _sleepHistory = [];
  JournalEntry? _latestJournal;
  UserProfile? _userProfile;
  bool _sending = false;
  bool _inputFocused = false;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode()
      ..addListener(() {
        setState(() => _inputFocused = _focusNode.hasFocus);
      });
    _init();
  }

  Future<void> _init() async {
    final authProvider = context.read<AuthProvider>();
    final journalProvider = context.read<JournalProvider>();
    final onboardingProvider = context.read<OnboardingProvider>();

    final uid = authProvider.uid ?? await FirestoreService.deviceUid;

    // Load all data in parallel for performance
    final reports = await SleepStorageService().getAllReports(uid);
    final prefs = await SharedPreferences.getInstance();

    // Load journal entries from provider (already loaded at app start)
    final journalEntries = journalProvider.entries;

    // Load user profile from provider (already loaded at app start)
    final profile = onboardingProvider.profile;

    if (!mounted) return;
    setState(() {
      _sleepHistory = reports;
      _latestReport = reports.isEmpty ? null : reports.first;

      // Latest journal: prefer the most recent evening entry, fall back to any entry
      _latestJournal = journalEntries.isEmpty
          ? null
          : journalEntries.firstWhere(
              (e) => e.type == JournalType.evening,
              orElse: () => journalEntries.first,
            );

      _userProfile = profile.name.isNotEmpty ? profile : null;
    });

    final historyStr = prefs.getString('chat_history_$uid');
    if (historyStr != null) {
      try {
        // Offload JSON parsing to background isolate to avoid UI jank on large histories
        final List<dynamic> decoded = await compute(_decodeJsonList, historyStr);
        final loadedMessages = decoded.map((e) {
          final m = _Message.fromJson(e);
          return _Message(m.text, isUser: m.isUser, isLoading: false);
        }).toList()
          ..removeWhere((m) => !m.isUser && m.text.isEmpty);
        if (!mounted) return;
        setState(() {
          _messages.addAll(loadedMessages);
        });
      } catch (_) {}
    }

    if (!mounted) return;
    if (_messages.isEmpty) {
        final name = _userProfile?.name.isNotEmpty == true
            ? ', ${_userProfile!.name.split(' ').first}'
            : '';
        _messages.add(_Message(
          _latestReport == null
              ? 'Hi$name! I\'m **Nidra**, your AI sleep assistant 🌙\nRecord your first sleep session and I\'ll give you personalised insights. Or ask me anything about sleep!\n\nFor more information - go to [SnoreClinics.org](https://snoreclinics.org/)'
              : 'Hi$name! I\'m **Nidra** 🌙\nYour last session scored **${_latestReport!.qualityScore.toInt()}/100**. Ask me anything about your sleep!\n\nFor more information - go to [SnoreClinics.org](https://snoreclinics.org/)',
        ));
        setState(() {});
        _saveHistory();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollDown());
  }

  Future<void> _saveHistory() async {
    if (!context.mounted) return;
    final authProvider = context.read<AuthProvider>();
    final uid = authProvider.uid ?? await FirestoreService.deviceUid;
    final prefs = await SharedPreferences.getInstance();
    // Keep last 50 messages to avoid huge storage
    final toSave = _messages.length > 50 ? _messages.sublist(_messages.length - 50) : _messages;
    await prefs.setString('chat_history_$uid', jsonEncode(toSave.map((e) => e.toJson()).toList()));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLightMode = Theme.of(context).brightness == Brightness.light;
    return Scaffold(
      backgroundColor: isLightMode ? AppTheme.backgroundLight : AppTheme.background,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isLightMode
                ? [AppTheme.backgroundLight, AppTheme.surfaceLight]
                : [const Color(0xFF0D0F1E), const Color(0xFF080A13)],
          ),
        ),
        child: Column(
          children: [
            _buildAppBar(),
            _buildSuggestionsRow(),
            Expanded(
              child: ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                itemCount: _messages.length,
                itemBuilder: (_, i) => _bubble(_messages[i], i),
              ),
            ),
            _buildHelpBanner(),
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  // ─── AppBar ────────────────────────────────────────────────────
  Widget _buildAppBar() {
    final isLightMode = Theme.of(context).brightness == Brightness.light;
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16,
        right: 8,
        bottom: 12,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            isLightMode ? AppTheme.surfaceLight : const Color(0xFF0D0F1E),
            isLightMode ? AppTheme.surfaceLight.withValues(alpha: 0.95) : const Color(0xFF0D0F1E).withValues(alpha: 0.95),
          ],
        ),
        border: Border(
          bottom: BorderSide(
            color: isLightMode ? AppTheme.cardBorderLight : AppTheme.primaryIndigo.withValues(alpha: 0.12),
            width: 0.8,
          ),
        ),
      ),
      child: Row(
        children: [
          if (widget.isModal)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: IconButton(
                icon: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: isLightMode ? AppTheme.textPrimaryLight : Colors.white,
                  size: 20,
                ),
                onPressed: () => Navigator.pop(context),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ),
          // Avatar with glow
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryIndigo.withValues(alpha: isLightMode ? 0.2 : 0.4),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset('assets/images/nidra.png', fit: BoxFit.contain),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Nidra',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isLightMode ? AppTheme.textPrimaryLight : Colors.white,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppTheme.primaryIndigo, Color(0xFF8B5CF6)],
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'AI',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.accentTeal,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.accentTeal.withValues(alpha: 0.6),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'AI Sleep Assistant · Online',
                      style: TextStyle(
                        fontSize: 11,
                        color: isLightMode ? AppTheme.textSecondaryLight : AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (widget.isModal || Navigator.canPop(context))
            GestureDetector(
              onTap: () {
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                }
              },
              child: Container(
                width: 36,
                height: 36,
                margin: const EdgeInsets.only(right: 4),
                decoration: BoxDecoration(
                  color: isLightMode ? Colors.black.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isLightMode ? Colors.black.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.1)),
                ),
                child: Icon(Icons.close_rounded, color: isLightMode ? Colors.black54 : Colors.white60, size: 18),
              ),
            ),
        ],
      ),
    );
  }

  // ─── Suggestion chips ──────────────────────────────────────────
  Widget _buildSuggestionsRow() {
    final isLightMode = Theme.of(context).brightness == Brightness.light;
    final chips = [
      ('My sleep score?', Icons.star_rounded),
      ('Why do I snore?', Icons.help_outline_rounded),
      ('Sleep tips', Icons.lightbulb_rounded),
      ('Apnea risk', Icons.favorite_rounded),
    ];
    return Container(
      decoration: BoxDecoration(
        color: isLightMode ? AppTheme.surfaceLight.withValues(alpha: 0.9) : const Color(0xFF0D0F1E).withValues(alpha: 0.9),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        child: Row(
          children: chips.map((chip) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => _sendMessage(chip.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.primaryIndigo.withValues(alpha: isLightMode ? 0.12 : 0.18),
                        const Color(0xFF8B5CF6).withValues(alpha: isLightMode ? 0.06 : 0.10),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(50),
                    border: Border.all(
                      color: AppTheme.primaryIndigo.withValues(alpha: isLightMode ? 0.25 : 0.35),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(chip.$2, size: 13, color: AppTheme.primaryIndigo.withValues(alpha: 0.8)),
                      const SizedBox(width: 6),
                      Text(
                        chip.$1,
                        style: TextStyle(
                          color: isLightMode ? AppTheme.textSecondaryLight : AppTheme.textSecondary,
                          fontSize: 12,
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
      ),
    );
  }

  // ─── Message bubbles ───────────────────────────────────────────
  Widget _bubble(_Message m, int index) {
    if (m.isUser) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16, left: 52),
        child: Align(
          alignment: Alignment.centerRight,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.primaryIndigo, Color(0xFF8B5CF6)],
              ),
              borderRadius: BorderRadius.circular(20).copyWith(
                bottomRight: const Radius.circular(5),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryIndigo.withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              m.text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
        ),
      );
    }

    final isLightMode = Theme.of(context).brightness == Brightness.light;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, right: 40),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 30,
            height: 30,
            margin: const EdgeInsets.only(right: 10, bottom: 2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryIndigo.withValues(alpha: isLightMode ? 0.15 : 0.3),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset('assets/images/nidra.png', fit: BoxFit.contain),
            ),
          ),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isLightMode
                      ? [AppTheme.surfaceLight, const Color(0xFFF1F5F9)]
                      : [const Color(0xFF1A1D33), const Color(0xFF141728)],
                ),
                borderRadius: BorderRadius.circular(20).copyWith(
                  bottomLeft: const Radius.circular(5),
                ),
                border: Border.all(
                  color: isLightMode
                      ? AppTheme.cardBorderLight
                      : AppTheme.primaryIndigo.withValues(alpha: 0.18),
                  width: 0.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isLightMode ? 0.04 : 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: m.isLoading
                  ? const _TypingIndicator()
                  : MarkdownBody(
                      data: m.text,
                      selectable: true,
                      onTapLink: (text, href, title) {
                        if (href != null && href.isNotEmpty) {
                          launchUrl(Uri.parse(href),
                              mode: LaunchMode.externalApplication);
                        }
                      },
                      styleSheet: MarkdownStyleSheet(
                        p: TextStyle(
                          color: isLightMode ? AppTheme.textPrimaryLight : Colors.white,
                          fontSize: 14,
                          height: 1.6,
                        ),
                        strong: const TextStyle(
                          color: AppTheme.accentTeal,
                          fontWeight: FontWeight.w700,
                        ),
                        a: const TextStyle(
                          color: AppTheme.primaryIndigo,
                          decoration: TextDecoration.underline,
                          decorationColor: AppTheme.primaryIndigo,
                          fontWeight: FontWeight.w600,
                        ),
                        listBullet: TextStyle(color: isLightMode ? AppTheme.textPrimaryLight.withValues(alpha: 0.8) : Colors.white60),
                        blockquote: TextStyle(color: isLightMode ? AppTheme.textSecondaryLight : Colors.white54, fontStyle: FontStyle.italic),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Help banner ───────────────────────────────────────────────
  Widget _buildHelpBanner() {
    final isLightMode = Theme.of(context).brightness == Brightness.light;
    return GestureDetector(
      onTap: () => launchUrl(
        Uri.parse('https://snoreclinics.org/'),
        mode: LaunchMode.externalApplication,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.primaryIndigo.withValues(alpha: isLightMode ? 0.05 : 0.10),
              const Color(0xFF8B5CF6).withValues(alpha: isLightMode ? 0.03 : 0.06),
            ],
          ),
          border: Border(
            top: BorderSide(
              color: AppTheme.primaryIndigo.withValues(alpha: isLightMode ? 0.10 : 0.15),
              width: 0.8,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.language_rounded, size: 14, color: AppTheme.primaryIndigo.withValues(alpha: 0.8)),
            const SizedBox(width: 8),
            Text(
              'For more information — visit ',
              style: TextStyle(
                fontSize: 12,
                color: isLightMode ? AppTheme.textSecondaryLight : Colors.white.withValues(alpha: 0.4),
              ),
            ),
            Text(
              'SnoreClinics.org',
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.primaryIndigo,
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.underline,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.open_in_new_rounded, size: 12, color: AppTheme.primaryIndigo.withValues(alpha: 0.7)),
          ],
        ),
      ),
    );
  }

  // ─── Input bar ─────────────────────────────────────────────────
  Widget _buildInputBar() {
    final isLightMode = Theme.of(context).brightness == Brightness.light;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: EdgeInsets.fromLTRB(
        16, 10, 16, MediaQuery.of(context).padding.bottom + 10,
      ),
      decoration: BoxDecoration(
        color: isLightMode ? AppTheme.surfaceLight : const Color(0xFF0E0F1C),
        border: Border(
          top: BorderSide(
            color: _inputFocused
                ? AppTheme.primaryIndigo.withValues(alpha: 0.4)
                : isLightMode ? AppTheme.cardBorderLight : AppTheme.primaryIndigo.withValues(alpha: 0.12),
            width: _inputFocused ? 1 : 0.8,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isLightMode ? 0.04 : 0.3),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isLightMode
                      ? [const Color(0xFFF1F5F9), const Color(0xFFE2E8F0)]
                      : [const Color(0xFF1A1D33), const Color(0xFF141728)],
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: _inputFocused
                      ? AppTheme.primaryIndigo.withValues(alpha: 0.5)
                      : isLightMode ? AppTheme.cardBorderLight : Colors.white.withValues(alpha: 0.08),
                  width: 1,
                ),
                boxShadow: _inputFocused
                    ? [
                        BoxShadow(
                          color: AppTheme.primaryIndigo.withValues(alpha: 0.15),
                          blurRadius: 12,
                          spreadRadius: 1,
                        ),
                      ]
                    : [],
              ),
              child: TextField(
                controller: _ctrl,
                focusNode: _focusNode,
                style: TextStyle(color: isLightMode ? AppTheme.textPrimaryLight : Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Ask Nidra anything...',
                  hintStyle: TextStyle(
                    color: isLightMode ? AppTheme.textSecondaryLight.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.3),
                    fontSize: 14,
                  ),
                  filled: false,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 13,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
                onSubmitted: _sendMessage,
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Send button
          GestureDetector(
            onTap: () => _sendMessage(_ctrl.text),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: _sending
                    ? LinearGradient(
                        colors: [
                          isLightMode ? Colors.black.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.06),
                          isLightMode ? Colors.black.withValues(alpha: 0.04) : Colors.white.withValues(alpha: 0.04),
                        ],
                      )
                    : const LinearGradient(
                        colors: [AppTheme.primaryIndigo, Color(0xFF8B5CF6)],
                      ),
                boxShadow: _sending
                    ? []
                    : [
                        BoxShadow(
                          color: AppTheme.primaryIndigo.withValues(alpha: 0.5),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              child: _sending
                  ? const _MiniLoader()
                  : const Icon(Icons.arrow_upward_rounded,
                      color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendMessage(String text) async {
    final msg = text.trim();
    if (msg.isEmpty || _sending) return;
    _ctrl.clear();
    setState(() {
      _sending = true;
      _messages.add(_Message(msg, isUser: true));
      _messages.add(_Message('', isLoading: true));
    });
    _scrollDown();

    final buffer = StringBuffer();
    final idx = _messages.length - 1;

    // Build history from all prior non-loading messages (exclude current user msg)
    final history = _messages
        .sublist(0, _messages.length - 2) // exclude the just-added user msg and loading msg
        .where((m) => !m.isLoading && m.text.isNotEmpty)
        .map((m) => {'role': m.isUser ? 'user' : 'model', 'text': m.text})
        .toList();

    try {
      await for (final chunk in _gemini.chat(
        msg,
        userProfile: _userProfile,
        latestReport: _latestReport,
        latestJournal: _latestJournal,
        sleepHistory: _sleepHistory,
        history: history,
      )) {
        buffer.write(chunk);
        if (mounted) {
          setState(() {
            _messages[idx] = _Message(buffer.toString());
          });
        }
      }
    } catch (e) {
      debugPrint('NidraChat UI Error: $e');
      if (mounted) {
        setState(() {
          _messages[idx] = _Message("I'm sorry, I'm having trouble connecting right now. Please try again later.");
        });
      }
    } finally {
      if (mounted) setState(() => _sending = false);
      _saveHistory();
      _scrollDown();
    }
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }
}

// ─── Typing indicator (3 bouncing dots) ────────────────────────
class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();
  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _anims;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      3,
      (i) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 500),
      ),
    );

    // stagger each dot
    for (int i = 0; i < 3; i++) {
      Future.delayed(Duration(milliseconds: i * 160), () {
        if (mounted) _controllers[i].repeat(reverse: true);
      });
    }

    _anims = _controllers
        .map((c) => CurvedAnimation(parent: c, curve: Curves.easeInOut))
        .toList();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 20,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(3, (i) {
          return AnimatedBuilder(
            animation: _anims[i],
            builder: (_, __) => Container(
              width: 7,
              height: 7,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primaryIndigo.withValues(
                  alpha: 0.4 + 0.6 * _anims[i].value,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryIndigo.withValues(alpha: 0.3 * _anims[i].value),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ],
              ),
              transform: Matrix4.translationValues(
                0,
                -4 * _anims[i].value,
                0,
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ─── Mini loader for send button ───────────────────────────────
class _MiniLoader extends StatefulWidget {
  const _MiniLoader();
  @override
  State<_MiniLoader> createState() => _MiniLoaderState();
}

class _MiniLoaderState extends State<_MiniLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Transform.rotate(
        angle: _ctrl.value * 2 * math.pi,
        child: const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            color: Colors.white54,
            strokeWidth: 2,
          ),
        ),
      ),
    );
  }
}
