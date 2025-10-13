import 'package:flutter/material.dart';

class GreetingWidget extends StatelessWidget {
  final String username;

  const GreetingWidget({Key? key, required this.username}) : super(key: key);

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return "Good morning";
    } else if (hour < 17) {
      return "Good afternoon";
    } else {
      return "Good evening";
    }
  }

  String _getBackgroundImage() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'assets/images/greetingMorning.png';   // morning
    } else if (hour < 17) {
      return 'assets/images/greetingMorning.png'; // afternoon
    } else {
      return 'assets/images/greetingEvening.png';   // evening
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return SizedBox(
      width: double.infinity,
      height: screenHeight * 0.15,
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Card(
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias, // makes image follow rounded corners
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                _getBackgroundImage(),
                height: 40,
                fit: BoxFit.cover,
              ),

              // Optional overlay for readability
              Container(
                color: Colors.black.withOpacity(0.2),
              ),

              // 📝 Greeting text
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text.rich(
                    TextSpan(
                      text: "${_getGreeting()}, \n",
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      children: [
                        TextSpan(
                          text: "$username 👋",
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color.fromARGB(255, 255, 253, 105),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
