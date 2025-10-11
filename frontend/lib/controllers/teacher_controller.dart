import 'package:frontend/constants/url.dart';
import 'package:frontend/models/classroom_model.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class TeacherController {
  static final _baseURL = URL.baseURL;

  Future<bool> addStudents(classId, studentsId, token) async {
    final url = Uri.parse('$_baseURL/teacher/add-students');
    final response = await http.post(url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token'
        },
        body: jsonEncode({"classId": classId, "studentIds": studentsId}));

    if (response.statusCode == 200) {
      return true;
    } else {
      throw Exception("Failed to add students ${response.statusCode}");
    }
  }

  Future<bool> deleteStudent(classId, studentId, token) async {
    final url = Uri.parse('$_baseURL/teacher/delete-student');
    final response = await http.delete(url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token'
        },
        body: jsonEncode({"classId": classId, "studentId": studentId}));

    if (response.statusCode == 200) {
      return true;
    } else {
      throw Exception("Failed to delete Students ${response.statusCode}");
    }
  }

  Future<List<ClassroomModel>> getAllClasses(token) async {
    final url = Uri.parse('$_baseURL/teacher/get-classes');
    final response = await http.get(url, headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token'
    });

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List classesjson = data['classes'] ?? [];

      List<ClassroomModel> classes = classesjson
          .map<ClassroomModel>((json) => ClassroomModel.fromJson(json))
          .toList();
      return classes;
    } else {
      throw Exception("Failed to load classes");
    }
  }

  Future<List<ClassroomModel>> getTeacherInClass(classId, token) async {
    final url =
        Uri.parse('$_baseURL/teacher/get-teacher-by-class?classId=$classId');
    final response = await http.get(url, headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token'
    });

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List teachersjson = data['teachers'] ?? [];

      List<ClassroomModel> teachers = teachersjson
          .map<ClassroomModel>((json) => ClassroomModel.fromJson(json))
          .toList();
      return teachers;
    } else {
      throw Exception("Failed to load teachers");
    }
  }

  Future<List<ClassroomModel>> getStudentsInClass(classId, token) async {
    final url =
        Uri.parse('$_baseURL/teacher/get-student-by-class?classId=$classId');
    final response = await http.get(url, headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token'
    });

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List studentsjson = data['students'] ?? [];

      List<ClassroomModel> students = studentsjson
          .map<ClassroomModel>((json) => ClassroomModel.fromJson(json))
          .toList();
      return students;
    } else {
      throw Exception("Failed to load students");
    }
  }

  Future<List<ClassroomModel>> getStudentsNotInClass(classId, token) async {
    final url =
        Uri.parse('$_baseURL/adminteacher/get-student-not-in-any-class');
    final response = await http.get(url, headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token'
    });

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List studentsjson = data['students'] ?? [];

      List<ClassroomModel> students = studentsjson
          .map<ClassroomModel>((json) => ClassroomModel.fromJson(json))
          .toList();
      return students;
    } else {
      throw Exception("Failed to load students");
    }
  }

  Future<void> submitAttendance({
    required String token,
    required String classId,
    required String date,
    required List<Map<String, String>> attendance,
  }) async {
    final url = Uri.parse('$_baseURL/adminteacher/take-attendance');

    final body = {
      'classId': classId,
      'date': date,
      'attendance': attendance,
    };

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to submit attendance: ${response.body}');
    }
  }
}
