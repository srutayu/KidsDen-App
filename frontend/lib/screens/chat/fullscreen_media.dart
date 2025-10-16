
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

class FullScreenMedia extends StatefulWidget {
  final int initialIndex;
  final List<Map> mediaList;

  FullScreenMedia({required this.initialIndex, required this.mediaList});

  @override
  _FullScreenMediaState createState() => _FullScreenMediaState();
}

class _FullScreenMediaState extends State<FullScreenMedia> {
  late PageController _pageController;
  late int _currentIndex;
  static final _platform = MethodChannel('kidsden/app_info');

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  Future<int?> _getAndroidSdkInt() async {
    try {
      final val = await _platform.invokeMethod<int>('getSdkInt');
      return val;
    } catch (e) {
      return null;
    }
  }

  /// Ensure appropriate storage/media permission for downloading the given item.
  /// Returns true if permission is granted or not needed, false if denied.
  Future<bool> _ensureStoragePermission(Map item) async {
    if (!Platform.isAndroid) return true;

    final sdkInt = (await _getAndroidSdkInt()) ?? 0;
    try {
      if (sdkInt >= 33) {
        final mime = item['mime'] as String? ?? '';
        Permission perm = mime.startsWith('image/') ? Permission.photos : mime.startsWith('video/') ? Permission.videos : Permission.storage;
        final status = await perm.status;
        if (!status.isGranted) {
          final res = await perm.request();
          if (!res.isGranted) {
            if (res.isPermanentlyDenied) await openAppSettings();
            return false;
          }
        }
      } else if (sdkInt >= 30) {
        final manageStatus = await Permission.manageExternalStorage.status;
        if (!manageStatus.isGranted) {
          final res = await Permission.manageExternalStorage.request();
          if (!res.isGranted) {
            if (res.isPermanentlyDenied) await openAppSettings();
            return false;
          }
        }
      } else {
        final status = await Permission.storage.status;
        if (!status.isGranted) {
          final res = await Permission.storage.request();
          if (!res.isGranted) {
            if (res.isPermanentlyDenied) await openAppSettings();
            return false;
          }
        }
      }
    } catch (e) {
      print('Error ensuring storage permission: $e');
      return true;
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.mediaList[_currentIndex]['name'] ?? ''),
        actions: [
          IconButton(
            icon: Icon(Icons.download),
            tooltip: 'Download',
            onPressed: () async {
              await _saveCurrentMedia();
            },
          )
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.mediaList.length,
        onPageChanged: (idx) => setState(() => _currentIndex = idx),
        itemBuilder: (ctx, idx) {
          final item = widget.mediaList[idx];
          final mime = item['mime'] as String? ?? '';
          final url = item['url'] as String? ?? '';

          if (mime.startsWith('image/')) {
            return InteractiveViewer(
              child: Center(child: Image.network(url, fit: BoxFit.contain)),
            );
          }

          // For videos and pdfs, we'll show a placeholder with open action
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(mime.startsWith('video/') ? Icons.videocam : Icons.insert_drive_file, size: 80),
                SizedBox(height: 12),
                Text(item['name'] ?? ''),
                SizedBox(height: 12),
                ElevatedButton.icon(
                  icon: Icon(Icons.open_in_new),
                  label: Text('Open'),
                  onPressed: () async {
                    final uri = Uri.parse(url);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                )
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _saveCurrentMedia() async {
    final item = widget.mediaList[_currentIndex];
    final url = item['url'] as String? ?? '';
    final name = item['name'] as String? ?? 'downloaded_file';

    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No URL to download')));
      return;
    }

    try {
      // Ensure storage permission is granted before attempting download
      final ok = await _ensureStoragePermission(item);
      if (!ok) return;

      final resp = await http.get(Uri.parse(url));
      if (resp.statusCode != 200) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to download: ${resp.statusCode}')));
        return;
      }

      final bytes = resp.bodyBytes;

      Directory baseDir;
      if (Platform.isAndroid) {
        // App-specific external directory is best for compatibility
        baseDir = (await getExternalStorageDirectory())!;
      } else {
        baseDir = await getApplicationDocumentsDirectory();
      }

      final saveDir = Directory('${baseDir.path}/KidsDen');
      if (!await saveDir.exists()) await saveDir.create(recursive: true);

      // sanitize name
      final safeName = name.replaceAll(RegExp(r"[^0-9A-Za-z. _-]"), '_');
      final file = File('${saveDir.path}/$safeName');
      await file.writeAsBytes(bytes);

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved to ${file.path}')));
    } catch (e) {
      print('Error saving file: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving file')));
    }
  }
}