// ignore_for_file: avoid_print
import 'dart:convert';
import 'package:http/http.dart' as http;

const apiKey = 'AIzaSyBpXHSGiU4mObeVgNkVZEuxLm1Qrvyyuj0';
const projectId = 'snoreclinics-ai';
const numConcurrentUsers = 100;

Future<void> main() async {
  print('--- SnoreClinics AI Firebase Backend Stress Test ---');
  print('Simulating $numConcurrentUsers concurrent users signing up and saving an 8-hour sleep report...');

  final stopwatch = Stopwatch()..start();
  
  // Create 100 futures to run in parallel
  List<Future<void>> futures = [];
  for (int i = 0; i < numConcurrentUsers; i++) {
    futures.add(_simulateUserJourney(i));
  }
  
  // Wait for all users to finish
  await Future.wait(futures);
  
  stopwatch.stop();
  print('======================================');
  print('✅ BACKEND LOAD TEST COMPLETE!');
  print('Total Time: ${stopwatch.elapsed.inSeconds} seconds for $numConcurrentUsers full user journeys.');
  print('======================================');
}

Future<void> _simulateUserJourney(int index) async {
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final email = 'loadtestuser_${timestamp}_$index@example.com';
  final password = 'TestPassword123!';
  
  try {
    // 1. Sign Up
    final authRes = await http.post(
      Uri.parse('https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=$apiKey'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'returnSecureToken': true,
      }),
    );
    
    if (authRes.statusCode != 200) {
      print('❌ User $index Auth Failed: ${authRes.body}');
      return;
    }
    
    final authData = jsonDecode(authRes.body);
    final uid = authData['localId'];
    final idToken = authData['idToken'];
    
    // 2. Save 8-hour Sleep Report via Firestore REST API
    // We generate a dummy amplitude timeline with 300 points
    final timelineValues = List.generate(300, (i) => {
      'mapValue': {
        'fields': {
          'timeSeconds': {'doubleValue': i * 96.0}, // 8 hours / 300
          'amplitude': {'doubleValue': 0.5},
          'isSnoring': {'booleanValue': false},
          'stage': {'stringValue': 'light'},
          'intensity': {'stringValue': 'none'},
        }
      }
    });

    final reportPayload = {
      'fields': {
        'fileName': {'stringValue': 'stress_test_recording.wav'},
        'recordedAt': {'timestampValue': DateTime.now().toUtc().toIso8601String()},
        'totalDurationMs': {'integerValue': 28800000}, // 8 hours
        'snoringDurationMs': {'integerValue': 3600000}, // 1 hour
        'snoringEventCount': {'integerValue': 12},
        'qualityScore': {'doubleValue': 78.5},
        'quality': {'stringValue': 'good'},
        'apneaRiskLevel': {'stringValue': 'Low'},
        'sleepDebtHours': {'doubleValue': 0.0},
        'lightSleepPercent': {'doubleValue': 0.45},
        'deepSleepPercent': {'doubleValue': 0.30},
        'remSleepPercent': {'doubleValue': 0.25},
        'snoringEvents': {'arrayValue': {'values': []}},
        'amplitudeTimeline': {'arrayValue': {'values': timelineValues}},
        'insights': {'arrayValue': {'values': []}},
      }
    };
    
    final firestoreRes = await http.patch(
      Uri.parse('https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/users/$uid/sleep_reports/$timestamp'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
      body: jsonEncode(reportPayload),
    );
    
    if (firestoreRes.statusCode == 200) {
      print('✅ User $index ($email) created account and saved 8-hour report successfully.');
    } else {
      print('❌ User $index Firestore Failed: ${firestoreRes.statusCode} - ${firestoreRes.body}');
    }
  } catch (e) {
    print('❌ User $index Exception: $e');
  }
}
