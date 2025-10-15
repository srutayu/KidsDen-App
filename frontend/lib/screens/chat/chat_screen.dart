import 'package:flutter/material.dart';
import 'package:frontend/constants/url.dart';
import 'package:frontend/provider/user_data_provider.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:file_selector/file_selector.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';

class ChatScreen extends StatefulWidget {
  final String authToken;
  final String classId;
  final String className;

  ChatScreen({
    required this.authToken,
    required this.classId,
    required this.className,
  });

  @override
  _ChatScreenState createState() => _ChatScreenState();
}


// Screen to show media thumbnails and open full-screen viewer
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

class _ChatScreenState extends State<ChatScreen> {
  late IO.Socket socket;
  List messages = [];
  bool isTyping = false;
  TextEditingController _controller = TextEditingController();

  // Cache: userId -> userName
  Map<String, String> userNamesCache = {};

  // Current logged-in userId
  late final currentUserId = Provider.of<UserProvider>(context, listen: false).user?.id;
  String? currentUserRole;

  @override
  void initState() {
    super.initState();
    fetchCurrentUserDetails();
    fetchOldMessages();
    initSocket();
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

      if (parsed is Map && parsed['type'] == 'file') {
        final mime = parsed['mime'] ?? '';
        if (mime.startsWith('image/') || mime.startsWith('video/') || mime == 'application/pdf') {
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

  Future<void> fetchCurrentUserDetails() async {
  if (currentUserId == null) return;
    try {
      final res = await http.get(
        Uri.parse(
            '${URL.chatURL}/classes/get-user-role?userId=$currentUserId'),
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
          print('Fetched ${messages.length} messages for class ${widget.classId} (widget disposed before update)');
          return;
        }
        setState(() {
          messages = data;
        });
        print('Fetched ${messages.length} messages for class ${widget.classId}');
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
      if (mounted) {
        setState(() {
          // Check if message already exists to prevent duplicates using multiple criteria
          bool messageExists = messages.any((msg) => 
            msg['_id'] == data['_id'] ||
            (msg['content'] == data['content'] && 
             msg['sender'] == data['sender'] && 
             (msg['timestamp'] != null && data['timestamp'] != null &&
              DateTime.parse(msg['timestamp']).difference(DateTime.parse(data['timestamp'])).abs().inSeconds < 5))
          );
          
          if (!messageExists) {
            // Ensure consistent message structure
            final formattedMessage = {
              '_id': data['_id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
              'content': data['content'],
              'sender': data['sender'],
              'senderRole': data['senderRole'],
              'timestamp': data['timestamp'],
              'classId': data['classId'],
            };
            // If incoming message has a file key, try to replace local optimistic message
            try {
              dynamic parsedIncoming = formattedMessage['content'];
              if (parsedIncoming is String) parsedIncoming = json.decode(parsedIncoming);
              if (parsedIncoming is Map && parsedIncoming['type'] == 'file' && parsedIncoming['key'] != null) {
                final key = parsedIncoming['key'];
                final idx = messages.indexWhere((m) {
                  try {
                    final pc = m['content'] is String ? json.decode(m['content']) : m['content'];
                    return pc is Map && pc['key'] == key && pc['localPreviewBase64'] != null;
                  } catch (e) { return false; }
                });
                if (idx >= 0) {
                  messages[idx] = formattedMessage;
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
            messages.sort((a, b) => DateTime.parse(a['timestamp']).compareTo(DateTime.parse(b['timestamp'])));
          }
        });
      }
    });

    socket.on('typing', (data) {
      print('Received typing event: $data');
      if (mounted && data['sender'] != currentUserId) { // Only show if not current user
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
    if (currentUserId == null) return;
    try {
      final XTypeGroup typeGroup = XTypeGroup(label: 'files', extensions: ['jpg', 'jpeg', 'png', 'pdf', 'mp4', 'mov', 'doc', 'docx']);
      // Allow multiple file selection (max 10)
      final List<XFile>? files = await openFiles(acceptedTypeGroups: [typeGroup]);
      if (files == null || files.isEmpty) return;

      final selection = files.take(10).toList();

      // Prepare metadata for presign request
      final filesMeta = selection.map((f) => ({ 'fileName': f.name, 'contentType': f.mimeType ?? 'application/octet-stream' })).toList();

      // 1) Request batch presigned URLs from backend
      final presignRes = await http.post(
        Uri.parse('${URL.chatURL}/classes/request-presign'),
        headers: {
          'Authorization': 'Bearer ${widget.authToken}',
          'Content-Type': 'application/json'
        },
        body: json.encode({ 'files': filesMeta, 'classId': widget.classId }),
      );

      if (presignRes.statusCode != 200) {
        print('Presign request failed: ${presignRes.statusCode} ${presignRes.body}');
        return;
      }

      final presignData = json.decode(presignRes.body);
      final presignedFiles = presignData['files'] as List<dynamic>? ?? [];

      // Map keys by original name for pairing
      final presignMap = { for (var p in presignedFiles) p['fileName'] : p };

      // For each selected file, upload and confirm
      for (final f in selection) {
        try {
          final bytes = await f.readAsBytes();
          final pres = presignMap[f.name];
          if (pres == null) {
            print('No presign returned for ${f.name}');
            continue;
          }

          final uploadUrl = pres['uploadUrl'];
          final getUrl = pres['getUrl'];
          final key = pres['key'];

          // Insert optimistic local preview message
          try {
            final base64Data = base64Encode(bytes);
            final tempMessage = {
              '_id': 'local_${DateTime.now().millisecondsSinceEpoch}_${f.name}',
              'content': json.encode({ 'type': 'file', 'key': key, 'localPreviewBase64': base64Data, 'mime': f.mimeType ?? 'application/octet-stream', 'name': f.name }),
              'sender': currentUserId,
              'senderRole': currentUserRole,
              'timestamp': DateTime.now().toIso8601String(),
              'classId': widget.classId,
            };
            if (mounted) {
              setState(() {
                messages.add(tempMessage);
              });
            } else {
              messages.add(tempMessage);
            }
          } catch (e) {
            print('Error creating local preview: $e');
          }

          // 2) Upload directly to S3
          final putRes = await http.put(Uri.parse(uploadUrl), headers: {
            'Content-Type': f.mimeType ?? 'application/octet-stream'
          }, body: bytes);

          if (putRes.statusCode != 200 && putRes.statusCode != 204) {
            print('PUT to S3 failed for ${f.name}: ${putRes.statusCode} ${putRes.body}');
            continue;
          }

          // 3) Confirm upload
          final confirmRes = await http.post(
            Uri.parse('${URL.chatURL}/classes/confirm-upload'),
            headers: {
              'Authorization': 'Bearer ${widget.authToken}',
              'Content-Type': 'application/json'
            },
            body: json.encode({ 'key': key, 'classId': widget.classId, 'getUrl': getUrl, 'contentType': f.mimeType ?? 'application/octet-stream', 'name': f.name, 'size': bytes.length }),
          );

          if (confirmRes.statusCode == 200) {
            print('Upload confirmed for ${f.name}');
          } else {
            print('Confirm failed for ${f.name}: ${confirmRes.statusCode} ${confirmRes.body}');
          }
        } catch (e) {
          print('Error uploading file ${f.name}: $e');
        }
      }
    } catch (e) {
      print('Error uploading files: $e');
    }
  }

  

  Widget _buildFilePreview(Map parsed) {
    final String url = parsed['url'] ?? '';
    final String name = parsed['name'] ?? '';
    final String mime = parsed['mime'] ?? '';
    final String? base64Preview = parsed['localPreviewBase64'];

    final bool isImage = mime.startsWith('image/');
    final bool isVideo = mime.startsWith('video/');

    final preview = Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: isImage
            ? (base64Preview != null
                ? SizedBox(height: 160, child: Image.memory(base64Decode(base64Preview), fit: BoxFit.cover))
                : (url.isEmpty
                    ? Container(height: 160, color: Colors.black12, child: Center(child: Icon(Icons.broken_image)))
                    : SizedBox(
                        height: 160,
                        child: Image.network(url, fit: BoxFit.cover, loadingBuilder: (ctx, child, progress) {
                          if (progress == null) return child;
                          return Container(height: 160, child: Center(child: CircularProgressIndicator()));
                        }),
                      )) )
            : Container(
                height: 140,
                padding: EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      color: Colors.black12,
                      child: Center(
                        child: Icon(isVideo ? Icons.videocam : Icons.picture_as_pdf, size: 40),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: TextStyle(fontWeight: FontWeight.bold)),
                          SizedBox(height: 6),
                          Text(mime, style: TextStyle(color: Colors.black54, fontSize: 12)),
                        ],
                      ),
                    )
                  ],
                ),
              ),
      ),
    );

    // If there is no URL but we have a key and backend supports presigned GET, fetch it
    if (url.isEmpty && (parsed['key'] != null)) {
      _ensureUrlForParsed(parsed);
    }

    // Open the built-in full screen viewer for all media types so user can preview and download
    return GestureDetector(
      onTap: () {
        final media = _getMediaMessages();
        // try to find index of this url in media list
        final idx = media.indexWhere((m) => (m['url'] ?? '') == url);
        final start = idx >= 0 ? idx : 0;
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => FullScreenMedia(initialIndex: start, mediaList: media),
        ));
      },
      child: isVideo
          ? Stack(
              alignment: Alignment.center,
              children: [
                preview,
                Icon(Icons.play_circle_outline, size: 56, color: Colors.white70),
              ],
            )
          : preview,
    );
  }

  Future<void> _ensureUrlForParsed(Map parsed) async {
    try {
      if (parsed['url'] != null && (parsed['url'] as String).isNotEmpty) return;
      final key = parsed['key'];
      if (key == null) return;
      final res = await http.get(Uri.parse('${URL.chatURL}/classes/presign-get?key=$key'), headers: {'Authorization': 'Bearer ${widget.authToken}'});
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        parsed['url'] = data['url'];
        // Avoid calling setState if widget was disposed while awaiting network
        if (!mounted) return;
        setState(() {}); // trigger rebuild to show image
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
        Uri.parse(
            '${URL.chatURL}/classes/get-user-name?userId=$userId'),
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
    print(msg);

  if (senderId.isNotEmpty) {
    loadUserNameIfNeeded(senderId);
  }

  final senderName = userNamesCache[senderId] ?? '?';
  final initials = getInitials(senderName);

  final bool isMe = currentUserId != null && senderId == currentUserId;
    return Align(
      // alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Align(
  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
  child: ConstrainedBox(
    constraints: BoxConstraints(
      minWidth: MediaQuery.of(context).size.width * 0.32,  // 20% of screen
      maxWidth: MediaQuery.of(context).size.width * 0.8,  // 80% of screen
    ),
    child: IntrinsicWidth(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isMe ? Colors.greenAccent : Colors.grey.shade300,
          borderRadius: BorderRadius.circular(16),
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
                          print('File message parsed: $parsed');
                          // Pass the whole parsed map so we can handle local preview (base64) and server URL
                          return _buildFilePreview(parsed);
                        }

              // fallback: plain text
              return Text(
                parsed is String ? parsed : (parsed?.toString() ?? ' '),
                style: const TextStyle(fontSize: 16),
              );
            }),
            const SizedBox(height: 4),
      
            // Bottom row: initials + timestamp
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  initials,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.black54,
                  ),
                ),
                      SizedBox(width: 10),
                      Text(
                 msg['timestamp'] != null 
                 ? DateFormat('h:mma').format(DateTime.parse(msg['timestamp']).toLocal()).toLowerCase() : '',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.black38,
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
        body: Column(
          children: [
            Expanded(
              child: ListView.builder(
                reverse: true,
                itemCount: messages.length,
                itemBuilder: (_, i) =>
                    buildMessage(messages[messages.length - 1 - i]),
              ),
            ),
            if (isTyping)
              Padding(
                padding: EdgeInsets.all(8),
                child: Text('Someone is typing...',
                    style: TextStyle(fontStyle: FontStyle.italic)),
              ),
            if (currentUserRole != 'student')
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        maxLines: null,
                        keyboardType: TextInputType.multiline,
                        onChanged: (val) => sendTyping(val.isNotEmpty),
                        decoration: InputDecoration(
                          hintText: 'Type a message',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.attach_file),
                          onPressed: uploadFile,
                        ),
                        IconButton(
                          icon: Icon(Icons.send),
                          onPressed: () => sendMessage(_controller.text),
                        ),
                      ],
                    ),
                  ],
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'You do not have permission to send messages.',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
          ],
        ),
      );

}
