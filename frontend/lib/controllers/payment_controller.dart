import 'dart:convert';

import 'package:frontend/constants/url.dart';
import 'package:http/http.dart' as http;

class GetFeesController{
  static final _baseURL = URL.baseURL;

  static Future<int> getFees(classId, token) async {
    final url = Uri.parse('$_baseURL/student/get-fees?classId=$classId');
    final response = await http.get(url,
        headers: {'Content-Type':'application/json',
              'Authorization': 'Bearer $token'},
    );

    if(response.statusCode == 200){
      Map<String, dynamic> jsonMap = jsonDecode(response.body);
      int amount = jsonMap['amount'];
      return amount;
    } else {
      throw Exception("Failed to fetch amount from class");
    }
  }


  static Future<List<int>> getYears(token) async {
    final url = Uri.parse('$_baseURL/admin/get-years');
    final response = await http.get(url , headers: {'Content-Type':'application/json',
      'Authorization': 'Bearer $token'});

    if(response.statusCode == 200) {
      Map<String, dynamic> jsonMap = jsonDecode(response.body);
      return List<int>.from(jsonMap["years"]);
    } else {
      throw Exception("Error fectching years from backend, StatusCode: ${response.statusCode}");
    }
  }

  static Future<List<String>> getMonthsByYear(token, year) async {
    final url = Uri.parse('$_baseURL/admin/get-months?year=$year');
    final response = await http.get(url, headers: {
      'Content-Type':'application/json',
      'Authorization': 'Bearer $token'
    });

    if(response.statusCode == 200) {
      Map<String, dynamic> jsonMap = jsonDecode(response.body);
      List<dynamic> monthsDynamic = jsonMap["months"];
      List<String> months = List<String>.from(monthsDynamic);
      return months;
    } else {
      throw Exception("Error fetching months by the years, StatusCode: ${response.statusCode}");
    }
  }

  static Future<int> deletePaymentRecord (token, year, month, classId) async {

    final url = Uri.parse('$_baseURL/fees/delete-fees');
    Map<String, dynamic> body = {};
    if (year != null || year != 0) body['year'] = year;
    if (month != null && month.isNotEmpty && month!= "None") body['month'] = month;
    if (classId != null && classId.isNotEmpty && classId!="None") body['classId'] = classId;

    final response = await http.delete(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );

    if(response.statusCode == 200) {
      Map<String, dynamic> jsonMap = jsonDecode(response.body);
      return jsonMap['deletedCount'];
    } else {
      throw Exception("Error deleting data, ${response.statusCode}");
    }
  }

  static Future<bool> updateCashPayment(token , month, year, studentId) async {
    final url = Uri.parse('$_baseURL/admin/offline-payment');
    Map<String, dynamic> body = {
      'month': month,
      'year': year,
      'studentId': studentId
    };

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );

    if(response.statusCode == 200) {
      Map<String, dynamic> jsonMap = jsonDecode(response.body);
      return true;
    } else  {
      throw Exception("Error updating cash payment, ${response.statusCode}");
    }
  }


}