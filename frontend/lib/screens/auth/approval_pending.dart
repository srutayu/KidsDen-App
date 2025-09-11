import 'package:flutter/material.dart';

class ApprovalPending extends StatelessWidget {
  const ApprovalPending({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text("Account Created Successfully, Approval Pending. Please Contact Admin!"),
      ),
    );
  }
}
