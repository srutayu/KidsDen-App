import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'dart:io';

class LocalImageViewer extends StatelessWidget {
  final String filePath;
  const LocalImageViewer({super.key, required this.filePath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: Colors.transparent, title: Text(filePath.split('/').last),),
      body: Center(
        child: PhotoView(
          imageProvider: FileImage(File(filePath)),
          backgroundDecoration: const BoxDecoration(color: Colors.black),
        ),
      ),
    );
  }
}
