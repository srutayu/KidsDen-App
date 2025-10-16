import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class FileUtils {
  // Returns the local path for a file
  static Future<String> getLocalPath(String filename) async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/$filename';
  }

  // Checks if file exists locally
  static Future<bool> fileExists(String filename) async {
    final path = await getLocalPath(filename);
    return File(path).exists();
  }

  // Downloads a file from URL if not exists locally
  static Future<String> downloadFile(String url, String filename) async {
    final path = await getLocalPath(filename);
    final file = File(path);

    if (!await file.exists()) {
      final resp = await http.get(Uri.parse(url));
      if (resp.statusCode == 200) {
        await file.writeAsBytes(resp.bodyBytes);
      } else {
        throw Exception('Failed to download file: ${resp.statusCode}');
      }
    }

    return path;
  }
}
