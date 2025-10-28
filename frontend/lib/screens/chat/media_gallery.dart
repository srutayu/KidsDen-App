import 'dart:io';

import 'package:flutter/material.dart';
import 'package:frontend/screens/chat/download_media.dart';
import 'package:frontend/screens/chat/fullscreen_media.dart';
import 'package:frontend/screens/chat/image_viewer.dart';
import 'package:frontend/screens/chat/pdf_viewer.dart';
import 'package:frontend/screens/chat/videoPlayer.dart';

class MediaGalleryScreen extends StatelessWidget {
  final List<Map> mediaList;

  const MediaGalleryScreen({super.key, required this.mediaList});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Shared media')),
      body: mediaList.isEmpty
          ? Center(child: Text('No media shared yet'))
          : GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
              ),
              itemCount: mediaList.length,
              itemBuilder: (ctx, i) {
                final item = mediaList[i];
                final mime = item['mime'] as String? ?? '';
                final url = item['url'] as String? ?? '';
                

                return GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => FullScreenMedia(
                          initialIndex: i,
                          mediaList: mediaList,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    color: Colors.black12,
                    child: FutureBuilder<String>(
                      future: FileUtils.getLocalPath(), // async call here
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          // While waiting for local path
                          return const Center(
                              child: CircularProgressIndicator());
                        }

                        final localDir = snapshot.data!;
                        final localFileName = item['name'] as String?;
                        final localPath = localFileName != null
                            ? '$localDir/$localFileName'
                            : null;

                        final file =
                            localPath != null && File(localPath).existsSync()
                                ? File(localPath)
                                : null;

                        // 🖼️ IMAGES
                       if (mime.startsWith('image/')) {
                          if (file != null) {
                            return GestureDetector(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        LocalImageViewer(filePath: file.path, senderID: item['sender'],),
                                  ),
                                );
                              },
                              child: Image.file(
                                file,
                                fit: BoxFit.cover,
                              ),
                            );
                          } else {
                            return GestureDetector(
                              onTap: () async {
                                // optionally download first if not local
                                final path = await FileUtils.downloadFile(
                                    url, item['name']!);
                                if (context.mounted) {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          LocalImageViewer(filePath: path, senderID: item['sender'],),
                                    ),
                                  );
                                }
                              },
                              child: Image.network(
                                url,
                                fit: BoxFit.cover,
                              ),
                            );
                          }
                        } else if (mime.startsWith('video/')) {
                          return FutureBuilder<String>(
                            future: FileUtils.getVideoThumbnail(
                                file != null, url, item['name']!),
                            builder: (context, snapshot) {
                              final hasThumbnail =
                                  snapshot.hasData && snapshot.data!.isNotEmpty;

                              return GestureDetector(
                                onTap: () async {
                                  final path = file != null
                                      ? file.path
                                      : await FileUtils.downloadFile(
                                          url, item['name']!);
                                  if (context.mounted) {
                                    Navigator.of(context)
                                        .push(MaterialPageRoute(
                                      builder: (_) => VideoPlayerScreen(
                                          videoUrl: path,
                                          isLocal: true,
                                          senderID: item['sender']),
                                    ));
                                  }
                                },
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    // 🎞️ Background: Either video thumbnail or fallback container
                                    Positioned.fill(
              child: hasThumbnail
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(snapshot.data!),
                        fit: BoxFit.cover,
                      ),
                    )
                  : Container(
                      color: Colors.black26,
                      child: const Center(
                        child: Icon(Icons.videocam,
                            color: Colors.white70, size: 48),
                      ),
                    ),
            ),

            // ▶️ Play overlay
            const Icon(
              Icons.play_circle_outline,
              color: Colors.white,
              size: 48,
            ),

            // Optional loading spinner while generating thumbnail
            if (!snapshot.hasData)
              const Positioned.fill(
                child: Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
          ],
        ),
      );
    },
  );
}


else if (mime.startsWith('application/pdf')) {
  // 📄 PDF SECTION
  return GestureDetector(
    onTap: () async {
      final path = file != null
          ? file.path
          : await FileUtils.downloadFile(url, item['name']!);
      if (context.mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PdfViewerScreen(filePath: path),
          ),
        );
      }
    },
    child: Container(
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.picture_as_pdf, color: Colors.red, size: 40),
            const SizedBox(height: 6),
            Text(
              item['name'] ?? '',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black87,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}


                        // 🎬 VIDEOS / 📄 PDFs / OTHERS
                        return Stack(
                          children: [
                            Positioned.fill(
                                child: Container(color: Colors.black12)),
                            Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    mime.startsWith('abc/')
                                        ? Icons.videocam
                                        : Icons.insert_drive_file,
                                    size: 36,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    item['name'] ?? '',
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }
}
