import 'dart:math';
import 'package:flutter/material.dart';

import '../models/sleep_report.dart';
import '../../../core/theme/app_theme.dart';

/// Animated circular gauge showing sleep quality score 0–100.
class SleepQualityCard extends StatefulWidget {
  final SleepReport report;

  const SleepQualityCard({super.key, required this.report});

  @override
  State<SleepQualityCard> createState() => _SleepQualityCardState();
}

class _SleepQualityCardState extends State<SleepQualityCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scoreAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _scoreAnim = Tween<double>(begin: 0, end: widget.report.qualityScore)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Color get _scoreColor {
    final score = widget.report.qualityScore;
    if (score >= 85) return AppTheme.success;
    if (score >= 65) return AppTheme.accentTeal;
    if (score >= 45) return AppTheme.primaryGold;
    return AppTheme.error;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _scoreColor.withValues(alpha: 0.12),
            AppTheme.surfaceElevated,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _scoreColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          _buildGauge(),
          const SizedBox(width: 24),
          Expanded(child: _buildStats(context)),
        ],
      ),
    );
  }

  Widget _buildGauge() {
    return AnimatedBuilder(
      animation: _scoreAnim,
      builder: (_, __) {
        return SizedBox(
          width: 100,
          height: 100,
          child: CustomPaint(
            painter: _GaugePainter(
              score: _scoreAnim.value,
              color: _scoreColor,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _scoreAnim.value.toInt().toString(),
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: _scoreColor,
                    ),
                  ),
                  const Text(
                    '/100',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStats(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(widget.report.qualityEmoji,
                style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Text(
              widget.report.qualityLabel,
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium!
                  .copyWith(color: _scoreColor),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _StatRow(
          icon: Icons.access_time_rounded,
          label: 'Duration',
          value: _formatDuration(widget.report.totalDuration),
        ),
        const SizedBox(height: 6),
        _StatRow(
          icon: Icons.volume_up_rounded,
          label: 'Snoring',
          value:
              '${widget.report.snoringPercentage.toStringAsFixed(1)}% of night',
          valueColor: AppTheme.error,
        ),
        const SizedBox(height: 6),
        _StatRow(
          icon: Icons.notifications_rounded,
          label: 'Events',
          value: '${widget.report.snoringEventCount} snoring events',
        ),
      ],
    );
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }
}

class _StatRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _StatRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.textSecondary, size: 14),
        const SizedBox(width: 6),
        Text('$label: ',
            style: Theme.of(context).textTheme.bodyMedium),
        Flexible(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                  color: valueColor ?? AppTheme.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double score;
  final Color color;

  _GaugePainter({required this.score, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 8;
    const startAngle = -pi * 0.75;
    const sweepAngle = pi * 1.5;

    // Background arc
    final bgPaint = Paint()
      ..color = AppTheme.cardBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      bgPaint,
    );

    // Score arc
    final fgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle * (score / 100),
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(_GaugePainter old) => old.score != score;
}
