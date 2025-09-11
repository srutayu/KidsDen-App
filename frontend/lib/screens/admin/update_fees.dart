import 'package:flutter/material.dart';
import 'package:frontend/controllers/fees_controller.dart';
import 'package:frontend/provider/auth_provider.dart';
import 'package:provider/provider.dart';

class UpdateFees extends StatefulWidget {
  const UpdateFees({super.key});

  @override
  State<UpdateFees> createState() => _UpdateFeesState();
}

class _UpdateFeesState extends State<UpdateFees> {


  String? selectedClass;
  List<String> classes = [];
  final TextEditingController _amountController = TextEditingController();

  late final token = Provider.of<AuthProvider>(context, listen:false).token;

  @override
  void initState(){
    super.initState();
    fetchClasses();
  }

  Future<void> fetchClasses() async {
    // Fetch and set classes list, e.g. from backend
    FeesController.getAllClasses(token).then((value) {
      setState(() {
        classes = value;
      });
    },).catchError((error){
      // print("Error Occurred While fetching classes, $error");
    });
  }

  Future<void> fetchFeesForClass(String classId) async {
    // Call backend to get fees for classId
    // Then set controller value:
    // _amountController.text = fetchedAmount.toString();

    FeesController.getFees(classId, token).then((value) {
      setState(() {
        _amountController.text = value.toString();
      });
    },).catchError((error){
      // print("Error occurred $error");
    });
  }

  Future<void> updateFees() async {
    // Call backend to update fees with selectedClass and amount e.g.:
    // POST /fees/update {classId, amount}
    // Handle success/failure, show message

    FeesController.updateFeesAmountByClassId(selectedClass, _amountController.text, token).then((value) {
      if(value){
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Successfully Fees Updated"),));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error occurred"),));
      }
    },).catchError((error){
      // print("Error occurred: $error");
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text("Update Fees"),
      ),
      body: Padding(padding: EdgeInsets.all(6),
      child: Column(
        children: [
          DropdownButton<String>(
            hint: Text("Select Class"),
            value: selectedClass,
            onChanged: (value) {
              setState(() {
                selectedClass = value;
              });
              if(value!= null) {
                fetchFeesForClass(value);
              }
            },
            items: classes.map((c) => DropdownMenuItem(value: c,child: Text(c),)).toList(),
            ),
          SizedBox(height: 16,),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: "Fees Amount",
              border: OutlineInputBorder(),
            ),
          ),
          SizedBox(height: 16,),
          ElevatedButton(onPressed: () {
            if(selectedClass!= null && _amountController.text.isNotEmpty){
              updateFees();
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Please select a class and enter amount"),));
            }
          }, child: Text("Update Fees"))
        ],
      ),),
    );
  }
}
