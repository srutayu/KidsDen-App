import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

class FileUtils {
  static Future<String> getLocalPath() async {
  if (Platform.isAndroid) {
    // Use a public directory visible in gallery
    final publicPath = '/storage/emulated/0/Pictures/KidsDen';
    final directory = Directory(publicPath);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return publicPath;
  } else {
    final dir = await getApplicationDocumentsDirectory();
    return dir.path;
  }
}

  static Future<String> getLocalFilePath(String fileName) async {
    final dirPath = await getLocalPath();
    return '$dirPath/$fileName';
  }

  static Future<bool> fileExists(String fileName) async {
    final file = File(await getLocalFilePath(fileName));
    return file.exists();
  }

  static Future<String> downloadFile(String url, String fileName) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final file = File(await getLocalFilePath(fileName));
      await file.writeAsBytes(response.bodyBytes);
      return file.path;
    } else {
      throw Exception('Failed to download file');
    }
  }
}
