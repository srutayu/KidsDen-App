import 'dart:io';

import 'package:flutter/material.dart';
import 'package:frontend/screens/chat/fullscreen_media.dart';

class MediaGalleryScreen extends StatelessWidget {
  final List<Map> mediaList;

  MediaGalleryScreen({required this.mediaList});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Shared media')),
      body: mediaList.isEmpty
          ? Center(child: Text('No media shared yet'))
          : GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
              ),
              itemCount: mediaList.length,
              itemBuilder: (ctx, i) {
                final item = mediaList[i];
                final mime = item['mime'] as String? ?? '';
                final url = item['url'] as String? ?? '';
                print(item['name']);

                return GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => FullScreenMedia(
                          initialIndex: i, mediaList: mediaList),
                    ));
                  },
                  child: Container(
                    color: Colors.black12,
                    child: Builder(
                      builder: (context) {
                        // final localPath = item['name'] as String?;
                        final localFileName = item['name'] as String?;
                        final localDir =
                            '/storage/emulated/0/Pictures/KidsDen';
                        final localPath = localFileName != null
                            ? '$localDir/$localFileName'
                            : null;

                        final file =
                            localPath != null && File(localPath).existsSync()
                                ? File(localPath)
                                : null;

                        if (mime.startsWith('image/')) {
                          if (file != null) {
                            return Image.file(file, fit: BoxFit.cover);
                          } else {
                            return Image.network(url, fit: BoxFit.cover);
                          }
                        } else {
                          return Stack(
                            children: [
                              Positioned.fill(
                                  child: Container(color: Colors.black12)),
                              Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      mime.startsWith('video/')
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
                        }
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }
}
