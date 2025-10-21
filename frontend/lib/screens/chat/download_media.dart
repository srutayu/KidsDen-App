import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

class FileUtils {
  /// 📁 Returns the local directory path (visible in gallery for Android)
  static Future<String> getLocalPath() async {
    if (Platform.isAndroid) {
      final directory = await getExternalStorageDirectory();
      final path = '${directory!.path}/KidsDen';
      final dir = Directory(path);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return path;
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


static Future<String> downloadFile(String url, String name) async {
  final dirPath = await getLocalPath();
  final filePath = '$dirPath/$name';
  final file = File(filePath);

  // Use your preferred download method (http, dio, etc.)
  final response = await http.get(Uri.parse(url));
  await file.writeAsBytes(response.bodyBytes);

  return filePath;
}



static Future<String> getVideoThumbnail(bool exists, String url, String name) async {
  final videoPath = exists
      ? await FileUtils.getLocalFilePath(name)
      : await FileUtils.downloadFile(url, name);

  final thumbDir = await getTemporaryDirectory();
  final thumbPath = '${thumbDir.path}/$name-thumb.jpg';

  if (await File(thumbPath).exists()) return thumbPath;

  final generated = await VideoThumbnail.thumbnailFile(
    video: videoPath,
    thumbnailPath: thumbPath,
    imageFormat: ImageFormat.JPEG,
    maxWidth: 700,
    quality: 80,
  );

  return generated ?? thumbPath;
}
}