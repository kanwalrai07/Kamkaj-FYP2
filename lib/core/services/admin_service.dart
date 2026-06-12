import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class AdminService {
  // In development, use localhost or your machine's IP
  // For Android emulator, use 10.0.2.2 instead of localhost
  final String baseUrl = kIsWeb ? 'http://localhost:3000' : 'http://10.0.2.2:3000';

  Future<List<dynamic>> getPendingCNICs() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/admin/cnic-pending'));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load pending CNICs');
      }
    } catch (e) {
      debugPrint('Error fetching CNICs: $e');
      return [];
    }
  }

  Future<bool> verifyWorker(String workerId, String status, {String? reason}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/admin/verify-worker'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'workerId': workerId,
          'status': status,
          'reason': reason,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error verifying worker: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> getUstaadScore(String workerId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/worker/$workerId/ustaad-score'));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching Ustaad Score: $e');
      return null;
    }
  }
}
