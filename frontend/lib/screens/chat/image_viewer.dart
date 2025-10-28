import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:frontend/constants/url.dart';
import 'package:frontend/provider/auth_provider.dart';
import 'package:photo_view/photo_view.dart';
import 'package:http/http.dart' as http;
import 'dart:io';

import 'package:provider/provider.dart';

class LocalImageViewer extends StatefulWidget {
  final String filePath;
  final String senderID;

  const LocalImageViewer({super.key, required this.filePath, required this.senderID});

  @override
  State<LocalImageViewer> createState() => _LocalImageViewerState();
}

class _LocalImageViewerState extends State<LocalImageViewer> {
  late String token;

  void initState() {
    super.initState();
    token = Provider.of<AuthProvider>(context, listen: false).token!;
    fetchUserName(widget.senderID, token);
  }
  String senderName='';

  Future<void> fetchUserName(String userId, String authToken) async {
  if (userId.isEmpty) return;
  try {
    final uri = Uri.parse('${URL.chatURL}/classes/get-user-name?userId=$userId');
    final response = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $authToken',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        senderName= data['name'];
      });
    } else {
      return;
    }
  } catch (e) {
    return;
  }
}

 @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : Colors.white,
      appBar: AppBar(
        backgroundColor: isDarkMode ? Colors.black : Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(
          color: isDarkMode ? Colors.white : Colors.black, // Back arrow color
        ),
        title: Text(
          senderName,
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: PhotoView(
          imageProvider: FileImage(File(widget.filePath)),
          backgroundDecoration: BoxDecoration(
            color: isDarkMode ? Colors.black : Colors.white,
          ),
          loadingBuilder: (context, event) => const Center(
            child: CircularProgressIndicator(),
          ),
          errorBuilder: (context, error, stackTrace) => const Center(
            child: Icon(Icons.error_outline, color: Colors.redAccent, size: 40),
          ),
          // 👇 Zoom control
          minScale:
              PhotoViewComputedScale.contained * 1.0, // fit-to-screen baseline
          maxScale: PhotoViewComputedScale.covered * 3.0, // up to 3x zoom
        ),
      ),
    );
  }
}

