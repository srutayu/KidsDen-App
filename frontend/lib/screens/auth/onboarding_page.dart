import 'package:flutter/material.dart';
import 'package:frontend/screens/auth/login_page.dart';
import 'package:frontend/screens/auth/signup_page.dart';
import 'package:lottie/lottie.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 168, 244, 184), 
      body: Padding(
        padding: const EdgeInsets.all(40.0), 
        child: Center(
          child: SizedBox(
            width: double.infinity,
            height: double.infinity,
            child: Card(
              elevation: 10,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Hero(
                      tag: 'school-logo',
                      child: Image.asset(
                        'assets/logo.png',
                        width: 200,
                        height: 200,
                      ),
                    ),
                    Lottie.asset('assets/lotties/Educatin.json'),
                    Text(
                      "Welcome",
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                            onPressed: () {
                              Navigator.push(context, MaterialPageRoute(
                                builder: (context) {
                                  return SignUpPage();
                                },
                              ));
                            },
                            child: Text("Sign Up")),
                        FilledButton(
                            onPressed: () {
                              Navigator.push(context, MaterialPageRoute(
                                builder: (context) {
                                  return LoginPage();
                                },
                              ));
                            },
                            child: Text("Log In")),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
