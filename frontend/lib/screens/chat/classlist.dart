import 'package:flutter/material.dart';
import 'package:frontend/constants/url.dart';
import 'package:frontend/provider/user_data_provider.dart';
import 'package:frontend/screens/chat/broadcast_screen.dart';
import 'package:frontend/screens/widgets/greetingWidget.dart';
import 'package:provider/provider.dart';
import 'chat_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ClassListScreen extends StatefulWidget {
  final String authToken; 
  ClassListScreen({required this.authToken});

  @override
  _ClassListScreenState createState() => _ClassListScreenState();
}

class _ClassListScreenState extends State<ClassListScreen> {
  List classes = [];
  bool isLoading = true;

  late String userId = Provider.of<UserProvider>(context, listen: false).user!.id;
  late String role = Provider.of<UserProvider>(context, listen: false).user!.role;
  late final String username = Provider.of<UserProvider>(context, listen: false).user!.name;


  @override
  void initState() {
    super.initState();
    fetchClasses();
  }

  Future<void> fetchClasses() async {
    try {
      // print("Token: ${widget.authToken}");
      final url = Uri.parse('${URL.chatURL}/api/classes/get-classes');
      final res = await http.get(url,
        headers: {'Authorization': 'Bearer ${widget.authToken}'});

      print("StatusCode: ${res.statusCode}");
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        setState(() {
          classes = data;
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      print('Fetch classes error: ${e.toString()}');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  String getInitials(String name) {
    final parts = name.split(' ');
    if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  final List<Color> cardColors = [
  Colors.blue.shade100,
  Colors.green.shade100,
  Colors.pink.shade100,
  Colors.orange.shade100,
  Colors.purple.shade100,
  Colors.teal.shade100,
  Colors.amber.shade100,
  Colors.red.shade100,
];

  @override
  Widget build(BuildContext context) => Scaffold(
    body: isLoading
            ? Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  GreetingWidget(username: username),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        if (role == "teacher" || role == "admin") ...[
                          Text(
                            'Classrooms',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          FilledButton(
                            onPressed: () {
                              Navigator.push(context, MaterialPageRoute(
                                builder: (context) {
                                  return BroadcastScreen(
                                    authToken: widget.authToken,
                                    userId: userId,
                                    userRole: role,
                                  );
                                },
                              ));
                            },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.campaign),
                                SizedBox(width: 8),
                                Text("Broadcast"),
                              ],
                            ),
                          ),
                        ] else ...[
                          Expanded(
                            child: Center(
                              child: Text(
                                'Classrooms',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ]
                      ],
                    ),
                  ),
                  Expanded(
                    child: GridView.builder(
                      padding: EdgeInsets.all(12),
                      itemCount: classes.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2, // 2 cards in a row
                        crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 3 / 2,
              ),
              itemBuilder: (_, index) {
                final cls = classes[index];
                final classId = cls['classId'] ?? cls['id'] ?? cls['_id'];
                final className = cls['className'] ?? cls['name'] ?? '';
                // final initials = getInitials(className);

                return GestureDetector(
                  onTap: () {
                    if (classId != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            authToken: widget.authToken,
                            classId: classId,
                            className: className,
                          ),
                        ),
                      );
                    }
                  },
                  child: Card(
                    color: cardColors[index % cardColors.length],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          className,
                          style: TextStyle(
                            fontSize: 16, 
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
