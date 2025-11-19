import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:frontend/controllers/auth_controller.dart';
import 'package:frontend/screens/auth/approval_pending.dart';
import 'package:frontend/screens/auth/login_page.dart';
import 'package:frontend/screens/widgets/toast_message.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:intl_phone_field/phone_number.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  bool _isLoading = false;
  bool _obscureText = true;
  final TextEditingController _email = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  String completeNumber= '';
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _name = TextEditingController();

  @override
  void initState() {
    super.initState();
    _password.addListener(() => setState(() {}));
    _confirmPasswordController.addListener(() => setState(() {}));
    _email.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _password.dispose();
    _confirmPasswordController.dispose();
    _email.dispose();
    super.dispose();
  }

  bool get isLengthValid => _password.text.length >= 6;
  bool get isMatch => _password.text.isNotEmpty && _confirmPasswordController.text.isNotEmpty&&
      _password.text == _confirmPasswordController.text;
  final RegExp emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
  bool get isEmailValid {
    final text = _email.text.trim();
    if (text.isEmpty) return true; // ✅ allow empty (optional field)
    return emailRegex.hasMatch(text);
  }
  bool _isNameValid = false;
    bool _isPhoneValid = false;
  bool _validateName(String name) {
  final nameRegex = RegExp(r'^[A-Za-z\s]+$');
  return nameRegex.hasMatch(name.trim());
}

void _onNameChanged(String name) {
  setState(() {
    _isNameValid = _validateName(name);
  });
}


  bool isTeacher = true; // default switch = Student
  String _selectedRole = "teacher"; // same as default

  bool isValidIndianPhoneNumber(String input) {
    final trimmed = input.trim();
    if (input.isEmpty) return true;
    final regex = RegExp(r'^[0-9]{10}$');
    return regex.hasMatch(trimmed);
  }

  bool isValidPhoneNumber(PhoneNumber phone) {
    final number = phone.number;
    final countryCode = phone.countryCode;

    // Allow only digits
    final onlyDigits = RegExp(r'^[0-9]+$');
    if (!onlyDigits.hasMatch(number)) return false;

    // Country-specific rule
    if (countryCode == '+91') {
      return number.length == 10; // India: 10 digits
    } else {
      return number.length >= 6 && number.length <= 15;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Center(
            child: Card(
              elevation: 10,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Hero(
                      tag: 'app-logo',
                      child: Image.asset(
                        'assets/logo.png',
                        width: 150,
                        height: 150,
                                  ),
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text("Student"),
                                    Switch(
                                      value: isTeacher,
                                      activeThumbColor: Colors.teal,
                                      onChanged: (value) {
                                        setState(() {
                                          isTeacher = value;
                                          _selectedRole = isTeacher
                                              ? "teacher"
                                              : "student"; // update your role
                                        });
                                      },
                                    ),
                                    Text("Teacher"),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                TextField(
                                  controller: _name,
                                  onChanged: _onNameChanged,
                                  decoration: InputDecoration(
                                    labelText: 'Name',
                                    fillColor: Colors.grey[200],
                                    prefixIcon: const Icon(Icons.person),
                                    suffixIcon: _name.text.isEmpty
                                        ? null
                                        : (_isNameValid
                                            ? const Icon(Icons.check_circle,
                                                color: Colors.green)
                                            : const Icon(Icons.cancel,
                                                color: Colors.red)),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(20),
                                      borderSide:
                                          const BorderSide(color: Colors.grey),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(20),
                                      borderSide: const BorderSide(
                                          color: Colors.teal, width: 2),
                                    ),
                                  ),
                                ),
                                SizedBox(height: 20),
                                IntlPhoneField(
                                  controller: _phone,
                                  initialCountryCode: 'IN',
                                  decoration: InputDecoration(
                                    labelText: 'Phone Number',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    suffixIcon: _phone.text.isEmpty
                                        ? null
                                        : (_isPhoneValid
                                            ? const Icon(Icons.check_circle,
                                                color: Colors.green)
                                            : const Icon(Icons.cancel,
                                                color: Colors.red)),
                                  ),
                                  onChanged: (phone) {
                                    setState(() {
                                      completeNumber = phone
                                          .completeNumber; // e.g. +919876543210
                                      _isPhoneValid = isValidPhoneNumber(phone);
                                    });
                                  },
                                  onCountryChanged: (country) {
                                    // Re-validate if user switches country
                                    setState(() {
                                      _isPhoneValid = isValidPhoneNumber(
                                        PhoneNumber(
                                          countryISOCode: country.code,
                                          countryCode: '+${country.dialCode}',
                                          number: _phone.text,
                                        ),
                                      );
                                    });
                                  },
                                ),
                                TextField(
                                  controller: _email,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: InputDecoration(
                                    labelText: 'Email ID',
                                    fillColor: Colors.grey[200],
                                    prefixIcon: Icon(Icons.email),
                                    suffixIcon: _email.text.isEmpty
                                        ? null
                                        : Icon(
                                            isEmailValid
                                                ? Icons.check_circle
                                                : Icons.cancel,
                                            color: isEmailValid
                                                ? Colors.green
                                                : Colors.red,
                                          ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(20),
                                      borderSide:
                                          BorderSide(color: Colors.grey),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(20),
                                      borderSide: BorderSide(
                                          color: Colors.teal, width: 2),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                TextField(
                                  controller: _password,
                                  obscureText: _obscureText,
                                  decoration: InputDecoration(
                                    labelText: 'Set a Password',
                                    fillColor: Colors.grey[200],
                                    prefixIcon: Icon(Icons.password),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscureText
                                            ? Icons.visibility
                                            : Icons.visibility_off,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _obscureText = !_obscureText;
                                        });
                                      },
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(20),
                                      borderSide:
                                          BorderSide(color: Colors.grey),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(20),
                                      borderSide: BorderSide(
                                          color: Colors.teal, width: 2),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                TextField(
                                  controller: _confirmPasswordController,
                                  obscureText: _obscureText,
                                  decoration: InputDecoration(
                                    labelText: 'Confirm Password',
                                    fillColor: Colors.grey[200],
                                    prefixIcon: Icon(Icons.lock_outline),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscureText
                                            ? Icons.visibility
                                            : Icons.visibility_off,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _obscureText = !_obscureText;
                                        });
                                      },
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(20),
                                      borderSide:
                                          BorderSide(color: Colors.grey),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(20),
                                      borderSide: BorderSide(
                                          color: Colors.teal, width: 2),
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  height: 20,
                                ),
                                Row(
                                  children: [
                                    Icon(
                                      isLengthValid
                                          ? Icons.check_circle
                                          : Icons.cancel,
                                      color: isLengthValid
                                          ? Colors.green
                                          : Colors.red,
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
                                      isMatch
                                          ? Icons.check_circle
                                          : Icons.cancel,
                                      color:
                                          isMatch ? Colors.green : Colors.red,
                                    ),
                                    SizedBox(width: 8),
                                    Text("Passwords match"),
                                  ],
                                ),
                                SizedBox(
                                  height: 10,
                                ),
                          SizedBox(
                                  width: double.infinity,
                                  child: FilledButton(
                                    onPressed: _isLoading
                                        ? null
                                        : () async {
                                            final email = _email.text.trim().isEmpty ? null : _email.text.trim();
                                            final phone = _phone.text.trim().isEmpty ? null : _phone.text.trim();
                                           
                                            if (_name.text.isEmpty) {
                                              showToast('Name Required');
                                              return;
                                            } else if (!_isNameValid) {
                                              showToast(
                                                  
                                                      'Name cannot contain special characters or numbers');
                                              return;
                                            } else if (!isValidIndianPhoneNumber(
                                                _phone.text)) {
                                              showToast(
                                                  'Invalid phone number');
                                              return;
                                            } else if (!isEmailValid) {
                                              showToast(
                                                   'Invalid Email');
                                              return;
                                            } else if (email == null &&
                                                phone == null) {
                                              showToast(
                                                  
                                                      'Either Phone or E-Mail required');
                                                      return;
                                            } else if (_password.text.isEmpty) {
                                              showToast(
                                                   'Password Required');
                                              return;
                                            } else if (!isMatch ||
                                                !isLengthValid) {
                                              showToast(
                                                  
                                                      'Password Criteria not met');
                                              return;
                                            }
                                            

                                            setState(() => _isLoading = true);
                                            

                                            try {
                                              await AuthController.register(
                                                _name.text,
                                                email,
                                                _password.text,
                                                _selectedRole,
                                                phone
                                              );

                                              if (!mounted) return;

                                              Navigator.pushReplacement(
                                                context,
                                                MaterialPageRoute(
                                                    builder: (context) =>
                                                        ApprovalPending()),
                                              );
                                            } catch (error) {
                                              String errorMessage =
                                                  "Something went wrong";

                                              try {
                                                final Map<String, dynamic>
                                                    decoded = jsonDecode(error
                                                        .toString()
                                                        .replaceFirst(
                                                            "Exception: ", ""));
                                                if (decoded
                                                    .containsKey('message')) {
                                                  errorMessage =
                                                      decoded['message'];
                                                }
                                              } catch (e) {
                                                // If decoding fails, fallback to default clean string
                                                errorMessage = error
                                                    .toString()
                                                    .replaceFirst(
                                                        "Exception: ", "");
                                              }

                                              showToast(
                                                  errorMessage);
                                            } finally {
                                              if (mounted) {
                                                setState(
                                                    () => _isLoading = false);
                                              }
                                            }
                                          },
                                    child: _isLoading
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Text("Register"),
                                  ),
                                ),
                                SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text("Already have an account? "),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.pushReplacement(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => LoginPage(),
                                          ),
                                        );
                                      },
                                      style: TextButton.styleFrom(
                                          padding: EdgeInsets.zero),
                                      child: const Text(
                                        "Log In",
                                        style: TextStyle(
                                          color: Colors.blue,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              ],
                            )))))));
  }
}
