import 'package:flutter/material.dart';
import 'package:frontend/controllers/auth_controller.dart';
import 'package:frontend/screens/widgets/toast_message.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _tokenController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _otpRequested = false;
  bool _otpVerified = false;
  bool _loading = false;
   bool get isMatch => _newPasswordController.text.isNotEmpty && _confirmController.text.isNotEmpty&&
      _newPasswordController.text == _confirmController.text;
      
    bool get isLengthValid => _newPasswordController.text.length >= 6;

  // String _message = '';

  void _showMessage(String msg) {
    showToast(msg);
  }

  @override
  void initState() {
    super.initState();
    _newPasswordController.addListener(_onPasswordChanged);
    _confirmController.addListener(_onPasswordChanged);
  }

  void _onPasswordChanged() {
  setState(() {}); // triggers UI rebuild to refresh button state
}

Future<void> _requestOtp() async {
  final token = _tokenController.text.trim();
  if (token.isEmpty) {
    _showMessage('Enter registered email');
    return;
  }
  setState(() => _loading = true);

  final result = await AuthController.requestOtp(token);

  if (mounted) {
    _showMessage(result['message']);
    if (result['success']) {
      setState(() => _otpRequested = true);
    }
  }
  setState(() => _loading = false);
}

Future<void> _verifyOtp() async {
  final identifier = _tokenController.text.trim(); // can be email or phone
  final otp = _otpController.text.trim();

  if (identifier.isEmpty || otp.isEmpty) {
    _showMessage('Enter registered email/phone and OTP');
    return;
  }

  setState(() => _loading = true);

  final result = await AuthController.verifyOtp(identifier, otp);

  if (mounted) {
    _showMessage(result['message']);
    if (result['success']) {
      setState(() => _otpVerified = true);
    }
  }

    setState(() => _loading = false);
  }

  Future<void> _changePassword() async {
    final identifier = _tokenController.text.trim(); // can be email or phone
    final newPass = _newPasswordController.text.trim();
    final conf = _confirmController.text.trim();

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

    final result = await AuthController.changePassword(identifier, newPass);
    if (mounted) {
      _showMessage(result['message']);
      if (result['success']) {
        Navigator.pop(context);
      }
    }

    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _tokenController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Colors.grey),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Change Password')),
      body: AbsorbPointer(
        absorbing: _loading,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1️⃣ Email / Phone
              _buildSectionTitle(context, 'Step 1: Enter registered Email / Phone'),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _tokenController,
                label: 'Email or phone number',
                enabled: !_otpRequested,
                keyboardType: TextInputType.emailAddress,
                border: inputBorder,
              ),
              const SizedBox(height: 8),
              _buildActionButton(
                label: 'Request OTP',
                onPressed: _otpRequested ? null : _requestOtp,
                active: !_otpRequested,
              ),

              const Divider(height: 40),

              // 2️⃣ OTP Verification
              _buildSectionTitle(context, 'Step 2: Verify OTP'),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _otpController,
                label: 'Enter OTP',
                enabled: _otpRequested && !_otpVerified,
                keyboardType: TextInputType.number,
                border: inputBorder,
              ),
              const SizedBox(height: 8),
              _buildActionButton(
                label: 'Verify OTP',
                onPressed: _otpRequested && !_otpVerified ? _verifyOtp : null,
                active: _otpRequested && !_otpVerified,
              ),

              const Divider(height: 40),

              // 3️⃣ Change Password
              _buildSectionTitle(context, 'Step 3: Set New Password'),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _newPasswordController,
                label: 'New password',
                obscureText: true,
                enabled: _otpVerified,
                border: inputBorder,
              ),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _confirmController,
                label: 'Confirm password',
                obscureText: true,
                enabled: _otpVerified,
                border: inputBorder,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    isLengthValid ? Icons.check_circle : Icons.cancel,
                    color: isLengthValid ? Colors.green : Colors.red,
                  ),
                  SizedBox(width: 8),
                  Text("At least 6 characters"),
                ],
              ),
              SizedBox(
                height: 10,
              ),
              Row(
                children: [
                  Icon(
                    isMatch ? Icons.check_circle : Icons.cancel,
                    color: isMatch ? Colors.green : Colors.red,
                  ),
                  SizedBox(width: 8),
                  Text("Passwords match"),
                ],
              ),
              SizedBox(height: 20,),
              _buildActionButton(
                label: 'Change Password',
                onPressed: _otpVerified ? _changePassword : null,
                active: _otpVerified && isLengthValid && isMatch,
              ),

              const SizedBox(height: 24),
              if (_loading) const Center(child: CircularProgressIndicator()),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- UI Helper Widgets ----------

 Widget _buildSectionTitle(BuildContext context, String title) {
  final isDarkMode = Theme.of(context).brightness == Brightness.dark;

  return Text(
    title,
    style: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: isDarkMode ? Colors.white : Colors.black, // 🌗 auto-switch
    ),
  );
}


 Widget _buildTextField({
  required TextEditingController controller,
  required String label,
  bool enabled = true,
  bool obscureText = false,
  TextInputType? keyboardType,
  required OutlineInputBorder border,
}) {
  return TextField(
    controller: controller,
    enabled: enabled,
    obscureText: obscureText,
    keyboardType: keyboardType,
    style: const TextStyle(color: Colors.black), // 🖤 Text always black
    decoration: InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: enabled ? Colors.black87 : Colors.grey, // subtle grey label when disabled
      ),
      filled: true, // ✅ Always filled
      fillColor: Colors.white, // ✅ Always white background
      border: border,
      enabledBorder: border.copyWith(
        borderSide: const BorderSide(color: Colors.grey),
      ),
      focusedBorder: border.copyWith(
        borderSide: const BorderSide(color: Colors.blueAccent, width: 2),
      ),
      disabledBorder: border.copyWith(
        borderSide: const BorderSide(color: Colors.grey),
      ),
    ),
  );
}


Widget _buildActionButton({
    required String label,
    required VoidCallback? onPressed,
    bool active = true,
  }) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: active ? Colors.blueAccent : Colors.grey.shade400,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        foregroundColor: active
            ? Colors.black
            : Colors.grey.shade200, // 🖤 Text color control
        elevation: active ? 3 : 0, // subtle visual cue
      ),
      onPressed: onPressed,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: active
              ? Colors.black
              : Colors.grey.shade200, // 🖤 Always black when active
        ),
      ),
    );
  }
}
