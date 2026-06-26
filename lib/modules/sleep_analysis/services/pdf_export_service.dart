import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/sleep_report.dart';

class PdfExportService {
  static Future<void> exportSleepReport(SleepReport report) async {
    final pdf = pw.Document();
    
    // Default font
    final font = await PdfGoogleFonts.outfitRegular();
    final fontBold = await PdfGoogleFonts.outfitBold();

    final dateStr = DateFormat('EEEE, d MMM yyyy').format(report.recordedAt);
    final durStr = '${report.totalDuration.inHours}h ${report.totalDuration.inMinutes.remainder(60)}m';

    // Downsample amplitude data for chart (max 100 points)
    final step = (report.amplitudeTimeline.length / 100).ceil().clamp(1, 1000);
    final chartData = <pw.PointChartValue>[];
    for (int i = 0; i < report.amplitudeTimeline.length; i += step) {
      chartData.add(pw.PointChartValue(
        report.amplitudeTimeline[i].timeSeconds / 60, // x axis in minutes
        report.amplitudeTimeline[i].amplitude,
      ));
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return [
            // Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('SnoreClinics Sleep Report', style: pw.TextStyle(font: fontBold, fontSize: 24, color: PdfColors.indigo700)),
                pw.Text(dateStr, style: pw.TextStyle(font: font, fontSize: 14, color: PdfColors.grey700)),
              ],
            ),
            pw.Divider(thickness: 2, color: PdfColors.indigo900),
            pw.SizedBox(height: 20),
            
            // Key Metrics Card
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 20, horizontal: 15),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _buildMetric('Sleep Score', '${report.qualityScore.toInt()}/100', font, fontBold, PdfColors.indigo700),
                  _buildMetric('Time in Bed', durStr, font, fontBold, PdfColors.black),
                  _buildMetric('Snore Time', '${report.snoringDuration.inHours}h ${report.snoringDuration.inMinutes.remainder(60)}m', font, fontBold, PdfColors.redAccent),
                ],
              ),
            ),
            pw.SizedBox(height: 30),
            
            // AI Insights
            pw.Text('AI Insights', style: pw.TextStyle(font: fontBold, fontSize: 18, color: PdfColors.black)),
            pw.Divider(),
            pw.SizedBox(height: 10),
            ...report.insights.map((insight) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 12),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                    width: 8,
                    height: 8,
                    margin: const pw.EdgeInsets.only(top: 4, right: 10),
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.indigo,
                      shape: pw.BoxShape.circle,
                    ),
                  ),
                  pw.Expanded(
                    child: pw.RichText(
                      text: pw.TextSpan(
                        children: [
                          pw.TextSpan(text: '${insight.title}: ', style: pw.TextStyle(font: fontBold, fontSize: 12, color: PdfColors.black)),
                          pw.TextSpan(text: insight.description, style: pw.TextStyle(font: font, fontSize: 12, lineSpacing: 1.5, color: PdfColors.grey800)),
                        ],
                      ),
                    ),
                  ),
                ]
              )
            )),
            
            pw.SizedBox(height: 30),
            
            // Amplitude Timeline Graph
            if (chartData.isNotEmpty) ...[
              pw.Text('Snoring Intensity Timeline', style: pw.TextStyle(font: fontBold, fontSize: 18, color: PdfColors.black)),
              pw.Divider(),
              pw.SizedBox(height: 10),
              pw.Container(
                height: 150,
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Chart(
                  grid: pw.CartesianGrid(
                    xAxis: pw.FixedAxis([
                      0,
                      if (chartData.isNotEmpty) chartData.last.x / 2,
                      if (chartData.isNotEmpty) chartData.last.x,
                    ]),
                    yAxis: pw.FixedAxis([0, 0.5, 1.0]),
                  ),
                  datasets: [
                    pw.LineDataSet(
                      color: PdfColors.teal,
                      drawSurface: true,
                      isCurved: true,
                      surfaceColor: PdfColors.teal.shade(100),
                      surfaceOpacity: 0.3,
                      data: chartData,
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Center(
                child: pw.Text('Time (Minutes) vs Amplitude', style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey700)),
              ),
              pw.SizedBox(height: 30),
            ],

            // Detailed Metrics
            pw.Text('Detailed Metrics', style: pw.TextStyle(font: fontBold, fontSize: 18, color: PdfColors.black)),
            pw.Divider(),
            pw.SizedBox(height: 10),
            
            _buildDetailRow('Snoring Percentage', '${report.snoringPercentage.toStringAsFixed(1)}%', font),
            _buildDetailRow('Apnea Risk Level', report.apneaRiskLevel, font),
            _buildDetailRow('Sleep Debt', '${report.sleepDebtHours.toStringAsFixed(1)} hours', font),
            _buildDetailRow('Total Snore Events', '${report.snoringEvents.length}', font),
            
            pw.SizedBox(height: 40),
            pw.Center(
              child: pw.Text('Generated by SnoreClinics App', style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey)),
            ),
          ];
        },
      ),
    );

    // Share or print
    await Printing.sharePdf(bytes: await pdf.save(), filename: 'sleep_report_${DateFormat('yyyyMMdd').format(report.recordedAt)}.pdf');
  }

  static pw.Widget _buildMetric(String label, String value, pw.Font font, pw.Font fontBold, PdfColor color) {
    return pw.Column(
      children: [
        pw.Text(label, style: pw.TextStyle(font: font, fontSize: 12, color: PdfColors.grey700)),
        pw.SizedBox(height: 8),
        pw.Text(value, style: pw.TextStyle(font: fontBold, fontSize: 24, color: color)),
      ],
    );
  }

  static pw.Widget _buildDetailRow(String label, String value, pw.Font font) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 6),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(font: font, fontSize: 13, color: PdfColors.grey800)),
          pw.Text(value, style: pw.TextStyle(font: font, fontSize: 13, color: PdfColors.black)),
        ],
      ),
    );
  }
}

