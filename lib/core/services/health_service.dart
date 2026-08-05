import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';

/// Service to handle integration with Apple Health (iOS) and Google Fit (Android).
class HealthService {
  static final HealthService _instance = HealthService._internal();
  factory HealthService() => _instance;
  HealthService._internal();

  final Health _health = Health();

  /// Types of data we want to request from the Health SDK.
  static const List<HealthDataType> _types = [
    HealthDataType.STEPS,
    HealthDataType.HEART_RATE,
    HealthDataType.SLEEP_SESSION,
  ];

  /// Request permissions for Health data.
  Future<bool> requestPermissions() async {
    if (kIsWeb) return false;

    // Check general permission first
    if (await Permission.activityRecognition.request().isDenied) {
      return false;
    }

    try {
      bool? hasPermissions = await _health.hasPermissions(_types);
      if (hasPermissions == false) {
        return await _health.requestAuthorization(_types);
      }
      return true;
    } catch (e) {
      debugPrint('[HealthService] Permission error: $e');
      return false;
    }
  }

  /// Fetches the average heart rate during a specific time window.
  Future<double?> getAverageHeartRate(DateTime start, DateTime end) async {
    if (kIsWeb) return null;

    try {
      List<HealthDataPoint> data = await _health.getHealthDataFromTypes(
        startTime: start,
        endTime: end,
        types: [HealthDataType.HEART_RATE],
      );

      if (data.isEmpty) return null;

      double total = 0;
      for (var p in data) {
        if (p.value is NumericHealthValue) {
          total += (p.value as NumericHealthValue).numericValue.toDouble();
        }
      }
      return total / data.length;
    } catch (e) {
      debugPrint('[HealthService] Error fetching heart rate: $e');
      return null;
    }
  }

  /// Fetches the total step count during a specific day.
  Future<int?> getStepCount(DateTime start, DateTime end) async {
    if (kIsWeb) return null;

    try {
      return await _health.getTotalStepsInInterval(start, end);
    } catch (e) {
      debugPrint('[HealthService] Error fetching steps: $e');
      return null;
    }
  }
}