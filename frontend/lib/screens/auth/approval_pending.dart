// import 'package:flutter/material.dart';

// class ApprovalPending extends StatelessWidget {
//   const ApprovalPending({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: Center(
//         child: Text("Account Created Successfully, Approval Pending. Please Contact Admin!"),
//       ),
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:frontend/screens/auth/onboarding_page.dart';
import 'package:lottie/lottie.dart'; // Add in pubspec.yaml: lottie: ^2.7.0

class ApprovalPending extends StatelessWidget {
  const ApprovalPending({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF121212)
          : const Color(0xFFF7F9FC),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ✨ Lottie animation
                Lottie.asset(
                  'assets/lotties/pending.json',
                  height: 200,
                  repeat: true,
                ),

                const SizedBox(height: 30),

                // ✅ Title
                Text(
                  "Account Created!",
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 10),

                // 🕒 Subtitle
                Text(
                  "Your account has been created successfully.\nApproval is pending — please contact your administrator.",
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark ? Colors.white70 : Colors.black54,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 40),

                // 📞 Contact Admin Button
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (context) => OnboardingPage()),
                    );
                  },
                  icon: const Icon(Icons.home),
                  label: const Text("Go to Homepage"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        isDark ? Colors.blueGrey.shade700 : Colors.blueAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
