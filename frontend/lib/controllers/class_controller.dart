import 'package:frontend/constants/url.dart';
import 'package:frontend/models/classroom_model.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ClassController {
  static final _baseURL = URL.baseURL;

  static Future<List<ClassroomModel>> getClasses(String token) async {
    final url = Uri.parse('$_baseURL/admin/get-classes');
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token'
      },
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> jsonMap = jsonDecode(response.body);

      final List<dynamic> classListDynamic = jsonMap["classes"];

      final List<ClassroomModel> classes = classListDynamic
          .map((item) => ClassroomModel.fromJson(item))
          .toList();

      return classes;
    } else {
      throw Exception(
        "Error fetching classes, StatusCode: ${response.statusCode}",
      );
    }
  }
}
