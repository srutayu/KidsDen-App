import 'dart:convert';
import 'package:frontend/constants/url.dart';
import 'package:frontend/models/user_model.dart';
import 'package:http/http.dart' as http;

class UserDetailController{
  static final _baseURL = URL.baseURL;

 static Future<User> getUserDetails(emailId, token) async {
   final url = Uri.parse('$_baseURL/user-data?email=$emailId');
   final response = await http.get(url,
       headers: {
         'Content-Type':'application/json',
         'Authorization': 'Bearer $token'
       });

   if(response.statusCode == 200){
     final Map<String, dynamic> jsonResponse = json.decode(response.body);
     return User.fromJson(jsonResponse);
   } else {
     throw Exception('Failer to load user data. Status Code : ${response.statusCode}');
   }
 }
}