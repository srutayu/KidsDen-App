import 'package:flutter/material.dart';
import 'package:frontend/controllers/admin_user_request_controller.dart';
import 'package:frontend/models/user_request_model.dart';
import 'package:frontend/provider/auth_provider.dart';
import 'package:frontend/screens/widgets/toast_message.dart';
import 'package:provider/provider.dart';

class MemberRequest extends StatefulWidget {
  const MemberRequest({super.key});

  @override
  State<MemberRequest> createState() => _MemberRequestState();
}

class _MemberRequestState extends State<MemberRequest> {
  List<UserRequest> _requests = [];
  bool _isLoading = true;
  String? _error;

  late final token = Provider.of<AuthProvider>(context, listen: false).token;

  @override
  void initState() {
    super.initState();
    fetchRequests();
  }

  Future<void> fetchRequests() async {
    try {
      // print(token);
      List<UserRequest> requests =
          await AdminRequestController.getAllRequests(token);
      setState(() {
        _requests = requests;
        _isLoading = false;
        _error = null;
      });
    } catch (error) {
      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Text('Error: $_error'),
      );
    }

    return Scaffold(
      appBar: AppBar(
          automaticallyImplyLeading: false, title: Text("Member Requests")),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
  onRefresh: fetchRequests,
  child: _requests.isEmpty
      ? ListView( // Must be scrollable for RefreshIndicator
          children: const [
            SizedBox(height: 200),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox_outlined, size: 80, color: Colors.grey),
                  SizedBox(height: 20),
                  Text(
                    "No pending requests",
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        )
      : ListView.builder(
          itemCount: _requests.length,
          itemBuilder: (context, index) {
            final user = _requests[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Row 1: Name + Role
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Text(
                          "Name: ${user.name}",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 20),
                        Text(
                          "Role: ${user.role[0].toUpperCase() + user.role.substring(1)}",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Row 2: Approve + Reject Buttons
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 20,
                      runSpacing: 10,
                      children: [

                        //card approve button
                        ElevatedButton.icon(
                          onPressed: () {
                            AdminRequestController.approveSingleUser(
                              user.id,
                              true,
                              token,
                            ).then((value) {
                              if (value) {
                                showToast('${user.name} Approved');
                                setState(() {
                                  _requests.removeWhere(
                                      (element) => element.id == user.id);
                                });
                              } else {
                                print("Not Approved");
                              }
                            }).catchError((error) {
                              print("Error occurred : $error");
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.check_circle),
                          label: const Text("Approve"),
                        ),

                        //card reject button
                        ElevatedButton.icon(
                          onPressed: () {
                            AdminRequestController.approveSingleUser(
                              user.id,
                              false,
                              token,
                            ).then((value) {
                              if (value) {
                                AdminRequestController.deleteUser(
                                  user.id,
                                  token,
                                ).then((value) {
                                  if (value) {
                                    showToast('${user.name} rejected and deleted');
                                  }
                                }).catchError((errors) {
                                  print("Error deleting user: $errors");
                                });
                                setState(() {
                                  _requests.removeWhere(
                                      (element) => element.id == user.id);
                                });
                              } else {
                                showToast("Not Rejected");
                              }
                            }).catchError((error) {
                              print("Error occurred : $error");
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.cancel_rounded),
                          label: const Text("Reject"),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
),

          ),
          Container(
              height: 81,
              color: Colors.teal,
              padding: EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // print("Approving All the Requests");
                        AdminRequestController.approveAllUser(token).then(
                          (value) {
                            if (value) {
                              if (_requests.isEmpty) {
                                showToast('No pending requests!');
                              } else {
                                showToast("All requests are approved");
                                setState(() {
                                  _requests.clear();
                                });
                              }
                            }
                          },
                        ).catchError((error) {
                          print("Error Approving all requests: $error");
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.approval_outlined),
                      label: const Text("Approve All"),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // print("Rejecting All the Requests");
                        AdminRequestController.rejectAllUsers(token).then(
                          (value) {
                            if (value) {
                              if (_requests.isEmpty) {
                                showToast('No pending requests!');
                              } else {
                                showToast("All requests are rejected");
                                setState(() {
                                  _requests.clear();
                                });
                              }
                            }
                          },
                        ).catchError((error) {
                          print("Error Rejecting all the Requests: $error");
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.cancel_presentation),
                      label: const Text("Reject All"),
                    ),
                  ),
                ],
              ))
        ],
      ),
    );
  }
}
