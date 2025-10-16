import 'dart:io';

import 'package:flutter/material.dart';
import 'package:frontend/constants/url.dart';
import 'package:frontend/provider/user_data_provider.dart';
import 'package:frontend/screens/chat/fullscreen_media.dart';
import 'package:frontend/screens/chat/media_gallery.dart';
import 'package:frontend/screens/chat/pdf_viewer.dart';
import 'package:frontend/screens/chat/videoPlayer.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:file_selector/file_selector.dart';

class ChatScreen extends StatefulWidget {
  final String authToken;
  final String classId;
  final String className;

  ChatScreen({required this.authToken, required this.classId, required this.className});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late IO.Socket socket;
  List messages = [];
  Set<String> uploadingKeys = {}; // keys or local ids currently uploading
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

  Future<String> downloadPdf(String url, String filename) async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/$filename');
  print(file);
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
                    final id = m['_id'] as String? ?? '';
                    final pc = m['content'] is String ? json.decode(m['content']) : m['content'];
                    // Match any optimistic local message (id startsWith 'local_') with same key,
                    // or a message that still has a local preview/path. This avoids races where
                    // localPreviewBase64 was removed before the server relay arrives.
                    return pc is Map && pc['key'] == key && (id.startsWith('local_') || pc['localPreviewBase64'] != null || pc['localPath'] != null);
                  } catch (e) { return false; }
                });
                if (idx >= 0) {
                  // preserve local id removed -> capture local id so we can clear uploading state
                  final localId = messages[idx]['_id'];
                  // Preserve optimistic localPreviewBase64 if present so UI keeps showing the preview until
                  // the server-supplied URL or thumbnail is available (prevents flicker)
                  try {
                    final existingContent = messages[idx]['content'];
                    dynamic existingParsed = existingContent;
                    if (existingContent is String) existingParsed = json.decode(existingContent);

                    dynamic serverParsed = formattedMessage['content'];
                    if (serverParsed is String) serverParsed = json.decode(serverParsed);

                    if (existingParsed is Map && existingParsed['localPreviewBase64'] != null && serverParsed is Map) {
                      // only copy localPreviewBase64 if server hasn't provided a URL or thumbnail yet
                      if ((serverParsed['url'] == null || (serverParsed['url'] as String).isEmpty) && (serverParsed['thumbnailUrl'] == null || (serverParsed['thumbnailUrl'] as String).isEmpty)) {
                        serverParsed['localPreviewBase64'] = existingParsed['localPreviewBase64'];
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
            final tempId = 'local_${DateTime.now().millisecondsSinceEpoch}_${f.name}';
            final tempMessage = {
              '_id': tempId,
              'content': json.encode({ 'type': 'file', 'key': key, 'localPreviewBase64': base64Data, 'mime': f.mimeType ?? 'application/octet-stream', 'name': f.name }),
              'sender': currentUserId,
              'senderRole': currentUserRole,
              'timestamp': DateTime.now().toIso8601String(),
              'classId': widget.classId,
            };
            if (mounted) {
              setState(() {
                messages.add(tempMessage);
                uploadingKeys.add(tempId);
              });
            } else {
              messages.add(tempMessage);
              uploadingKeys.add(tempId);
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
            // Try to parse returned message (if server returned it) and replace optimistic message
            try {
              final respBody = json.decode(confirmRes.body);
              // if server returns created message directly
              if (respBody != null && (respBody['_id'] != null || respBody['message'] != null)) {
                Map serverMsg = respBody;
                if (respBody['message'] != null) serverMsg = respBody['message'];
                // replace any optimistic message with same key
                final serverKey = (serverMsg['content'] is String) ? (() { try { return json.decode(serverMsg['content'])['key']; } catch (e) { return null; } })() : (serverMsg['content'] is Map ? serverMsg['content']['key'] : null);
                if (serverKey != null) {
                  final idx = messages.indexWhere((m) {
                    try {
                      final id = m['_id'] as String? ?? '';
                      final pc = m['content'] is String ? json.decode(m['content']) : m['content'];
                      return pc is Map && pc['key'] == serverKey && (id.startsWith('local_') || pc['localPreviewBase64'] != null || pc['localPath'] != null);
                    } catch (e) { return false; }
                  });
                  if (idx >= 0) {
                    setState(() {
                      messages[idx] = serverMsg;
                    });
                  }
                }
              }
            } catch (e) {
              // ignore parse errors
            }
          } else {
            print('Confirm failed for ${f.name}: ${confirmRes.statusCode} ${confirmRes.body}');
          }

          // Always clear uploading flag for any local optimistic message that matches this file key
          _clearUploadingForKey(key);
        } catch (e) {
          print('Error uploading file ${f.name}: $e');
        }
      }
    } catch (e) {
      print('Error uploading files: $e');
    }
  }


Widget _buildFilePreview(Map parsed, String messageId) {
  final String url = parsed['url'] ?? '';
  final String name = parsed['name'] ?? '';
  final String mime = parsed['mime'] ?? '';
  final String? base64Preview = parsed['localPreviewBase64'];

  final bool isImage = mime.startsWith('image/');
  final bool isVideo = mime.startsWith('video/');
  final bool isPDF = mime.startsWith('application/pdf');

  final preview = Container(
    constraints:
        BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
    decoration: BoxDecoration(
      color: Colors.grey.shade200,
      borderRadius: BorderRadius.circular(12),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: isImage
          ? (base64Preview != null
              ? SizedBox(
                  height: 160,
                  child: Image.memory(base64Decode(base64Preview),
                      fit: BoxFit.cover))
              : (url.isEmpty
                  ? Container(
                      height: 160,
                      color: Colors.black12,
                      child: Center(child: Icon(Icons.broken_image)))
                  : SizedBox(
                      height: 160,
                      child: Image.network(
                        url,
                        fit: BoxFit.cover,
                        loadingBuilder: (ctx, child, progress) {
                          if (progress == null) return child;
                          return Container(
                              height: 160,
                              child:
                                  Center(child: CircularProgressIndicator()));
                        },
                        errorBuilder: (ctx, error, stack) {
                          Future.microtask(() {
                            try {
                              _ensureUrlForParsed(parsed, messageId,
                                  force: true);
                            } catch (e) {}
                          });
                          if (base64Preview != null) {
                            return SizedBox(
                                height: 160,
                                child: Image.memory(
                                    base64Decode(base64Preview),
                                    fit: BoxFit.cover));
                          }
                          return Container(
                              height: 160,
                              color: Colors.black12,
                              child: Center(child: Icon(Icons.broken_image)));
                        },
                      ),
                    )))
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
                      child: Icon(
                          isVideo ? Icons.videocam : Icons.picture_as_pdf,
                          size: 40),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        SizedBox(height: 6),
                        Text(mime,
                            style: TextStyle(
                                color: Colors.black54, fontSize: 12)),
                      ],
                    ),
                  )
                ],
              ),
            ),
    ),
  );

  // Wrap in GestureDetector to open fullscreen on tap
  return GestureDetector(
    onTap: () async {
      if (isVideo) {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => VideoPlayerScreen(
              videoUrl: url,
              isLocal: false,
            ),
          ));
        } else if (isImage) {
          // Handle full-screen image preview (existing logic)
          final media = _getMediaMessages();
          final idx = media.indexWhere((m) => (m['url'] ?? '') == url);
          final start = idx >= 0 ? idx : 0;
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) =>
                FullScreenMedia(initialIndex: start, mediaList: media),
          ));
        } else if (isPDF) {
          final localPath = await downloadPdf(url, name);
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => PdfViewerScreen(
              filePath: localPath,
            ),
          ));
        }
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

  Future<void> _ensureUrlForParsed(Map parsed, String messageId, {bool force = false}) async {
    try {
      if (!force && parsed['url'] != null && (parsed['url'] as String).isNotEmpty) return;
      final key = parsed['key'];
      if (key == null) return;
      // If we've already requested a presign and not forcing, skip
      if (!force && parsed['_presignRequested'] == true) return;
      final res = await http.get(Uri.parse('${URL.chatURL}/classes/presign-get?key=$key'), headers: {'Authorization': 'Bearer ${widget.authToken}'});
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
        setState(() {}); // trigger rebuild to show image (still showing base64 if present)

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
                if (cont2 is Map && (cont2['localPreviewBase64'] != null || cont2['localPath'] != null)) {
                  cont2.remove('localPreviewBase64');
                  cont2.remove('localPath');
                  m2['content'] = json.encode(cont2);
                  setState(() { messages[idx2] = m2; });
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

  void _clearUploadingForKey(String key) {
    // Find any messages that are optimistic (local_) and whose content.key == key
    final toRemove = <String>[];
    for (final m in messages) {
      try {
        final cid = m['_id'] as String? ?? '';
        if (!cid.startsWith('local_')) continue;
        final cont = m['content'] is String ? json.decode(m['content']) : m['content'];
        if (cont is Map && cont['key'] == key) toRemove.add(cid);
      } catch (e) { continue; }
    }
    if (toRemove.isEmpty) return;
    setState(() {
      for (final id in toRemove) {
        uploadingKeys.remove(id);
      }
    });
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

  // Defensive: if message content is missing or empty, don't render a bubble
  final rawContent = msg['content'];
  if (rawContent == null) return SizedBox.shrink();
  if (rawContent is String && rawContent.trim().isEmpty) return SizedBox.shrink();

  final senderName = userNamesCache[senderId] ?? '?';
  final initials = getInitials(senderName);

  final bool isMe = currentUserId != null && senderId == currentUserId;
    // Build the message bubble first, then wrap with GestureDetector for deletion
    final bubble = Align(
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
                          // Pass the whole parsed map so we can handle local preview (base64) and server URL
                          final idKey = msg['_id'] as String? ?? '';
                          final bool isUploading = uploadingKeys.contains(idKey) || idKey.startsWith('local_');
                          // Build file preview with uploading overlay; long-press deletion is handled
                          // by the outer wrapper (below) which calls _attemptDeleteMessage.
                          return Stack(
                            children: [
                              _buildFilePreview(parsed, idKey),
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
                                          Text('Uploading...', style: TextStyle(color: Colors.white)),
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

    // Only allow long-press delete for messages sent by the current user
    if (isMe) {
      return GestureDetector(
        onLongPress: () => _attemptDeleteMessage(msg['_id'] as String? ?? '', msg),
        child: bubble,
      );
    }

    // For messages not sent by the current user, just return the bubble (no delete option)
    return bubble;
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
    final currentUserIdLocal = Provider.of<UserProvider>(context, listen: false).user?.id;
    if (currentUserIdLocal == null) return;
    // Only allow delete when the current user is the original sender. Server also enforces this.
    if (currentUserIdLocal != senderIdLocal) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('You do not have permission to delete this message')));
      return;
    }

    final should = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete message?'),
        content: Text('This will remove the message and any attached files.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text('Delete')),
        ],
      ),
    );

    if (should != true) return;

    try {
      final res = await http.delete(Uri.parse('${URL.chatURL}/classes/delete-message/${idKey}'), headers: {'Authorization': 'Bearer ${widget.authToken}'});
      if (res.statusCode == 200) {
        if (!mounted) return;
        setState(() {
          messages.removeWhere((m) => m['_id'] == idKey);
        });
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
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
