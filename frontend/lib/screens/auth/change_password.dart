import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../constants/url.dart';

// Change Password screen with WhatsApp OTP flow
// Endpoints assumed:
// POST /api/auth/request-otp  { phone }
// POST /api/auth/verify-otp   { phone, otp }
// POST /api/auth/change-password { phone, newPassword }

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _otpRequested = false;
  bool _otpVerified = false;
  bool _loading = false;

  String _message = '';

  final String baseUrl = URL.baseURL; // change as needed

  void _showMessage(String msg) {
    setState(() {
      _message = msg;
    });
  }

  Future<void> _requestOtp() async {
  final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showMessage('Enter registered email');
      return;
    }
    setState(() => _loading = true);
    try {
      final res = await http.post(Uri.parse('$baseUrl/auth/password/request-otp'),
          headers: {'Content-Type': 'application/json'}, body: jsonEncode({'phone': email}));
      final body = jsonDecode(res.body);
      if (res.statusCode == 200) {
        _showMessage(body['message'] ?? 'OTP sent');
        setState(() => _otpRequested = true);
      } else {
        _showMessage(body['message'] ?? 'Failed to request OTP');
      }
    } catch (e) {
      _showMessage('Error: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _verifyOtp() async {
  final email = _emailController.text.trim();
    final otp = _otpController.text.trim();
    if (email.isEmpty || otp.isEmpty) {
      _showMessage('Enter email and OTP');
      return;
    }
    setState(() => _loading = true);
    try {
      final res = await http.post(Uri.parse('$baseUrl/auth/password/verify-otp'),
          headers: {'Content-Type': 'application/json'}, body: jsonEncode({'email': email, 'otp': otp}));
      final body = jsonDecode(res.body);
      if (res.statusCode == 200) {
        _showMessage(body['message'] ?? 'OTP verified');
        setState(() => _otpVerified = true);
      } else {
        _showMessage(body['message'] ?? 'OTP verification failed');
      }
    } catch (e) {
      _showMessage('Error: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _changePassword() async {
  final email = _emailController.text.trim();
    final newPass = _newPasswordController.text;
    final conf = _confirmController.text;
    if (!_otpVerified) {
      _showMessage('Verify OTP first');
      return;
    }
    if (newPass.isEmpty || conf.isEmpty) {
      _showMessage('Enter new password and confirm');
      return;
    }
    if (newPass != conf) {
      _showMessage('Passwords do not match');
      return;
    }
    setState(() => _loading = true);
    try {
      final res = await http.post(Uri.parse('$baseUrl/auth/password/change'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email, 'newPassword': newPass}));
      final body = jsonDecode(res.body);
      if (res.statusCode == 200) {
        _showMessage(body['message'] ?? 'Password changed successfully');
        // Optionally navigate back to login
      } else {
        _showMessage(body['message'] ?? 'Failed to change password');
      }
    } catch (e) {
      _showMessage('Error: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
  _emailController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Change Password')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Registered email'),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _loading ? null : _requestOtp,
                child: const Text('Request OTP via WhatsApp'),
              ),
              if (_otpRequested) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'OTP'),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _loading ? null : _verifyOtp,
                  child: const Text('Verify OTP'),
                ),
              ],
              if (_otpVerified) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _newPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'New password'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _confirmController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Confirm password'),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _loading ? null : _changePassword,
                  child: const Text('Change password'),
                ),
              ],
              const SizedBox(height: 16),
              if (_loading) const Center(child: CircularProgressIndicator()),
              if (_message.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(_message, style: const TextStyle(color: Colors.red)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
