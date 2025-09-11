import 'package:flutter/material.dart';
import 'package:frontend/controllers/admin_user_request_controller.dart';
import 'package:frontend/models/user_request_model.dart';
import 'package:frontend/provider/auth_provider.dart';
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

  late final token = Provider.of<AuthProvider>(context, listen:false).token;

  @override
  void initState(){
    super.initState();
    fetchRequests();
  }

  Future<void> fetchRequests() async{
    try {
      // print(token);
      List<UserRequest> requests = await AdminRequestController.getAllRequests(token);
      setState(() {
        _requests = requests;
        _isLoading = false;
        _error = null;
      });
    } catch(error) {
      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }
  @override
  Widget build(BuildContext context) {
    if(_isLoading){
      return Center(
        child: CircularProgressIndicator(),
      );
    }

    if(_error != null){
      return Center(child: Text('Error: $_error'),);
    }

    return Scaffold(
      appBar: AppBar(
          title: Text("Member Requests")
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              child: Center(
                child: ListView.builder(itemCount: _requests.length, itemBuilder: (context, index) {
                  final user = _requests[index];
                  return Container(
                    child: Column(
                      children: [
                        Row(//Row 1
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(user.name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),),
                            SizedBox(width: 20,),
                            Text(user.role[0].toUpperCase()+user.role.substring(1), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),)
                          ],
                        ),
                        Row( //Row 2
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton(onPressed: () {
                              // print("${user.name} is Approved");

                              AdminRequestController.aproveSingleUser(user.id, true, token).then((value) {
                                if(value){
                                  print("User Approved successfully");
                                  setState(() {
                                    _requests.removeWhere((element) => element.id == user.id,);
                                  });
                                }
                                else {
                                  print("Not Approved");
                                }
                              },).catchError((error){
                                print("Error occurred : $error");
                              });
                            }, style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.black
                            ), child: Row(
                              children: [
                                Text("Approve"),
                                SizedBox(width: 10,),
                                Icon(Icons.approval_outlined)
                              ],
                            ),),
                            SizedBox(width: 40,),
                            ElevatedButton(onPressed: () {
                              // print("${user.name} is Rejected");
                              AdminRequestController.aproveSingleUser(user.id, false, token).then((value) {
                                if(value){
                                  AdminRequestController.deleteUser(user.id, token).then((value) {
                                    if(value) {
                                      print("User Rejected and Deleted");
                                    }
                                  },).catchError((errors){
                                    print("error deleting user: $errors");
                                  });
                                  print("User Rejected successfully");
                                  setState(() {
                                    _requests.removeWhere((element) => element.id == user.id,);
                                  });
                                }
                                else {
                                  print("Not Rejected");
                                }
                              },).catchError((error){
                                print("Error occurred : $error");
                              });
                            }, style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.black
                            ), child: Row(
                              children: [
                                Text("Rejected"),
                                SizedBox(width: 10,),
                                Icon(Icons.cancel_outlined)
                              ],
                            ),),
                          ],
                        ),
                        SizedBox(height: 20,)
                      ],
                    ),
                  );
                },)
              ),
            ),
          ),
          Container(
            height: 81,
            color: Colors.teal,
            padding: EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(onPressed: () {
                  // print("Approving All the Requests");
                  AdminRequestController.approveAllUser(token).then((value) {
                    if(value) {
                      print("All requests are approved");
                      setState(() {
                        _requests.clear();
                      });
                    }
                  },).catchError((error){
                    print("Error Approving all requests: $error");
                  });
                }, child: Row(
                  children: [
                    Text("Approve All"),
                    SizedBox(width: 20,),
                    Icon(Icons.approval_outlined)
                  ],
                )),
                SizedBox(width: 30,),
                ElevatedButton(onPressed: () {
                  // print("Rejecting All the Requests");
                  AdminRequestController.rejectAllUsers(token).then((value) {
                    if(value){
                      print("All Requests are rejected");
                      setState(() {
                        _requests.clear();
                      });
                    }
                  },).catchError((error){
                    print("Error Rejecting all the Requests: $error");
                  });
                }, child: Row(
                  children: [
                    Text("Reject All"),
                    SizedBox(width: 20,),
                    Icon(Icons.cancel_presentation)
                  ],
                ))
              ],
            ),
          )
        ],
      ),
    );
  }
}
