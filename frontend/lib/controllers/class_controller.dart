import 'package:frontend/constants/url.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ClassController {
  static final _baseURL = URL.baseURL;

  static Future<List<String>> getClasses(token) async {
    final url = Uri.parse('$_baseURL/admin/get-classes');
    final response = await http.get(url, headers: {
      'Content-Type':'application/json',
      'Authorization': 'Bearer $token'
    });

    if(response.statusCode == 200) {
      Map<String, dynamic> jsonMap = jsonDecode(response.body);
      List<dynamic> monthsDynamic = jsonMap["classes"];
      List<String> months = List<String>.from(monthsDynamic);
      return months;
    } else {
      throw Exception("Error fetching classes, StatusCode: ${response.statusCode}");
    }
  }
}