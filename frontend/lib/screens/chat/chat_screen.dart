import 'package:flutter/material.dart';
import 'package:frontend/provider/user_data_provider.dart';
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

  // Store current logged-in userId and role to detect own messages and permissions
  String? currentUserId;
  String? currentUserRole;

  @override
  void initState() {
    super.initState();
    fetchCurrentUserDetails();
    fetchOldMessages();
    initSocket();
  }
  late String userId = Provider.of<UserProvider>(context, listen: false).user!.id;

  Future<void> fetchCurrentUserDetails() async {
    try {
      final res = await http.get(
        Uri.parse('http://192.168.0.131:8000/api/classes/get-user-role?userId=$userId'),
        headers: {'Authorization': 'Bearer ${widget.authToken}'},
      );
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        setState(() {
          currentUserId = data['_id'] ?? data['id'];
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

    socket.emit('message', {
      'classId': widget.classId,
      'message': msg,
    });

    setState(() {
      messages.add({'content': msg, 'sender': 'me'});
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
    if (userId.isEmpty || userId == 'me' || userNamesCache.containsKey(userId)) return;

    try {
      final response = await http.get(
        Uri.parse('http://192.168.0.131:8000/api/classes/get-user-name?userId=$userId'),
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
    // if (parts.length == 1) return parts[0][0].toUpperCase();
    // return (parts[0][0] + parts[1][0]).toUpperCase();
    return parts[0];
  }

  Widget buildMessage(Map msg) {
    final senderId = msg['sender'] == 'me' ? 'me' : (msg['sender'] ?? '');
    if (senderId != 'me' && senderId.isNotEmpty) {
      loadUserNameIfNeeded(senderId); // async fetch username if needed
    }
    final senderName = senderId == 'me'
        ? 'You'
        : (userNamesCache[senderId] ?? '?'); // Use cached or placeholder
    final initials = getInitials(senderName);

    final bool isMe = senderId == 'me' || senderId == currentUserId;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isMe ? Colors.greenAccent : Colors.grey.shade300,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(msg['content'] ?? msg['message'] ?? '',
                style: TextStyle(fontSize: 16)),
            SizedBox(height: 4),
            Text(initials, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ],
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
            itemBuilder: (_, i) => buildMessage(messages[messages.length - 1 - i]),
          ),
        ),
        if (isTyping)
          Padding(
            padding: EdgeInsets.all(8),
            child: Text('Someone is typing...',
                style: TextStyle(fontStyle: FontStyle.italic)),
          ),
        // Disable message input for students
        if (currentUserRole != 'student')
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
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
