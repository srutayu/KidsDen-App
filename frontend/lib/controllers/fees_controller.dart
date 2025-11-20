import 'package:frontend/constants/url.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class FeesController {
  static final _baseURL = URL.baseURL;
  
  static Future<List<String>> getAllClasses(token) async{
    final url = Uri.parse('$_baseURL/fees/get-classes');
    final response = await http.get(url, headers: {
      'Content-Type':'application/json',
      'Authorization': 'Bearer $token'
    });
    
    if(response.statusCode == 200){
      Map<String, dynamic> jsonMap = jsonDecode(response.body);
      List<String> classes = List<String>.from(jsonMap['classes']);
      return classes;
    } else {
      throw Exception("Error fetching classes from Fees Collection, ${response.statusCode}");
    }
  }

  static Future<int> getFees(classId, token) async {
    final url = Uri.parse('$_baseURL/admin/get-fees?classId=$classId');
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

static Future<bool> updateFeesAmountByClassId(
    String classId, String amount, String token) async {

  final url = Uri.parse("$_baseURL/fees/update-fees");

  final response = await http.post(
    url,
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token'
    },
    body: jsonEncode({
      "classId": classId,
      "amount": amount
    }),
  );

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);

    if (data.containsKey("class") && data["class"]["_id"] == classId) {
      return true;
    } else {
      return false;
    }
  } else {
    print("Update fees failed: ${response.statusCode}");
    return false;
  }
}

}