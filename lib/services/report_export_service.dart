import 'package:flutter/foundation.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:universal_html/html.dart' as html;

import '../models/predictive_maintenance_result.dart';

class ReportExportService {
  Future<void> exportCsv(List<PredictiveMaintenanceResult> rows) async {
    final csv = StringBuffer()
      ..writeln(
        'timestamp,device_id,fault_prediction,fault_confidence,rul,anomaly_status,forecast_temp,recommendation,health_score,risk_level',
      );

    for (final row in rows) {
      csv.writeln(
        '${row.timestamp.toIso8601String()},${row.deviceId},${row.faultPrediction},${row.faultConfidence.toStringAsFixed(2)},${row.remainingUsefulLife},${row.anomalyStatus},${row.futureForecastTemp.toStringAsFixed(3)},"${row.maintenanceRecommendation.replaceAll('"', '""')}",${row.healthScore},${row.riskLevel}',
      );
    }

    final bytes = Uint8List.fromList(csv.toString().codeUnits);
    _download(
      filename: 'predictive-maintenance-report.csv',
      bytes: bytes,
      mime: 'text/csv',
    );
  }

  Future<void> exportPdf(List<PredictiveMaintenanceResult> rows) async {
    final doc = pw.Document();
    final topRows = rows.reversed.take(25).toList(growable: false);

    doc.addPage(
      pw.MultiPage(
        build: (context) {
          return [
            pw.Header(level: 0, text: 'Predictive Maintenance Report'),
            pw.Paragraph(
              text:
                  'Generated from ReVolve dashboard. Showing latest ${topRows.length} records.',
            ),
            pw.TableHelper.fromTextArray(
              headers: const [
                'Time',
                'Fault',
                'RUL',
                'Anomaly',
                'Health',
                'Risk',
              ],
              data: topRows
                  .map(
                    (row) => [
                      row.timestamp.toIso8601String(),
                      row.faultPrediction,
                      '${row.remainingUsefulLife}',
                      row.anomalyStatus,
                      '${row.healthScore}%',
                      row.riskLevel,
                    ],
                  )
                  .toList(growable: false),
            ),
          ];
        },
      ),
    );

    final bytes = await doc.save();
    _download(
      filename: 'predictive-maintenance-report.pdf',
      bytes: Uint8List.fromList(bytes),
      mime: 'application/pdf',
    );
  }

  void _download({
    required String filename,
    required Uint8List bytes,
    required String mime,
  }) {
    if (!kIsWeb) {
      throw UnsupportedError(
        'File download is currently supported for web builds in this project.',
      );
    }

    final blob = html.Blob([bytes], mime);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', filename)
      ..click();
    anchor.remove();
    html.Url.revokeObjectUrl(url);
  }
}
