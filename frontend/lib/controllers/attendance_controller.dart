import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:frontend/constants/url.dart';

class AttendanceController {
  static final _baseURL = URL.baseURL;

  /// Fetch attendance for a specific class and date
  static Future<List<Map<String, dynamic>>> getAttendance({
    required String token,
    required String classId,
    required DateTime date,
  }) async {
    final formattedDate = date.toIso8601String();
    final url = Uri.parse('$_baseURL/adminteacher/get-attendance?classId=${classId}&date=${formattedDate}');

    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final jsonMap = jsonDecode(response.body);

      if (jsonMap.containsKey('attendance')) {
        final List<dynamic> attendanceDynamic = jsonMap['attendance'];
        final attendanceList = attendanceDynamic.map<Map<String, dynamic>>((e) {
          return {
            'userId': e['userId'],
            'name': e['name'],
            'attendance': e['attendance'],
          };
        }).toList();

        return attendanceList;
      } else {
        return [];
      }
    } else {
      throw Exception('Error fetching attendance: ${response.statusCode}');
    }
  }
}
