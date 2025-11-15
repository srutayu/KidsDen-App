
import 'package:flutter/widgets.dart';
import 'package:frontend/constants/url.dart';
import 'package:flutter/foundation.dart';
import 'package:frontend/models/login_response.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';


class AuthController {
  static final _baseURL = URL.baseURL;

  static Future<bool>register(String name, String? email, String password, String role, String? phone) async {
    if (phone == null && email == null){
      return false;
    }
    final url = Uri.parse('$_baseURL/auth/register');
    final response = await http.post(url,
      headers: {'Content-Type':'application/json'},
      body: jsonEncode({
        "name":name, "email":email,"password":password, "role":role, "phone": phone
      })
    );
    // Map<String, dynamic> jsonMap = json.decode(response.body);

    if(response.statusCode == 201){
      return true;
    } else {
      throw Exception(
        response.body.isNotEmpty ? response.body : "Registration failed",
      );
    }
  }

 static Future<LoginResponse?> login(String id, String password) async {
  final url = Uri.parse('$_baseURL/auth/login');

  // Basic email regex
  final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  // Build request body dynamically
  final Map<String, dynamic> body = {
    "password": password,
  };

  if (emailRegex.hasMatch(id)) {
    // 📧 It's an email
    body["email"] = id.trim();
  } else {
    // 📱 It's a phone number
    String phone = id.trim();
    if (!phone.startsWith('91') && phone.length == 10) {
      phone = '91$phone'; // normalize Indian phone
    }
    body["phone"] = phone;
  }

  final response = await http.post(
    url,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode(body),
  );

  if (response.statusCode == 200) {
    final Map<String, dynamic> jsonMap = json.decode(response.body);
    if (jsonMap.containsKey('token') && jsonMap.containsKey('user')) {
      return LoginResponse.fromJson(jsonMap);
    } else if (jsonMap.containsKey('message')) {
      debugPrint('Login error: ${jsonMap['message']}');
      return null;
    }
  } else if (response.statusCode == 401) {
    final Map<String, dynamic> jsonMap = json.decode(response.body);
    final errorMessage = jsonMap['message'] ?? 'Login failed';
    throw Exception(errorMessage);
  } else {
    throw Exception('Unexpected error: ${response.statusCode}');
  }

  return null;
}


  static Future<bool>logout(String token) async {
    final url = Uri.parse('$_baseURL/auth/logout');
    final response = await http.post(url,
    headers: {
      'Content-Type':'application/json',
      'Authorization': 'Bearer $token'
    });
    // print(token);
    Map<String, dynamic> jsonMap = json.decode(response.body);
    if(response.statusCode == 200 || response.statusCode == 400){
      return true;
    } else {
      print("Logout Error: ${jsonMap['message']}");
      return false;
    }
  }
  
 static Future<bool> checkIfApproved(String id) async {
  // Simple email regex
  final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  // Decide which query param to send
  final isEmail = emailRegex.hasMatch(id.trim());
  final param = isEmail ? 'email' : 'phone';
  String value = id.trim();

  // Normalize phone if needed
  if (!isEmail && !value.startsWith('91') && value.length == 10) {
    value = '91$value';
  }

  final url = Uri.parse('$_baseURL/auth/check-approval?$param=$value');

  final response = await http.get(
    url,
    headers: {'Content-Type': 'application/json'},
  );

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    return data['isApproved'] as bool;
  } else {
    String errorMessage = "Failed to load approval status";
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded.containsKey('message')) {
        errorMessage = decoded['message'];
      }
    } catch (_) {}
    throw Exception(errorMessage);
  }
}


  static Future<String> getRole(String token) async {
    final url = Uri.parse('$_baseURL/get-role');

    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token', 
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final role = (data['role']);
      return role;
    }
    else {
      throw Exception("Failed to fetch login date");
    }
  }

  static Future<String> getNamefromID(String token, String id) async {
    final url = Uri.parse('${URL.chatURL}/classes/get-user-name?userId=$id');

    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token', 
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final name = (data['name']);
      return name;
    }
    else {
      throw Exception("Failed to fetch Name from $id");
    }
  }

  static Future<Map<String, dynamic>> requestOtp(String identifier) async {
    final url = Uri.parse('$_baseURL/auth/password/request-otp');

    try {
      // Simple checks to detect if it's an email or phone
      final isEmail = identifier.contains('@');
      final isPhone = RegExp(r'^[0-9]{10}$').hasMatch(identifier);

      // Choose the correct field
      final body = isEmail
          ? {'email': identifier}
          : isPhone
              ? {'phone': identifier}
              : null;

      if (body == null) {
        return {
          'success': false,
          'message': 'Invalid email or phone number format',
        };
      }

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'] ?? 'OTP sent successfully',
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to request OTP',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> verifyOtp(
      String identifier, String otp) async {
    final url = Uri.parse('$_baseURL/auth/password/verify-otp');

    try {
      final isEmail = identifier.contains('@');
      final isPhone = RegExp(r'^[0-9]{10}$').hasMatch(identifier);

      final body = isEmail
          ? {'email': identifier, 'otp': otp}
          : isPhone
              ? {'phone': identifier, 'otp': otp}
              : null;

      if (body == null) {
        return {
          'success': false,
          'message': 'Invalid email or phone number format',
        };
      }

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'] ?? 'OTP verified successfully',
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'OTP verification failed',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: $e',
      };
    }
  }

   static Future<Map<String, dynamic>> changePassword(String identifier, String newPassword) async {
    final url = Uri.parse('$_baseURL/auth/password/change');

    try {
      final isEmail = identifier.contains('@');
      final isPhone = RegExp(r'^[0-9]{10}$').hasMatch(identifier);

      final body = isEmail
          ? {'email': identifier, 'newPassword': newPassword}
          : isPhone
              ? {'phone': identifier, 'newPassword': newPassword}
              : null;

      if (body == null) {
        return {
          'success': false,
          'message': 'Invalid email or phone number format',
        };
      }

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'] ?? 'Password changed successfully',
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to change password',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: $e',
      };
    }
  }
}
