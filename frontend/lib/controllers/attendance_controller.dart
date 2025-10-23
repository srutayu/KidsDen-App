import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:frontend/constants/url.dart';
import 'package:intl/intl.dart';

class AttendanceController {
  static final _baseURL = URL.baseURL;

  /// Fetch attendance for a specific class and date
  static Future<List<Map<String, dynamic>>> getAttendance({
    required String token,
    required String classId,
    required DateTime date,
  }) async {
  final formattedDate = date.toIso8601String();
  final url = Uri.parse('$_baseURL/adminteacher/get-attendance?classId=$classId&date=$formattedDate');

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

  static Future<bool> checkAttendance({
  required String token,
  required String classId,
}) async {
  // 🕒 Automatically use today's date
  final now = DateTime.now();

  // Format date as DD-MM-YYYY (since your API expects this)
  final formattedDate =
    '${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}-${now.year}';


  final url = Uri.parse(
      '$_baseURL/adminteacher/check-attendance?classId=$classId&date=$formattedDate');

  final response = await http.get(
    url,
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    },
  );

  if (response.statusCode == 200) {
    final Map<String, dynamic> body = jsonDecode(response.body);

    if (body.containsKey('attendance_taken')) {
      return body['attendance_taken'] == true;
    } else {
      throw Exception('Invalid response: missing "attendance_taken" key');
    }
  } else {
    throw Exception(
      'Error checking attendance: ${response.statusCode} - ${response.body}',
    );
  }
}

  static Future<bool> checkTeacherAttendance({
  required String token,
}) async {
  // 🕒 Automatically use today's date
  final now = DateTime.now();

  // Format date as DD-MM-YYYY (since your API expects this)
  final formattedDate =
    '${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}-${now.year}';


  final url = Uri.parse(
      '$_baseURL/adminteacher/check-teacher-attendance?date=$formattedDate');

  final response = await http.get(
    url,
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    },
  );

  if (response.statusCode == 200) {
    final Map<String, dynamic> body = jsonDecode(response.body);

    if (body.containsKey('attendance_taken')) {
      return body['attendance_taken'] == true;
    } else {
      throw Exception('Invalid response: missing "attendance_taken" key');
    }
  } else {
    throw Exception(
      'Error checking attendance: ${response.statusCode} - ${response.body}',
    );
  }
}

  static Future<List<Map<String, dynamic>>> getTeacherAttendance({
    required String token,
    required DateTime date,
  }) async {
  final formattedDate = DateFormat('MM-dd-yyyy').format(date);
  final url = Uri.parse('$_baseURL/admin/get-teacher-attendance?date=$formattedDate');
  // debugPrint(url.toString());
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
