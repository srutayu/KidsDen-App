import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frontend/constants/url.dart';
import 'package:frontend/provider/user_data_provider.dart';
import 'package:frontend/screens/chat/download_media.dart';
import 'package:frontend/screens/chat/image_viewer.dart';
import 'package:frontend/screens/chat/media_gallery.dart';
import 'package:frontend/screens/chat/pdf_viewer.dart';
import 'package:frontend/screens/chat/videoPlayer.dart';
import 'package:frontend/screens/widgets/measure_size.dart';
import 'package:frontend/screens/widgets/toast_message.dart';
import 'package:frontend/services/s3_services.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';



class ChatScreen extends StatefulWidget {
  final String authToken;
  final String classId;
  final String className;

  const ChatScreen(
      {super.key, required this.authToken,
      required this.classId,
      required this.className});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class LocalImageCache {
  static final Map<String, ImageProvider> _cache = {};

  static ImageProvider get(String path) {
    if (_cache.containsKey(path)) return _cache[path]!;
    final img = FileImage(File(path));
    _cache[path] = img;
    return img;
  }

  static void clear() => _cache.clear();
}


class _ChatScreenState extends State<ChatScreen> {
  late IO.Socket socket;
  List messages = [];
  Set<String> uploadingKeys = {}; // keys or local ids currently uploading
  bool isTyping = false;
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<DateTime> messageTimes = [];
  List<String> dateLabels = [];
  Map<String, String> userNamesCache = {};

  late final currentUserId =
      Provider.of<UserProvider>(context, listen: false).user?.id;
  String? currentUserRole;

  final ValueNotifier<String> floatingDate = ValueNotifier("");
  final Map<int, double> _itemHeights = {};


  @override
  void initState() {
    super.initState();
    fetchCurrentUserDetails();
    fetchOldMessages();
    initSocket();
    _scrollController.addListener(_handleScroll);
  }

  
void _handleScroll() {
  final pos = _scrollController.position;
  final double offset = pos.pixels;

  final int approxIndex = (offset / 180).floor();
  _precacheNextImages(approxIndex);
  _precachePreviousImages(approxIndex);
  
  // Find which date section we're in
  double cumulativeHeight = 0;
  int dateIndex = 0;
  
  for (int i = 0; i < messages.length; i++) {
    final height = _itemHeights[i] ?? 180; 
    cumulativeHeight += height;
    
    if (cumulativeHeight > offset) {
      dateIndex = i;
      break;
    }
  }
  
  final int actualIndex = messages.length - 1 - dateIndex;
  if (actualIndex >= 0 && actualIndex < dateLabels.length) {
    floatingDate.value = dateLabels[actualIndex];
  }
}



void _precacheNextImages(int currentIndex) async {
  // In reverse mode, "next" means OLDER messages (further up)
  final nextBatch = messages.skip(currentIndex + 1).take(5);

  for (final msg in nextBatch) {
    final url = msg['url'];
    final name = msg['name'];
    final mime = msg['mime'] ?? '';

    if (url != null && url.isNotEmpty && mime.startsWith('image/')) {
      final exists = await FileUtils.fileExists(name);
      if (exists) {
        final localPath = await FileUtils.getLocalFilePath(name);
        final file = File(localPath);
        if (await file.exists()) {
          precacheImage(FileImage(file), context);
          print('✅ Precaching local image: $localPath');
        } else {
          print('⚠️ File not found for precache: $localPath');
        }
      } else {
        print('⏩ Skipped network precache for: $name (not local)');
      }
    }
  }
}

void _precachePreviousImages(int currentIndex) async {
  // In reverse mode, "previous" means NEWER messages (further down)
  final start = (currentIndex - 5).clamp(0, messages.length - 1);
  final prevBatch = messages.skip(start).take(3);

  for (final msg in prevBatch) {
    final url = msg['url'];
    final name = msg['name'];
    final mime = msg['mime'] ?? '';

    if (url != null && url.isNotEmpty && mime.startsWith('image/')) {
      final exists = await FileUtils.fileExists(name);
      if (exists) {
        final localPath = await FileUtils.getLocalFilePath(name);
        final file = File(localPath);
        if (await file.exists()) {
          precacheImage(FileImage(file), context);
          debugPrint('✅ Precaching local image: $localPath');
        } else {
          debugPrint('⚠️ File missing during precache: $localPath');
        }
      } else {
        debugPrint('⏩ Skipped network precache for: $name (not local)');
      }
    }
  }
}
Offset _tapPosition = Offset.zero;

void _storePosition(TapDownDetails details) {
  _tapPosition = details.globalPosition;
}

void _showMessageMenu(BuildContext context, Map<dynamic, dynamic> msg, bool isMe, bool isMedia) async {
  final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;

  final selected = await showMenu<String>(
    context: context,
    position: RelativeRect.fromLTRB(
      _tapPosition.dx,
      _tapPosition.dy,
      overlay.size.width - _tapPosition.dx,
      overlay.size.height - _tapPosition.dy,
    ),
    items: [
      if (!isMedia)
        PopupMenuItem(
        value: 'copy',
        child: Row(
          children: const [
            Icon(Icons.copy, size: 20),
            SizedBox(width: 8),
            Text('Copy'),
          ],
        ),
      ),
      
      

      // Only allow delete for user's own messages
      if (isMe)
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: const [
              Icon(Icons.delete, size: 20, color: Colors.red),
              SizedBox(width: 8),
              Text('Delete'),
            ],
          ),
        ),
    ],
  );

  // Handle user selection
  switch (selected) {
    case 'copy':
      if (msg['content'] != null && msg['content'].toString().isNotEmpty) {
        await Clipboard.setData(ClipboardData(text: msg['content']));
        showToast('Text Copied');
      }
      break;

    case 'delete':
      _attemptDeleteMessage(msg['_id'] as String? ?? '', msg);
      break;
  }
}




  List<Map> _getMediaMessages() {
    final List<Map> media = [];
    for (final msg in messages) {
      final content = msg['content'];
      dynamic parsed = content;
      if (content is String) {
        try {
          parsed = json.decode(content);
        } catch (_) {
          parsed = content;
        }
      }

      if (parsed is Map && parsed['type'] == 'file' && parsed['url']!= null) {
        final mime = parsed['mime'] ?? '';
        if (mime.startsWith('image/') ||
            mime.startsWith('video/') ||
            mime == 'application/pdf') {
          media.add({
            'url': parsed['url'],
            'name': parsed['name'] ?? '',
            'mime': mime,
            'timestamp': msg['timestamp'],
            'sender': msg['sender'],
            '_id': msg['_id'],
          });
        }
      }
    }
    return media.reversed.toList();
  }

  Future<void> openFile(String filePath) async {
  final result = await OpenFilex.open(filePath);
  print('Result: ${result.message}');
}


  Future<String> downloadPdf(String url, String filename) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$filename');
    if (!await file.exists()) {
      final resp = await http.get(Uri.parse(url));
      await file.writeAsBytes(resp.bodyBytes);
    }
    return file.path;
  }

  Future<void> fetchCurrentUserDetails() async {
    if (currentUserId == null) return;
    try {
      final res = await http.get(
        Uri.parse('${URL.chatURL}/classes/get-user-role?userId=$currentUserId'),
        headers: {'Authorization': 'Bearer ${widget.authToken}'},
      );
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (!mounted) {
          // Widget was disposed while awaiting network response; keep state updated but don't call setState
          currentUserRole = data['role'];
          return;
        }
        setState(() {
          currentUserRole = data['role'];
        });
      }
    } catch (e) {
      print('Error fetching current user details: $e');
    }
  }

  Future<void> fetchOldMessages() async {
    try {
      final res = await http.get(
        Uri.parse(
            '${URL.chatURL}/classes/get-messages?classId=${widget.classId}'),
        headers: {'Authorization': 'Bearer ${widget.authToken}'},
      );

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        // If widget is already disposed, avoid calling setState
        if (!mounted) {
          messages = data;
          return;
        }
        setState(() {
          messages = data;
        });

        for (var msg in messages) {
  final dt = DateTime.parse(msg['timestamp']);
  messageTimes.add(dt);

  // Convert date to Today/Yesterday/dd MMM
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final msgDate = DateTime(dt.year, dt.month, dt.day);

  String label;
  if (msgDate == today) {
    label = "Today";
  } else if (msgDate == today.subtract(Duration(days: 1))) {
    label = "Yesterday";
  } else {
    label = DateFormat("dd MMM yyyy").format(msgDate);
  }

  dateLabels.add(label);
}

      }
    } catch (e) {
      print('Error fetching old messages: $e');
    }
  }

  void initSocket() {
    socket = IO.io(URL.socketURL, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
      'auth': {'token': widget.authToken},
      'forceNew': true,
    });

    socket.connect();

    socket.onConnect((_) {
      print('Socket connected');
      // Join the specific class room to receive messages for this class
      socket.emit('join-room', widget.classId);
    });

    socket.onDisconnect((_) {
      print('Socket disconnected');
    });

    socket.onConnectError((error) {
      print('Socket connection error: $error');
    });

    socket.on('message', (data) {
      print('Received message: $data');
      // Handle server-side deletion relay
      if (data != null && data['deleted'] == true && data['_id'] != null) {
        if (!mounted) return;
        setState(() {
          messages.removeWhere((m) => m['_id'] == data['_id']);
        });
        return;
      }
      if (mounted) {
        setState(() {
          // Check if message already exists to prevent duplicates using multiple criteria
          bool messageExists = messages.any((msg) =>
              msg['_id'] == data['_id'] ||
              (msg['content'] == data['content'] &&
                  msg['sender'] == data['sender'] &&
                  (msg['timestamp'] != null &&
                      data['timestamp'] != null &&
                      DateTime.parse(msg['timestamp'])
                              .difference(DateTime.parse(data['timestamp']))
                              .abs()
                              .inSeconds <
                          5)));

          if (!messageExists) {
            // Ensure consistent message structure
            final formattedMessage = {
              '_id': data['_id'] ??
                  DateTime.now().millisecondsSinceEpoch.toString(),
              'content': data['content'],
              'sender': data['sender'],
              'senderRole': data['senderRole'],
              'timestamp': data['timestamp'],
              'classId': data['classId'],
            };
            // If incoming message has a file key, try to replace local optimistic message
            try {
              dynamic parsedIncoming = formattedMessage['content'];
              if (parsedIncoming is String) {
                parsedIncoming = json.decode(parsedIncoming);
              }
              if (parsedIncoming is Map &&
                  parsedIncoming['type'] == 'file' &&
                  parsedIncoming['key'] != null) {
                final key = parsedIncoming['key'];
                final idx = messages.indexWhere((m) {
                  try {
                    final id = m['_id'] as String? ?? '';
                    final pc = m['content'] is String
                        ? json.decode(m['content'])
                        : m['content'];
                    // Match any optimistic local message (id startsWith 'local_') with same key,
                    // or a message that still has a local preview/path. This avoids races where
                    // localPreviewBase64 was removed before the server relay arrives.
                    return pc is Map &&
                        pc['key'] == key &&
                        (id.startsWith('local_') ||
                            pc['localPreviewBase64'] != null ||
                            pc['localPath'] != null);
                  } catch (e) {
                    return false;
                  }
                });
                if (idx >= 0) {
                  // preserve local id removed -> capture local id so we can clear uploading state
                  final localId = messages[idx]['_id'];
                  // Preserve optimistic localPreviewBase64 if present so UI keeps showing the preview until
                  // the server-supplied URL or thumbnail is available (prevents flicker)
                  try {
                    final existingContent = messages[idx]['content'];
                    dynamic existingParsed = existingContent;
                    if (existingContent is String) {
                      existingParsed = json.decode(existingContent);
                    }

                    dynamic serverParsed = formattedMessage['content'];
                    if (serverParsed is String) {
                      serverParsed = json.decode(serverParsed);
                    }

                    if (existingParsed is Map &&
                        existingParsed['localPreviewBase64'] != null &&
                        serverParsed is Map) {
                      // only copy localPreviewBase64 if server hasn't provided a URL or thumbnail yet
                      if ((serverParsed['url'] == null ||
                              (serverParsed['url'] as String).isEmpty) &&
                          (serverParsed['thumbnailUrl'] == null ||
                              (serverParsed['thumbnailUrl'] as String)
                                  .isEmpty)) {
                        serverParsed['localPreviewBase64'] =
                            existingParsed['localPreviewBase64'];
                        formattedMessage['content'] = json.encode(serverParsed);
                      }
                    }
                  } catch (e) {
                    // ignore parse errors and proceed with replacement
                  }

                  // Replace the optimistic message with server message; outer setState will handle UI update
                  messages[idx] = formattedMessage;
                  // clear uploading flag for the optimistic id (no nested setState; outer setState encompasses this change)
                  uploadingKeys.remove(localId);
                } else {
                  messages.add(formattedMessage);
                }
              } else {
                messages.add(formattedMessage);
              }
            } catch (e) {
              messages.add(formattedMessage);
            }
            // Sort messages by timestamp to maintain order
            messages.sort((a, b) => DateTime.parse(a['timestamp'])
                .compareTo(DateTime.parse(b['timestamp'])));
          }
        });
      }
    });

    socket.on('typing', (data) {
      print('Received typing event: $data');
      if (mounted && data['sender'] != currentUserId) {
        // Only show if not current user
        setState(() {
          isTyping = data['isTyping'] ?? false;
        });
      }
    });
  }

  void sendMessage(String msg) {
    if (msg.trim().isEmpty) return;
    if (currentUserId == null) return;

    if (!socket.connected) {
      print('Socket not connected, attempting to reconnect...');
      socket.connect();
      return;
    }

    print('Sending message: $msg');
    socket.emit('message', {
      'classId': widget.classId,
      'message': msg,
      'sender': currentUserId,
    });

    _controller.clear();
    sendTyping(false); // Stop typing indicator when message is sent
  }


Future<void> uploadFile() async {
  await UploadService.uploadFiles(
    authToken: widget.authToken,
    classId: widget.classId,
    currentUserId: currentUserId!,
    currentUserRole: currentUserRole,
    messages: messages,
    uploadingKeys: uploadingKeys,
    baseUrl: URL.chatURL,
    setState: setState,
    mounted: mounted,
  );
}
Widget _buildFilePreview(Map parsed, String messageId, String sender) {
    final String url = parsed['url'] ?? '';
    final String name = parsed['name'] ?? '';
    final String mime = parsed['mime'] ?? '';
    final bool isImage = mime.startsWith('image/');
    final bool isVideo = mime.startsWith('video/');
    final bool isPDF = mime.startsWith('application/pdf');

    return FutureBuilder<bool>(
      future: FileUtils.fileExists(name),
      builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      // 👇 while the async call is still running
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (snapshot.hasError) {
      return const Text('Error checking file');
    }

    if (snapshot.hasData && (snapshot.data == true || snapshot.data == false)) {
       {
        final exists = snapshot.data ?? false;
        final fileFuture = exists ? FileUtils.getLocalFilePath(name) : null;

        final preview = Container(
          constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.72),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: isImage
                ? (exists
                    ? FutureBuilder<String>(
                        future: fileFuture,
                        builder: (context, snap) {
                          if (!snap.hasData) {
                            return SizedBox(
                              height: 160,
                              width: MediaQuery.of(context).size.width * 0.32,
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          return Image(
                            image: LocalImageCache.get(snap.data!),
                            fit: BoxFit.cover,
                            height: 160,
                            width: MediaQuery.of(context).size.width * 0.32,
                          );
                        },
                      )
                    : (url.isEmpty
                        ? Container(
                            height: 160,
                            color: Colors.black12,
                            child: const Center(
                                    child: Icon(Icons.broken_image)),
                              )
                            : Stack(
                                alignment: Alignment.center,
                                children: [
                                  CachedNetworkImage(
                                    imageUrl: url,
                                    height: 160,
                                    fit: BoxFit.cover,
                                    placeholder: (context, _) => const SizedBox(
                                      height: 160,
                                      child: Center(
                                          child: CircularProgressIndicator()),
                                    ),
                                    errorWidget: (context, error, stackTrace) {
                                      Future.microtask(() =>
                                          _ensureUrlForParsed(parsed, messageId,
                                              force: true));
                                      return Container(
                                        height: 160,
                                        color: Colors.black12,
                                        child: const Center(
                                            child: Icon(Icons.broken_image)),
                                      );
                                    },
                                    imageBuilder: (context, imageProvider) {
                                      // ✅ Trigger auto-download when image successfully loads
                                      Future.microtask(() async {
                                        try {
                                          await FileUtils.downloadFile(
                                              url, name);
                                        } catch (e) {
                                          debugPrint(
                                              'Auto-download failed: $e');
                                        }
                                      });

                                      return Image(
                                        image: imageProvider,
                                        height: 160,
                                        fit: BoxFit.cover,
                                      );
                                    },
                                  ),
                                  Positioned(
                                    bottom: 8,
                                    right: 8,
                                    child: IconButton(
                                      icon: const Icon(
                                        Icons.download_rounded,
                                        color: Color.fromARGB(255, 145, 35, 35),
                                      ),
                                      onPressed: () async {
                                        try {
                                          await FileUtils.downloadFile(
                                              url, name);
                                          (context as Element).markNeedsBuild();
                                        } catch (e) {}
                                      },
                                    ),
                                  ),
                                ],
                              )))
                    : isVideo
                        ? FutureBuilder<String>(
                            future:
                                FileUtils.getVideoThumbnail(exists, url, name),
                            builder: (context, snap) {
                              if (!snap.hasData) {
                                return SizedBox(
                              height: 160,
                              width: MediaQuery.of(context).size.width * 0.32,
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          return Stack(
                            alignment: Alignment.center,
                            children: [
                              Image.file(
                                File(snap.data!),
                                fit: BoxFit.cover,
                                height: 160,
                                width: MediaQuery.of(context).size.width * 0.32,
                              ),
                              const Icon(Icons.play_circle_outline,
                                  size: 56, color: Colors.white70),
                            ],
                          );
                        },
                      )
                    : isPDF
                        ? Container(
                            height: 160,
                            width: 160,
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: Colors.red.shade200, width: 1),
                            ),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.picture_as_pdf,
                                      color: Colors.red, size: 48),
                                  const SizedBox(height: 8),
                                  Text(
                                    name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : Container(
                            height: 140,
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Container(
                                  width: 96,
                                  height: 96,
                                  color: Colors.black12,
                                  child: Center(
                                    child: Icon(
                                        isVideo
                                            ? Icons.videocam
                                            : isPDF
                                                ? Icons.picture_as_pdf
                                                : Icons.insert_drive_file,
                                        size: 40),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(name,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 6),
                                      Text(mime,
                                          style: const TextStyle(
                                              color: Colors.black54,
                                              fontSize: 12)),
                                    ],
                                  ),
                                )
                              ],
                            ),
                          ),
          ),
        );

        return GestureDetector(
          onTap: () async {
            if (isVideo) {
              final path = exists
                  ? await FileUtils.getLocalFilePath(name)
                  : await FileUtils.downloadFile(url, name);
              if (context.mounted) {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) =>
                      VideoPlayerScreen(videoUrl: path, isLocal: true, senderID: sender),
                ));
              }
              
            } else if (isImage) {
              final path = exists
                  ? await FileUtils.getLocalFilePath(name)
                  : await FileUtils.downloadFile(url, name);
              if (context.mounted) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => LocalImageViewer(filePath: path, senderID: sender ),
                  ),
                );
              }
              
            } else if (isPDF) {
              final path = exists
                  ? await FileUtils.getLocalFilePath(name)
                  : await FileUtils.downloadFile(url, name);

              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => PdfViewerScreen(filePath: path),
              ));
            }
            else{
              final path = exists
                ? await FileUtils.getLocalFilePath(name)
                : await FileUtils.downloadFile(url, name);
                openFile(path);
            }
          },
          child: isVideo
              ? Stack(
                  alignment: Alignment.center,
                  children: [
                    preview,
                    Icon(Icons.play_circle_outline,
                        size: 56, color: Colors.white70),
                  ],
                )
              : preview,
        );
      }
    } else {
      // 👇 file does not exist
      return const Text('❌ File missing');
    }
  },
    );
  }

  Future<void> _ensureUrlForParsed(Map parsed, String messageId,
      {bool force = false}) async {
    try {
      if (!force &&
          parsed['url'] != null &&
          (parsed['url'] as String).isNotEmpty) {
        return;
      }
      final key = parsed['key'];
      if (key == null) return;
      // If we've already requested a presign and not forcing, skip
      if (!force && parsed['_presignRequested'] == true) return;
      final res = await http.get(
          Uri.parse('${URL.chatURL}/classes/presign-get?key=$key'),
          headers: {'Authorization': 'Bearer ${widget.authToken}'});
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        parsed['url'] = data['url'];
        // mark that we requested presign for this parsed map so we don't request repeatedly
        parsed['_presignRequested'] = true;
        // Also update the stored message in messages list with the new parsed content (to persist localPreviewBase64)
        if (mounted) {
          final idx = messages.indexWhere((m) => m['_id'] == messageId);
          if (idx >= 0) {
            try {
              final m = Map.of(messages[idx]);
              dynamic cont = m['content'];
              if (cont is String) cont = json.decode(cont);
              if (cont is Map) {
                cont['url'] = data['url'];
                cont['_presignRequested'] = true;
                m['content'] = json.encode(cont);
                messages[idx] = m;
              }
            } catch (e) {
              // ignore parse errors
            }
          }
        }
        // Avoid calling setState if widget was disposed while awaiting network
        if (!mounted) return;
        setState(
            () {}); // trigger rebuild to show image (still showing base64 if present)

        // Precache the network image so the UI can swap smoothly from base64 to network image
        try {
          final urlToCache = data['url'] as String?;
          if (urlToCache != null && urlToCache.isNotEmpty) {
            final image = NetworkImage(urlToCache);
            await precacheImage(image, context);

            // After successful precache, remove localPreviewBase64 from stored message so build uses network image
            if (!mounted) return;
            final idx2 = messages.indexWhere((m) => m['_id'] == messageId);
            if (idx2 >= 0) {
              try {
                final m2 = Map.of(messages[idx2]);
                dynamic cont2 = m2['content'];
                if (cont2 is String) cont2 = json.decode(cont2);
                if (cont2 is Map &&
                    (cont2['localPreviewBase64'] != null ||
                        cont2['localPath'] != null)) {
                  cont2.remove('localPreviewBase64');
                  cont2.remove('localPath');
                  m2['content'] = json.encode(cont2);
                  setState(() {
                    messages[idx2] = m2;
                  });
                }
              } catch (e) {
                // ignore
              }
            }
          }
        } catch (e) {
          // If precache fails, keep the base64 preview; it's fine to log
          print('Image precache failed: $e');
        }
      }
    } catch (e) {
      print('Error fetching presigned GET for key: $e');
    }
  }

  void sendTyping(bool typing) {
    if (socket.connected && currentUserId != null) {
      socket.emit('typing', {
        'classId': widget.classId,
        'sender': currentUserId, // Include sender ID
        'isTyping': typing,
      });
    }
  }

  void checkConnection() {
    if (!socket.connected) {
      print('Socket not connected, attempting to reconnect...');
      socket.connect();
    }
  }


  Future<void> loadUserNameIfNeeded(String userId) async {
    if (userId.isEmpty || userNamesCache.containsKey(userId)) return;
    try {
      final response = await http.get(
        Uri.parse('${URL.chatURL}/classes/get-user-name?userId=$userId'),
        headers: {
          'Authorization': 'Bearer ${widget.authToken}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final userName = data['name'] ?? '?';
        setState(() {
          userNamesCache[userId] = userName;
        });
      } else {
        setState(() {
          userNamesCache[userId] = '?';
        });
      }
    } catch (e) {
      print('Error loading username for $userId: $e');
      setState(() {
        userNamesCache[userId] = '?';
      });
    }
  }

  String getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.split(' ');
    return parts[0]; // keep it simple
  }

  Widget buildMessage(Map msg) {
    final currentUserId =
        Provider.of<UserProvider>(context, listen: false).user?.id;
    final senderId = msg['sender'] ?? '';

    if (senderId.isNotEmpty) {
      loadUserNameIfNeeded(senderId);
    }

    // Defensive: if message content is missing or empty, don't render a bubble
    final rawContent = msg['content'];
    if (rawContent == null) return SizedBox.shrink();
    if (rawContent is String && rawContent.trim().isEmpty) {
      return SizedBox.shrink();
    }

    final senderName = userNamesCache[senderId] ?? '?';
    final initials = getInitials(senderName);

    final bool isMe = currentUserId != null && senderId == currentUserId;
    bool isMedia= false;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Build the message bubble first, then wrap with GestureDetector for deletion
    final bubble = Align(
      // alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: MediaQuery.of(context).size.width * 0.32, // 20% of screen
            maxWidth: MediaQuery.of(context).size.width * 0.8, // 80% of screen
          ),
          child: IntrinsicWidth(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              padding: const EdgeInsets.all(12),
              
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isMe
                      ? (isDarkMode
                          ? [
                              const Color(0xFF43A047),
                              const Color(0xFF2E7D32)
                            ] // Dark sent
                          : [
                              const Color(0xFFB2FF59),
                              const Color(0xFF76FF03)
                            ]) // Light sent
                      : (isDarkMode
                          ? [
                              const Color(0xFF616161),
                              const Color.fromARGB(255, 98, 98, 98)
                            ] // Dark received
                          : [
                              const Color(0xFFF5F5F5),
                              const Color(0xFFE0E0E0)
                            ]), // Light received
                ),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: isMe
                      ? const Radius.circular(18)
                      : const Radius.circular(0),
                  bottomRight: isMe
                      ? const Radius.circular(0)
                      : const Radius.circular(18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 3,
                    offset: const Offset(1, 2),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Message content (text or file)
                  Builder(builder: (_) {
                    final content = msg['content'];
                    dynamic parsed = content;
                    if (content is String) {
                      try {
                        parsed = json.decode(content);
                      } catch (e) {
                        parsed = content;
                      }
                    }

                    if (parsed is Map && parsed['type'] == 'file') {
                      isMedia= true;
                      // Pass the whole parsed map so we can handle local preview (base64) and server URL
                      final idKey = msg['_id'] as String? ?? '';
                      final bool isUploading = uploadingKeys.contains(idKey) ||
                          idKey.startsWith('local_');
                      // Build file preview with uploading overlay; long-press deletion is handled
                      // by the outer wrapper (below) which calls _attemptDeleteMessage.
                      return Stack(
                        children: [
                          _buildFilePreview(parsed, idKey, senderId),
                          if (isUploading)
                            Positioned.fill(
                              child: Container(
                                color: Colors.black26,
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CircularProgressIndicator(),
                                      SizedBox(height: 8),
                                      Text('Uploading...',
                                          style:
                                              TextStyle(color: Colors.white)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    }

                    // fallback: plain text
                    return Text(
                      parsed is String ? parsed : (parsed?.toString() ?? ' '),
                      style: TextStyle(
                        fontSize: 16,
                        color: isDarkMode
                            ? Colors.white
                            : Colors.black // dark grey for light backgrounds
                      ),
                    );
                  }),
                  const SizedBox(height: 4),

                  // Bottom row: initials + timestamp
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        initials,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode
                              ? Colors.white
                              : const Color.fromARGB(255, 120, 120, 120),
                        ),
                      ),
                      SizedBox(width: 10),
                      Text(
                        msg['timestamp'] != null
                            ? DateFormat('h:mma')
                                .format(
                                    DateTime.parse(msg['timestamp']).toLocal())
                                .toLowerCase()
                            : '',
                        style: TextStyle(
                          fontSize: 10,
                          color: isDarkMode
                              ? Colors.white
                              : const Color.fromARGB(255, 120, 120, 120),
                        ),
                      )
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    
    if (isMe) {
  return GestureDetector(
    onTapDown: (details) => _storePosition(details),
    onLongPress: () => _showMessageMenu(context, msg, isMe, isMedia),
    child: bubble,
  );
} else {
  return GestureDetector(
    onTapDown: (details) => _storePosition(details),
    onLongPress: () => _showMessageMenu(context, msg, isMe, isMedia),
    child: bubble,
  );
}
  }

  /// Attempt to delete a message. If the message is optimistic (local_ id) it
  /// will be removed locally. Otherwise permission checks are enforced and a
  /// DELETE request is sent to the backend. On success the message is removed
  /// from the local list; failures show a SnackBar.
  Future<void> _attemptDeleteMessage(String idKey, Map msg) async {
    if (idKey.startsWith('local_')) {
      if (!mounted) return;
      setState(() {
        messages.removeWhere((m) => m['_id'] == idKey);
        uploadingKeys.remove(idKey);
      });
      return;
    }

    final senderIdLocal = msg['sender'] ?? '';
    final currentUserIdLocal =
        Provider.of<UserProvider>(context, listen: false).user?.id;
    if (currentUserIdLocal == null) return;
    // Only allow delete when the current user is the original sender. Server also enforces this.
    if (currentUserIdLocal != senderIdLocal) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('You do not have permission to delete this message')));
      return;
    }

    final should = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete message?'),
        content: Text('This will remove the message and any attached files.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text('Delete')),
        ],
      ),
    );

    if (should != true) return;

    try {
      final res = await http.delete(
          Uri.parse('${URL.chatURL}/classes/delete-message/$idKey'),
          headers: {'Authorization': 'Bearer ${widget.authToken}'});
      if (res.statusCode == 200) {
        if (!mounted) return;
        setState(() {
          messages.removeWhere((m) => m['_id'] == idKey);
        });
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to delete')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    }
  }

  @override
  void dispose() {
    socket.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(widget.className),
          actions: [
            IconButton(
              icon: Icon(Icons.photo_library),
              tooltip: 'Shared media',
              onPressed: () {
                final media = _getMediaMessages();
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => MediaGalleryScreen(mediaList: media),
                ));
              },
            )
          ],
        ),
        body: Stack(children: [
          Positioned.fill(
            child: Image.asset(
              Theme.of(context).brightness == Brightness.dark
                  ? 'assets/images/darkChatbackground.jpg' // 🌙 Dark mode image
                  : 'assets/images/lightChatbackground.png', // ☀️ Light mode image
              fit: BoxFit.cover,
            ),
          ),
         SafeArea(
 child: Stack(
  children: [
    Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            reverse: true,
            itemCount: messages.length,
            itemBuilder: (_, i) {
              final actualIndex = messages.length - 1 - i;
              return MeasureSize(
                onChange: (size) {
                  if (_itemHeights[actualIndex] != size.height) {
                    _itemHeights[actualIndex] = size.height;
                    // Optional: you can call _recalculateTotalHeight() here if needed
                  }
                },
                child: buildMessage(messages[actualIndex]),
              );
            })),

          if (isTyping)
            Padding(
              padding: EdgeInsets.all(8),
              child: Text(
                'Someone is typing...',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ),

          if (currentUserRole != 'student')
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black54,
                  border: Border.all(
                    color: Colors.grey,
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(29),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Text input area
                    Expanded(
                      child: Container(
                        constraints: const BoxConstraints(
                          maxHeight: 150,
                        ),
                        margin: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(29),
                        ),
                        child: Scrollbar(
                          thumbVisibility: false,
                          child: SingleChildScrollView(
                            reverse: true,
                            child: TextField(
                              controller: _controller,
                              keyboardType: TextInputType.multiline,
                              maxLines: null,
                              onChanged: (val) =>
                                  sendTyping(val.isNotEmpty),
                              style: const TextStyle(color: Colors.black),
                              decoration: const InputDecoration(
                                hintText: 'Type a message',
                                hintStyle:
                                    TextStyle(color: Colors.black54),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Icons
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.attach_file),
                          color: Colors.white,
                          onPressed: uploadFile,
                        ),
                        IconButton(
                          icon: const Icon(Icons.send),
                          color: Colors.white,
                          onPressed: () {
                            final text = _controller.text.trim();
                            if (text.isNotEmpty) sendMessage(text);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'You do not have permission to send messages.',
                style: TextStyle(color: Colors.black),
              ),
            ),
        ],
      ),

      //Floating Date Header 
      Positioned(
        top: 10,
        left: 0,
        right: 0,
        child: ValueListenableBuilder(
          valueListenable: floatingDate,
          builder: (_, value, __) {
            if (value.isEmpty) return SizedBox.shrink();

            return Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ],
  ),
)

          ]
        ),
      );
}
