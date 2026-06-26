// ignore_for_file: avoid_print
import 'dart:convert';
import 'package:http/http.dart' as http;

const apiKey = 'AIzaSyBpXHSGiU4mObeVgNkVZEuxLm1Qrvyyuj0';
const projectId = 'snoreclinics-ai';

void main() async {
  // First, we need to sign in as one of the test users to get a token
  // Let's sign up a new user just to get a fresh token
  final email = 'check_db_${DateTime.now().millisecondsSinceEpoch}@example.com';
  
  final authRes = await http.post(
    Uri.parse('https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=$apiKey'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'email': email,
      'password': 'TestPassword123!',
      'returnSecureToken': true,
    }),
  );
  
  final authData = jsonDecode(authRes.body);
  final idToken = authData['idToken'];
  
  if (idToken == null) {
    print('Failed to get token: \${authRes.body}');
    return;
  }
  
  // Now try to list users or run a structured query for sleep_reports
  final queryPayload = {
    'structuredQuery': {
      'from': [{'collectionId': 'sleep_reports', 'allDescendants': true}],
      'limit': 10
    }
  };
  
  final firestoreRes = await http.post(
    Uri.parse('https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents:runQuery'),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $idToken',
    },
    body: jsonEncode(queryPayload),
  );
  
  print('Firestore Status: ${firestoreRes.statusCode}');
  print('Firestore Response Length: ${firestoreRes.body.length}');
  print('Firestore Response snippet: ${firestoreRes.body.substring(0, firestoreRes.body.length > 500 ? 500 : firestoreRes.body.length)}');
}
