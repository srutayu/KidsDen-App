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

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    return SizedBox(
      width: double.infinity,
      height: screenHeight *.15,
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Card(
          elevation: 8, // shadow depth
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12), 
          ),
          color: Colors.white, 
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text.rich(
              TextSpan(
                text: "${_getGreeting()}, \n ",
                style: const TextStyle(
                  fontSize: 20, 
                  fontWeight: FontWeight.bold,
                ),
                children: [
                  TextSpan(
                    text: "$username 👋",
                    style: const TextStyle(
                      fontSize: 24, 
                      fontWeight: FontWeight.bold,
                      color: Colors.blueAccent,
                    ),
                  ),
                ],
              )
            )
          ),
        ),
      ),
    );
  }
}
