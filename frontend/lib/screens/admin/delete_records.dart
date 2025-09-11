import 'package:flutter/material.dart';
import 'package:frontend/controllers/class_controller.dart';
import 'package:frontend/controllers/payment_controller.dart';
import 'package:frontend/provider/auth_provider.dart';
import 'package:provider/provider.dart';

class DeleteRecords extends StatefulWidget {
  const DeleteRecords({super.key});

  @override
  State<DeleteRecords> createState() => _DeleteRecordsState();
}

class _DeleteRecordsState extends State<DeleteRecords> {
  String? selectedMonth;
  int? selectedYear;
  String? selectedClass;
  // List<String> months = ['January', 'February', 'March', 'April', 'May',
  //   'June', 'July', 'August', 'September', 'October', 'November', 'December'];

  late List<String> months;
  late List<int> years ;
  late List<String> classes =[];

  late final token = Provider.of<AuthProvider>(context, listen:false).token;
  
  @override
  void initState(){
    years= [];
    months= [];

    super.initState();

    fetchYears();
    fetchClass();
  }

  void fetchYears() async {
    // print("Fetching Years");
    var fetchedYears = await GetFeesController.getYears(token);
    setState(() {
      years = [0,...fetchedYears];
      if (selectedYear == null || !years.contains(selectedYear)) {
        selectedYear = years.isNotEmpty ? years.first : null;
        if (selectedYear != 0) fetchMonthByYear(selectedYear);
      }
    });
  }

  void fetchMonthByYear(int? year) async {
    if (year == null || year == 0) {
      setState(() {
        months = ["None"];
        selectedMonth = "None";
      });
      return;
    }
    // print("Fetching Months");
    var fetchedMonths = await GetFeesController.getMonthsByYear(token, year);
    setState(() {
      months = ["None", ...fetchedMonths];
      if (selectedMonth == null || !months.contains(selectedMonth)) {
        selectedMonth = months.first;
      }
    });
  }

  void fetchClass() async {
    // print("Fetching Classes");
    var fetchClass = await ClassController.getClasses(token);
    setState(() {
      classes = ["None", ...fetchClass];
      if (selectedClass == null || !classes.contains(selectedClass)) {
        selectedClass = classes.first;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Delete Records"),

      ),
      body: Container(
        margin : EdgeInsets.all(20.0),
        padding: EdgeInsets.all(10),
        child: Column(
          children: [
            DropdownButton<String>(
              hint: Text("Select Class"),
              value: selectedClass,
              onChanged: (String? newValue){
                setState(() {
                  selectedClass = newValue;
                });
              },
              items: classes.map((String classId) {
                return DropdownMenuItem<String>(
                    value: classId,
                    child: Text(classId)
                );
              }).toList(),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                DropdownButton<int>(
                  hint: Text("Select Year"),
                  value: selectedYear,
                  onChanged: (int? newValue){
                    setState(() {
                      selectedYear = newValue;
                      fetchMonthByYear(selectedYear);
                    });
                  },
                  items: years.map((int year) {
                    return DropdownMenuItem<int>(
                      value: year,
                      child: Text(year.toString())
                    );
                  }).toList(),
                ),
                SizedBox(width: 20,),
                DropdownButton<String>(
                  hint: Text("Select Month"),
                  value: selectedMonth,
                  onChanged: (String? newValue){
                    setState(() {
                      selectedMonth = newValue;
                    });
                  },
                  items: months.map((String month) {
                    return DropdownMenuItem<String>(
                      value: month,
                      child: Text(month[0].toUpperCase()+month.substring(1)),
                    );
                  }).toList(),
                ),
                SizedBox(width: 10,),
              ],
            ),
            SizedBox(height: 10,),
            ElevatedButton(onPressed: () {
              GetFeesController.deletePaymentRecord(token, selectedYear, selectedMonth, selectedClass).then((value) {
                if(value ==0 ){
                  // print("No data matched");
                } else if(value > 0){
                  // print("$value deleted");
                }
                  else {
                  // print("Error Occurred");
                }
              },).catchError((error){
                // print("Error deleting record $error");
              });
            }, child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("Delete Records", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),),
                SizedBox(width: 10,),
                Icon(Icons.delete_rounded, size: 20,)
              ],
            ))
          ],
        ),
      )
    );
  }
}
