import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:snore_clinics/modules/sleep_analysis/screens/sleep_report_screen.dart';
import 'package:snore_clinics/modules/sleep_analysis/models/sleep_report.dart';

void main() {
  testWidgets('Graph Screenshot', (WidgetTester tester) async {
    // Generate some dummy spots
    final timeline = List.generate(600, (i) {
      SleepStage stage;
      if (i < 100) { stage = SleepStage.light; }
      else if (i < 200) { stage = SleepStage.deep; }
      else if (i < 300) { stage = SleepStage.light; }
      else if (i < 400) { stage = SleepStage.rem; }
      else if (i < 500) { stage = SleepStage.light; }
      else { stage = SleepStage.awake; }

      final isSnoring = i % 15 == 0 && stage != SleepStage.deep;
      return AmplitudeSample(
        timeSeconds: i * 60.0,
        amplitude: isSnoring ? 0.8 : 0.15,
        isSnoring: isSnoring,
        stage: stage,
      );
    });

    final report = SleepReport(
      fileName: 'dummy.wav',
      recordedAt: DateTime.now(),
      totalDuration: const Duration(hours: 8),
      snoringDuration: const Duration(minutes: 10),
      snoringEventCount: 5,
      qualityScore: 85,
      quality: SleepQuality.good,
      snoringEvents: [],
      amplitudeTimeline: timeline,
      insights: [],
    );

    // Render it in a big window
    tester.view.physicalSize = const Size(1440, 2560);
    tester.view.devicePixelRatio = 2.0;

    await tester.pumpWidget(MaterialApp(
      home: SleepReportScreen(report: report),
    ));

    // Tap the 'Sleep Stages' tab so it's active
    await tester.tap(find.text('Sleep Stages'));
    await tester.pumpAndSettle();

    await expectLater(find.byType(SleepReportScreen), matchesGoldenFile('graph_screenshot.png'));
  });
}
