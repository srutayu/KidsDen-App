import 'package:flutter/material.dart';
import 'package:frontend/constants/url.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';


class BroadcastScreen extends StatefulWidget {
  final String authToken;
  final String userId;
  final String userRole;

  const BroadcastScreen({required this.authToken, required this.userId, required this.userRole});

  @override
  State<BroadcastScreen> createState() => _BroadcastScreenState();
}

class _BroadcastScreenState extends State<BroadcastScreen> {
  List classes = [];
  Set<String> selectedClassIds = {};
  TextEditingController _msgController = TextEditingController();
  bool isSending = false;


  @override
  void initState() {
    super.initState();
    fetchClasses();
  }

  Future<void> fetchClasses() async {
    final url = '${URL.chatURL}/api/classes/get-classes';
    final res = await http.get(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer ${widget.authToken}'},
    );
    if (res.statusCode == 200) {
      setState(() {
        classes = json.decode(res.body);
      });
    }
  }

  Future<void> sendBroadcast() async {
    final msg = _msgController.text.trim();
    if (msg.isEmpty || selectedClassIds.isEmpty) return;

    setState(() => isSending = true);

    final response = await http.post(
      Uri.parse('${URL.chatURL}/api/classes/broadcast-message'),
      headers: {
        'Authorization': 'Bearer ${widget.authToken}',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'senderId': widget.userId,
        'senderRole': widget.userRole,
        'message': msg,
        'classIds': selectedClassIds.toList(),
      }),
    );

    setState(() => isSending = false);

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Message sent to selected classes.')),
      );
      _msgController.clear();
      selectedClassIds.clear();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send broadcast.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Broadcast Message')),
    body: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text('Select Classes:', style: TextStyle(fontWeight: FontWeight.bold)),
          Expanded(
            child: ListView.builder(
              itemCount: classes.length,
              itemBuilder: (context, i) {
                final c = classes[i];
                final classId = c['classId'] ?? c['id'] ?? c['_id'];
                final name = c['className'] ?? c['name'] ?? '';
                return CheckboxListTile(
                  value: selectedClassIds.contains(classId),
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        selectedClassIds.add(classId);
                      } else {
                        selectedClassIds.remove(classId);
                      }
                    });
                  },
                  title: Text(name),
                );
              },
            ),
          ),
          TextField(
            controller: _msgController,
            decoration: InputDecoration(hintText: 'Type your broadcast message'),
            maxLines: 3,
          ),
          SizedBox(height: 10),
          ElevatedButton(
            onPressed: isSending ? null : sendBroadcast,
            child: isSending ? CircularProgressIndicator() : Text('Send Broadcast'),
          ),
        ],
      ),
    ),
  );
}
