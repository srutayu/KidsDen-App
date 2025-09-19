import 'package:flutter/material.dart';
import 'package:frontend/provider/user_data_provider.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:http/http.dart' as http;
import 'dart:convert';

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

  Future<void> fetchCurrentUserDetails() async {
  if (currentUserId == null) return;
    try {
      final res = await http.get(
        Uri.parse(
            'http://192.168.0.131:8000/api/classes/get-user-role?userId=$currentUserId'),
        headers: {'Authorization': 'Bearer ${widget.authToken}'},
      );
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
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
            'http://192.168.0.131:8000/api/classes/get-messages?classId=${widget.classId}'),
        headers: {'Authorization': 'Bearer ${widget.authToken}'},
      );

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        setState(() {
          messages = data;
        });
      }
    } catch (e) {
      print('Error fetching old messages: $e');
    }
  }

  void initSocket() {
    socket = IO.io('http://192.168.0.131:8000', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
      'auth': {'token': widget.authToken}
    });

    socket.connect();

    socket.onConnect((_) {
      print('connected');
    });

    socket.on('message', (data) {
      setState(() {
        messages.add(data);
      });
    });

    socket.on('typing', (data) {
      setState(() {
        isTyping = data['isTyping'] ?? false;
      });
    });
  }

 void sendMessage(String msg) {
  if (msg.trim().isEmpty) return;
  if (currentUserId == null) return;
  socket.emit('message', {
    'classId': widget.classId,
    'message': msg,
    'sender': currentUserId,
  });

  setState(() {
    messages.add({
      'content': msg,
      'sender': currentUserId,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    });
  });

  _controller.clear();
}

  void sendTyping(bool typing) {
    socket.emit('typing', {
      'classId': widget.classId,
      'isTyping': typing,
    });
  }

  Future<void> loadUserNameIfNeeded(String userId) async {
    if (userId.isEmpty || userNamesCache.containsKey(userId)) return;
    try {
      final response = await http.get(
        Uri.parse(
            'http://192.168.0.131:8000/api/classes/get-user-name?userId=$userId'),
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
            // Message text
            Text(
              msg['content'],
              style: const TextStyle(fontSize: 16),
            ),
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
                SizedBox(width: 4),
                Text(
                 DateFormat('h:mma').format(DateTime.parse(msg['timestamp']).toLocal()).toLowerCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.black38,
                  ),
                ),
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
        appBar: AppBar(title: Text(widget.className)),
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
                    IconButton(
                      icon: Icon(Icons.send),
                      onPressed: () => sendMessage(_controller.text),
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
