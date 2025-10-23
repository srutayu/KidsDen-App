
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter/material.dart';


void showToast(String message) {
  Fluttertoast.showToast(
    msg: message,
    toastLength: Toast.LENGTH_SHORT, // or Toast.LENGTH_LONG
    gravity: ToastGravity.BOTTOM,    // position
    backgroundColor: Colors.black87,
    textColor: Colors.white,
    fontSize: 16.0,
  );
}