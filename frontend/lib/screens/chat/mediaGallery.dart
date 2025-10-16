import 'package:flutter/material.dart';
import 'package:frontend/screens/chat/fullScreenMedia.dart';

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

                return GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => FullScreenMedia(initialIndex: i, mediaList: mediaList),
                    ));
                  },
                  child: Container(
                    color: Colors.black12,
                    child: mime.startsWith('image/')
                        ? Image.network(url, fit: BoxFit.cover)
                        : Stack(
                            children: [
                              Positioned.fill(
                                child: Container(color: Colors.black12),
                              ),
                              Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(mime.startsWith('video/') ? Icons.videocam : Icons.insert_drive_file, size: 36),
                                    SizedBox(height: 6),
                                    Text(item['name'] ?? '', overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12)),
                                  ],
                                ),
                              )
                            ],
                          ),
                  ),
                );
              },
            ),
    );
  }
}
