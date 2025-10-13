import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void showLogoutConfirmation(BuildContext context) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Confirm Exit'),
      content: const Text('Are you sure you want to quit the app?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('No'),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(ctx).pop();
            if (Platform.isAndroid) {
              SystemNavigator.pop();
            } else {
              exit(0);
            }
          },
          child: const Text('Yes'),
        ),
      ],
    ),
  );
}
