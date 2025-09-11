import 'dart:convert';

import 'package:frontend/constants/url.dart';
import 'package:frontend/models/user_request_model.dart';
import 'package:http/http.dart' as http;

class AdminRequestController {
  static final _baseURL = URL.baseURL;

  static Future<List<UserRequest>>getAllRequests(token) async {
    final url = Uri.parse('$_baseURL/admin/pending-approvals');
    final response = await http.get(url,
        headers: {
          'Content-Type':'application/json',
          'Authorization': 'Bearer $token'
        });

    if(response.statusCode == 200){
      List<dynamic> jsonList = jsonDecode(response.body);
      List<UserRequest> requests = jsonList.map(
              (jsonItems) => UserRequest.fromJson(jsonItems)
      ).toList();
      return requests;
    } else {
      throw Exception('Failed to load user requests: ${response.statusCode}');
    }
  }

  static Future<bool>aproveSingleUser(userId, isApproved, token) async {
    final url  = Uri.parse('$_baseURL/admin/approve-user');
    final response = await http.put(url,
        headers: {
        'Content-Type':'application/json',
        'Authorization': 'Bearer $token' },
    body: jsonEncode({
      "userId": userId, "approve": isApproved })
    );

    if(response.statusCode == 200) {
      return true;
    } else {
      throw Exception('Failed to Approve the user: ${response.statusCode}');
    }
  }
  
  static Future<bool>deleteUser(userId, token) async {
    
    final url = Uri.parse('$_baseURL/admin/reject-user');
    final response = await http.delete(url,
    headers: {
      'Content-Type':'application/json',
      'Authorization': 'Bearer $token' },
      body: jsonEncode({
        "userId" : userId
      })
    );

    if(response.statusCode == 200){
      return true;
    } else {
      throw Exception('Failed to delete the User: ${response.statusCode}');
    }
  }

  static Future<bool> approveAllUser(token) async {
    final url = Uri.parse('$_baseURL/admin/approve-all-users');
    final response = await http.put(url,
        headers: {
          'Content-Type':'application/json',
          'Authorization': 'Bearer $token'
        });

    if(response.statusCode == 200){
      return true;
    } else {
      throw Exception("Failed to Approve all the users: ${response.statusCode}");
    }
  }

  static Future<bool> rejectAllUsers(token) async {
    final url = Uri.parse('$_baseURL/admin/reject-all-users');
    final response = await http.delete(url, headers: {
      'Content-Type':'application/json',
      'Authorization': 'Bearer $token'
    });

    if(response.statusCode == 200){
      return true;
    } else {
      throw Exception("Failed to Reject all the users : ${response.statusCode}");
    }
  }
}