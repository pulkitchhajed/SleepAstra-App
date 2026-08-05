import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../providers/sleep_analysis_provider.dart';
import '../models/sleep_report.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/router/app_router.dart';
import '../../../core/widgets/sleep_calendar_widget.dart';
import '../widgets/charts/historical_trend_chart.dart';

class SleepHistoryScreen extends StatefulWidget {
  const SleepHistoryScreen({super.key});

  @override
  State<SleepHistoryScreen> createState() => _SleepHistoryScreenState();
}

class _SleepHistoryScreenState extends State<SleepHistoryScreen>
    with SingleTickerProviderStateMixin {
  String? _lastUid;
  bool _showAll = false;
  late TabController _tabController;
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (auth.uid != _lastUid) {
      _lastUid = auth.uid;
    }
    
    final isLight = context.watch<ThemeProvider>().isDarkMode == false;
    final bg = isLight ? AppTheme.backgroundLight : const Color(0xFF0D0F1E);
    final textPrimary = isLight ? AppTheme.textPrimaryLight : Colors.white;
    final textSec = isLight ? AppTheme.textSecondaryLight : Colors.white.withValues(alpha: 0.4);
    final cardBg = isLight ? AppTheme.surfaceLight : const Color(0xFF1A1D33);
    final cardBorder = isLight ? AppTheme.cardBorderLight : Colors.white.withValues(alpha: 0.12);

    return Scaffold(
      backgroundColor: bg,
      body: Container(
        decoration: BoxDecoration(
          color: bg,
          gradient: isLight ? null : const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0D0F1E), Color(0xFF080A13)],
          ),
        ),
        child: SafeArea(
          child: Consumer<SleepAnalysisProvider>(
            builder: (context, provider, _) {
              if (provider.history.isEmpty) {
                return _buildEmptyState(textPrimary, textSec, cardBorder, cardBg);
              }

              return Column(
                children: [
                  _buildAppBar(provider.history, textPrimary, textSec, cardBorder, cardBg),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildCalendarTab(provider.history, textPrimary, textSec),
                        _buildListTab(provider, textPrimary, textSec, cardBg, cardBorder),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // ─── Custom AppBar with tabs ───────────────────────────────────
  Widget _buildAppBar(List<SleepReport> history, Color textPrimary, Color textSec, Color cardBorder, Color cardBg) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Center(
            child: Text(
              'My Sleep',
              style: TextStyle(
                color: textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 17,
              ),
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          height: 42,
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cardBorder),
          ),
          child: TabBar(
            controller: _tabController,
            indicator: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.primaryIndigo, Color(0xFF8B5CF6)],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryIndigo.withValues(alpha: 0.4),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            labelColor: Colors.white,
            unselectedLabelColor: textSec,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
            tabs: const [
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.calendar_month_rounded, size: 15),
                    SizedBox(width: 6),
                    Text('Calendar'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.list_rounded, size: 15),
                    SizedBox(width: 6),
                    Text('List'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Calendar Tab ──────────────────────────────────────────────
  Widget _buildCalendarTab(List<SleepReport> history, Color textPrimary, Color textSec) {
    // Filter to selected month for trend/stats
    final monthHistory = history.where((r) =>
        r.recordedAt.year == _selectedMonth.year &&
        r.recordedAt.month == _selectedMonth.month).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Calendar
          SleepCalendarWidget(
            reports: history,
            onMonthChanged: (month) => setState(() => _selectedMonth = month),
          ),
          const SizedBox(height: 16),
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legend(AppTheme.accentTeal, 'Good (≥80)', textSec),
              const SizedBox(width: 16),
              _legend(AppTheme.primaryGold, 'Fair (60–79)', textSec),
              const SizedBox(width: 16),
              _legend(AppTheme.error, 'Poor (<60)', textSec),
            ],
          ),
          const SizedBox(height: 28),
          // Trend chart filtered to selected month
          _buildSectionHeader('Score Trend', Icons.trending_up_rounded, textPrimary),
          const SizedBox(height: 12),
          HistoricalTrendChart(history: monthHistory.isNotEmpty ? monthHistory : history),
          const SizedBox(height: 24),
          // Stats summary filtered to selected month
          _buildStatsSummary(monthHistory.isNotEmpty ? monthHistory : history, textPrimary),
        ],
      ),
    );
  }

  Widget _legend(Color color, String label, Color textSec) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.5),
                blurRadius: 4,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: textSec,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color textPrimary) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 18,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppTheme.primaryIndigo, AppTheme.accentTeal],
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Icon(icon, color: AppTheme.primaryIndigo, size: 16),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            color: textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsSummary(List<SleepReport> history, Color textPrimary) {
    if (history.isEmpty) return const SizedBox.shrink();

    final avgScore = history.map((r) => r.qualityScore).reduce((a, b) => a + b) / history.length;
    final bestScore = history.map((r) => r.qualityScore).reduce((a, b) => a > b ? a : b);
    final totalSessions = history.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Monthly Overview', Icons.insights_rounded, textPrimary),
        const SizedBox(height: 12),
        Row(
          children: [
            _statCard('${avgScore.toInt()}', 'Avg Score', AppTheme.primaryIndigo),
            const SizedBox(width: 12),
            _statCard('${bestScore.toInt()}', 'Best Score', AppTheme.accentTeal),
            const SizedBox(width: 12),
            _statCard('$totalSessions', 'Sessions', AppTheme.primaryGold),
          ],
        ),
      ],
    );
  }

  Widget _statCard(String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withValues(alpha: 0.12),
              color.withValues(alpha: 0.04),
            ],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 26,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color.withValues(alpha: 0.8),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── List Tab ──────────────────────────────────────────────────
  Widget _buildListTab(SleepAnalysisProvider provider, Color textPrimary, Color textSec, Color cardBg, Color cardBorder) {
    final twoWeeksAgo = DateTime.now().subtract(const Duration(days: 14));
    final recentHistory = provider.history
        .where((r) => r.recordedAt.isAfter(twoWeeksAgo))
        .toList();
    final olderHistory = provider.history
        .where((r) => r.recordedAt.isBefore(twoWeeksAgo))
        .toList();

    final displayList = _showAll ? provider.history : recentHistory;

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      itemCount: displayList.length + (olderHistory.isNotEmpty && !_showAll ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index == displayList.length) {
          return _buildShowOlderButton(olderHistory.length, cardBg, cardBorder, textSec);
        }
        final report = displayList[index];
        return _HistoryCard(
          report: report,
          cardBg: cardBg,
          cardBorder: cardBorder,
          textPrimary: textPrimary,
          textSec: textSec,
          onTap: () => Navigator.pushNamed(
            context,
            AppRouter.sleepReport,
            arguments: report,
          ),
          onDelete: () => _confirmDelete(context, provider, report),
        );
      },
    );
  }

  Widget _buildShowOlderButton(int count, Color cardBg, Color cardBorder, Color textSec) {
    return Center(
      child: GestureDetector(
        onTap: () => setState(() => _showAll = true),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cardBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.history_toggle_off_rounded,
                  color: textSec, size: 16),
              const SizedBox(width: 8),
              Text(
                'Show $count older sessions',
                style: TextStyle(
                    color: textSec, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Empty state ───────────────────────────────────────────────
  Widget _buildEmptyState(Color textPrimary, Color textSec, Color cardBorder, Color cardBg) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        automaticallyImplyLeading: false,
        title: Text('My Sleep',
            style: TextStyle(color: textPrimary, fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/images/empty_sleep.png', width: 140, height: 140),
            const SizedBox(height: 24),
            Text(
              'No Sleep History Yet',
              style: TextStyle(
                color: textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: Text(
                'Your future recordings and analysis will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: textSec,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context,
      SleepAnalysisProvider provider,
      SleepReport report) async {
    final delete = await showDialog<bool>(
      context: context,
      builder: (context) {
        final isLight = context.watch<ThemeProvider>().isDarkMode == false;
        final cardBg = isLight ? AppTheme.surfaceLight : const Color(0xFF1A1D33);
        final textPrimary = isLight ? AppTheme.textPrimaryLight : Colors.white;
        final textSec = isLight ? AppTheme.textSecondaryLight : Colors.white.withValues(alpha: 0.6);

        return AlertDialog(
          backgroundColor: cardBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Delete Report?',
              style: TextStyle(color: textPrimary, fontWeight: FontWeight.w700)),
          content: Text(
            'This will permanently remove this sleep analysis result.',
            style: TextStyle(color: textSec),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel',
                  style: TextStyle(color: textSec)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: AppTheme.error),
              child: const Text('Delete',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    );

    if (delete == true) {
      provider.deleteFromHistory(report);
    }
  }
}

// ─── History card ─────────────────────────────────────────────────────
class _HistoryCard extends StatelessWidget {
  final SleepReport report;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final Color cardBg;
  final Color cardBorder;
  final Color textPrimary;
  final Color textSec;

  const _HistoryCard({
    required this.report,
    required this.onTap,
    required this.onDelete,
    required this.cardBg,
    required this.cardBorder,
    required this.textPrimary,
    required this.textSec,
  });

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('EEE, MMM d, yyyy').format(report.recordedAt);
    final time = DateFormat('h:mm a').format(report.recordedAt);
    final color = _getQualityColor(report.quality);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cardBorder, width: 0.8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Score circle
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
              ),
              child: Center(
                child: Text(
                  report.qualityEmoji,
                  style: const TextStyle(fontSize: 24),
                ),
              ),
            ),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    date,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$time · ${report.totalDuration.inHours}h ${report.totalDuration.inMinutes % 60}m',
                    style: TextStyle(
                      fontSize: 12,
                      color: textSec,
                    ),
                  ),
                ],
              ),
            ),
            // Score + delete
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${report.qualityScore.toInt()}',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                    color: color,
                  ),
                ),
                GestureDetector(
                  onTap: onDelete,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Icon(Icons.delete_outline_rounded,
                        size: 18, color: textSec),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getQualityColor(SleepQuality quality) {
    switch (quality) {
      case SleepQuality.excellent: return AppTheme.accentTeal;
      case SleepQuality.good: return AppTheme.accentTeal;
      case SleepQuality.fair: return AppTheme.primaryGold;
      case SleepQuality.poor: return AppTheme.error;
    }
  }
}
