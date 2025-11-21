import 'dart:convert';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:frontend/constants/url.dart';
import 'package:frontend/controllers/class_controller.dart';
import 'package:frontend/controllers/fees_controller.dart';
import 'package:frontend/controllers/payment_controller.dart';
import 'package:frontend/models/classroom_model.dart';
import 'package:frontend/models/payment_model.dart';
import 'package:frontend/provider/auth_provider.dart';
import 'package:frontend/screens/widgets/toast_message.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:month_year_picker/month_year_picker.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

class CombinedFeesPaymentsPage extends StatelessWidget {
  const CombinedFeesPaymentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final token = Provider.of<AuthProvider>(context, listen: false).token;

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            UpdateFeesContent(token: token!),
            const Divider(thickness: 2, height: 40),
            PaymentRecordsContent(token: token),
          ],
        ),
      ),
    );
  }
}

//
// --------------------- UPDATE FEES CONTENT ---------------------
//
class UpdateFeesContent extends StatefulWidget {
  final String token;
  const UpdateFeesContent({super.key, required this.token});

  @override
  State<UpdateFeesContent> createState() => _UpdateFeesContentState();
}

class _UpdateFeesContentState extends State<UpdateFeesContent> {
  String? selectedClassId;
  String? selectedClassName;

  List<ClassroomModel> classes = [];
  final TextEditingController _amountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchClasses();
  }

  Future<void> fetchClasses() async {
    try {
      final value = await ClassController.getClasses(widget.token);
      setState(() => classes = value);
      print(classes);
    } catch (e) {
      debugPrint("Error Occurred While fetching classes: $e");
    }
  }

  Future<void> fetchFeesForClass(String classId) async {
    try {
      final value = await FeesController.getFees(classId, widget.token);
      setState(() => _amountController.text = value.toString());
    } catch (e) {
      debugPrint("Error fetching fees: $e");
    }
  }

  Future<void> updateFees() async {
    try {
      final value = await FeesController.updateFeesAmountByClassId(
        selectedClassId!,
        _amountController.text,
        widget.token,
      );

     showToast(value ? "Fees updated for $selectedClassName to ₹${_amountController.text}" : "Error occurred");
    } catch (e) {
      debugPrint("Error updating fees: $e");
    }
  }

  @override
 Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: Card(
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        color: theme.cardColor,
        shadowColor: theme.shadowColor.withOpacity(0.2),
        margin: const EdgeInsets.all(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Update Class Fees",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? Colors.white
                      : Colors.black, // accent adapts
                ),
              ),
              const SizedBox(height: 25),

              // Dropdown with border
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isDark ? Colors.white24 : Colors.grey.shade400,
                  ),
                  borderRadius: BorderRadius.circular(15),
                  color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton2<ClassroomModel>(
                    hint: Text(
                      "Select Class",
                      style: TextStyle(
                        fontSize: 16,
                        color: isDark
                            ? Colors.grey.shade400
                            : Colors.grey.shade700,
                      ),
                    ),

                    //  Selected value is the FULL model
                    value: selectedClassId == null
                        ? null
                        : classes.firstWhere(
                            (c) => c.id == selectedClassId,
                          ),

                    isExpanded: true,

                    dropdownStyleData: DropdownStyleData(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        color:
                            isDark ? Colors.grey.shade800 : Colors.grey.shade50,
                        boxShadow: [
                          BoxShadow(
                            color: isDark
                                ? Colors.black26
                                : Colors.grey.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                    ),

                    // 👇 When user selects a class
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          selectedClassId = value.id; // store ID internally
                          selectedClassName = value.name; // for display
                        });

                        print("Selected Class ID: $selectedClassId");
                        print("Selected Class Name: $selectedClassName");

                        fetchFeesForClass(
                            selectedClassId!); // send ID to backend
                      }
                    },

                    // 👇 Dropdown items
                    items: classes.map((c) {
                      return DropdownMenuItem<ClassroomModel>(
                        value: c,
                        child: Text(
                          c.name,
                          style: TextStyle(
                            fontSize: 16,
                            color:
                                isDark ? Colors.grey.shade200 : Colors.black87,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Amount text field
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                style: TextStyle(
                    color: isDark ? Colors.white : Colors.black, fontSize: 16),
                decoration: InputDecoration(
                  labelText: "Fees Amount",
                  labelStyle: TextStyle(
                      color: isDark
                          ? Colors.grey.shade400
                          : Colors.grey.shade700),
                  prefixIcon: Icon(
                    Icons.currency_rupee_rounded,
                    color: isDark ? Colors.grey.shade400 : Colors.blueAccent,
                  ),
                  filled: true,
                  fillColor:
                      isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide(
                        color: isDark
                            ? theme.colorScheme.primary
                            : Colors.blueAccent,
                        width: 2),
                  ),
                ),
              ),

              const SizedBox(height: 25),

              // Submit button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (selectedClassName != null &&
                        _amountController.text.isNotEmpty) {
                      updateFees();
                    } else {
                      showToast("Please select a class and enter amount");
                    }
                  },
                  icon: Icon(Icons.save_rounded, color: isDark? Colors.black : Colors.white,),
                  label: Text(
                    "Update Fees",
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.black : Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark
                        ? theme.colorScheme.primary
                        : Colors.blueAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    elevation: 4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

//
// --------------------- PAYMENT RECORDS CONTENT ---------------------
//
class PaymentRecordsContent extends StatefulWidget {
  final String token;
  const PaymentRecordsContent({super.key, required this.token});

  @override
  State<PaymentRecordsContent> createState() => _PaymentRecordsContentState();
}

class _PaymentRecordsContentState extends State<PaymentRecordsContent> {
  static final _baseURL = URL.baseURL;

  ClassroomModel? selectedClassModel;
  String? selectedClassName;
  String? selectedClassId;
  DateTime selectedDate = DateTime.now();
  bool loading = false;

  Map<String, int> statusCounts = {'paid': 0, 'pending': 0, 'unpaid': 0};
  Map<String, List<String>> studentsByStatus = {
    'paid': [],
    'pending': [],
    'unpaid': [],
  };

  Map<String, String> listOfUnpaidStudent = {};
  Map<String, String> listOfPendingStudent = {};

  List<ClassroomModel> classes = [];

  final Map<String, String> _userNameCache = {};

  @override
  void initState() {
    super.initState();
    fetchClasses();
  }

  void fetchClasses() async {
    List<ClassroomModel> fetchedClasses =
        await ClassController.getClasses(widget.token);
    
    if (!mounted) return;
    
    setState(() {
      classes = fetchedClasses;
      if (classes.isNotEmpty) {
        selectedClassName = classes[0].name;
        fetchPaymentStatus();
      }
    });
  }

  Future<String> fetchUserNameCached(String userId) async {
    if (userId.isEmpty) return 'Unknown';
    if (_userNameCache.containsKey(userId)) {
      return _userNameCache[userId]!;
    }
    try {
      final url = Uri.parse('$_baseURL/admin/user-name?userId=$userId');
      final response = await http.get(url, headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${widget.token}',
      });

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        String name = data['name'] ?? userId;
        _userNameCache[userId] = name;
        return name;
      } else {
        return userId;
      }
    } catch (e) {
      debugPrint('Exception fetching username for $userId: $e');
      return userId;
    }
  }

  Future<Map<String, Map<String, String>>> fetchStudentsWithNames(
      Map<String, List<String>> studentsById) async {
    final Map<String, Map<String, String>> result = {};
    for (var status in ['paid', 'pending', 'unpaid']) {
      List<String> studentIds = studentsById[status] ?? [];
      Map<String, String> names = {};
      for (var id in studentIds) {
        if (id.isNotEmpty) {
          final name = await fetchUserNameCached(id);
          names[id] = name;
        }
      }
      result[status] = names;
    }
    return result;
  }

 Future<void> fetchPaymentStatus() async {
  if (selectedClassId == null) return;

  if (!mounted) return;
  setState(() => loading = true);

  final year = selectedDate.year.toString();
  final monthNumber = selectedDate.month;
  final monthName = PaymentModel.getMonthName(monthNumber);

  final url = Uri.parse(
    '$_baseURL/admin/get-status?classId=$selectedClassId&year=$year&month=$monthName',
  );

  try {
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${widget.token}',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      final knownStatuses = {'paid', 'pending', 'unpaid'};
      Map<String, int> counts = {'paid': 0, 'pending': 0, 'unpaid': 0};

      for (final item in data['summary'] ?? []) {
        String status = (item['status'] as String?) ?? 'unknown';
        int count = (item['count'] as int?) ?? 0;
        if (knownStatuses.contains(status)) {
          counts[status] = count;
        }
      }

      Map<String, List<String>> studentsRaw = {
        'paid': data['studentsByStatus']?['paid'] != null
            ? (data['studentsByStatus']['paid'] as List)
                .whereType<String>()
                .toList()
            : [],
        'pending': data['studentsByStatus']?['pending'] != null
            ? (data['studentsByStatus']['pending'] as List)
                .whereType<String>()
                .toList()
            : [],
        'unpaid': data['studentsByStatus']?['unpaid'] != null
            ? (data['studentsByStatus']['unpaid'] as List)
                .whereType<String>()
                .toList()
            : [],
      };

      final namedStudents = await fetchStudentsWithNames(studentsRaw);

      if (!mounted) return;
      setState(() {
        statusCounts['paid'] = counts['paid'] ?? 0;
        statusCounts['pending'] = counts['pending'] ?? 0;
        statusCounts['unpaid'] = namedStudents['unpaid']?.length ?? 0;

        studentsByStatus['paid'] =
            namedStudents['paid']?.values.toList() ?? [];
        studentsByStatus['pending'] =
            namedStudents['pending']?.values.toList() ?? [];
        studentsByStatus['unpaid'] =
            namedStudents['unpaid']?.values.toList() ?? [];

          listOfUnpaidStudent = namedStudents['unpaid']!;
          listOfPendingStudent = namedStudents['pending']!;
          // print(listOfPendingStudent);
        });
      } else {
        throw Exception('Failed to load payment status');
      }
    } catch (e) {
      debugPrint("Error fetching payment status: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error fetching payment data')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

 Future<void> pickMonth() async {
  final picked = await showMonthYearPicker(
    context: context,
    initialDate: selectedDate,
    firstDate: DateTime(2020),
    lastDate: DateTime(DateTime.now().year, DateTime.now().month),
    builder: (context, child) {
      return MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(0.9),
        ),
        child: child!,
      );
    },
  );

  if (!mounted) return; // ensure widget is still active

  if (picked != null) {
    setState(() {
      selectedDate = DateTime(picked.year, picked.month);
    });

    if (!mounted) return; // check again before async call
    await fetchPaymentStatus();
  }
}


@override
Widget build(BuildContext context) {
  final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
  final totalCount = statusCounts.values.fold(0, (sum, val) => sum + val);

  if (classes.isEmpty || loading) {
    return const Center(child: CircularProgressIndicator());
  }

  return SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 🔹 Header
        Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                 Center(
                   child: Text(
                    "View Fee Status",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: isDark? Colors.white : Colors.black,
                    ),
                                   ),
                 ),
                const SizedBox(height: 20),

                  // Class Dropdown
                Row(
  children: [
    const Icon(Icons.class_rounded, color: Colors.blueAccent),
    const SizedBox(width: 10),

    Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
          border: Border.all(
            color: isDark ? Colors.white24 : Colors.grey.shade300,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8),

        child: DropdownButtonHideUnderline(
          child: DropdownButton2<ClassroomModel>(
            isExpanded: true,

            /// 🔹 The selected value must be a ClassroomModel
            value: selectedClassModel,

            hint: Text(
              'Select Class',
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
              ),
            ),

            /// 🔹 Dropdown items
            items: classes.map((cls) {
              return DropdownMenuItem<ClassroomModel>(
                value: cls,  // Full ClassroomModel object
                child: Text(
                  cls.name,
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              );
            }).toList(),

            /// 🔹 On change → Set ID + name + model
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  selectedClassModel = value;
                  selectedClassId = value.id;     // store ID
                  selectedClassName = value.name; // store name
                });

                fetchPaymentStatus();  // your function
              }
            },

            // 🔹 Button styling
            buttonStyleData: ButtonStyleData(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              height: 50,
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
            ),

            // 🔹 Dropdown styling
            dropdownStyleData: DropdownStyleData(
              maxHeight: 250,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey : Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: isDark ? Colors.black38 : const Color(0xFFDCDCDC),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
            ),

            iconStyleData: IconStyleData(
              icon: Icon(
                Icons.arrow_drop_down_rounded,
                size: 28,
                color: isDark
                    ? Colors.blueAccent.shade100
                    : Colors.blueAccent,
              ),
            ),

            menuItemStyleData: const MenuItemStyleData(
              height: 48,
              padding: EdgeInsets.symmetric(horizontal: 12),
            ),
          ),
        ),
      ),
    ),
  ],
),


                  const SizedBox(height: 16),

                  // Month selector
                  Center(
                    child: ElevatedButton.icon(
                      onPressed: pickMonth,
                      icon: const Icon(Icons.edit_calendar_rounded),
                      label: Text(
                        'Select Month',
                        style: TextStyle(
                          color:
                              Theme.of(context).brightness == Brightness.dark
                                  ? Colors.white
                                  : Colors.black,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            Theme.of(context).brightness == Brightness.dark
                                ? Colors.blueAccent.shade200
                                : Colors.blueAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 3,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),

        // 🔹 Pie Chart Card
        Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: totalCount > 0
                ? Column(
                    children: [
                       Text(
                        'Payments for ${DateFormat('MMMM yyyy').format(selectedDate)}',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 250,
                        child: SfCircularChart(
                          legend: Legend(
                              isVisible: true,
                              overflowMode: LegendItemOverflowMode.wrap),
                          tooltipBehavior: TooltipBehavior(enable: true),
                          series: <PieSeries<StatusData, String>>[
                            PieSeries<StatusData, String>(
                              dataSource: [
                                StatusData(
                                    'Paid',
                                    statusCounts['paid'] ?? 0,
                                    Colors.green.shade400),
                                StatusData('Pending',
                                    statusCounts['pending'] ?? 0, Colors.orange),
                                StatusData('Unpaid',
                                    statusCounts['unpaid'] ?? 0, Colors.red),
                              ].where((e) => e.count > 0).toList(),
                              xValueMapper: (StatusData data, _) => data.status,
                              yValueMapper: (StatusData data, _) => data.count,
                              pointColorMapper: (StatusData data, _) =>
                                  data.color,
                              dataLabelMapper: (StatusData data, _) =>
                                  '${data.status}: ${data.count}',
                              dataLabelSettings:
                                  const DataLabelSettings(isVisible: true),
                              enableTooltip: true,
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : const Center(
                    child: Text(
                      'No payment data for this month and class',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
          ),
        ),

        const SizedBox(height: 20),

        // 🔹 Paid Students
        buildPaidStudentList('Paid Students', studentsByStatus['paid']!),
        const SizedBox(height: 10),

        // 🔹 Pending Students
        buildStudentList('Pending Students', listOfPendingStudent),
        const SizedBox(height: 10),

        // 🔹 Unpaid Students
        buildStudentList('Unpaid Students', listOfUnpaidStudent),
      ],
    ),
  );
}

Widget buildPaidStudentList(String title, List<String> students) {
  return Card(
    elevation: 3,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: ExpansionTile(
      title: Text(
        '$title (${students.length})',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      children: students.isEmpty
          ? [const ListTile(title: Text('No students'))]
          : students
              .map(
                (name) => ListTile(
                  title: Text(name),
                  leading: const Icon(Icons.person, color: Colors.green),
                ),
              )
              .toList(),
    ),
  );
}

Widget buildStudentList(String title, Map<String, String> students) {
  return Card(
    elevation: 3,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: ExpansionTile(
      title: Text(
        '$title (${students.length})',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      children: students.isEmpty
          ? [const ListTile(title: Text('No students'))]
          : students.entries.map(
              (entry) => ListTile(
                leading: const Icon(Icons.person_outline, color: Colors.blue),
                title: Text(entry.value),
                trailing: TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    backgroundColor: Colors.green.shade100,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    String monthName =
                        PaymentModel.getMonthName(selectedDate.month);
                    monthName = monthName.substring(0, 1).toLowerCase() +
                        monthName.substring(1);
                        
                    GetFeesController.updateCashPayment(
                      widget.token,
                      monthName,
                      selectedDate.year.toString(),
                      entry.key,
                    ).then((value) {
                      if (value) {
                        showToast('Cash taken for ${entry.value}');
                        fetchPaymentStatus();
                      }
                    });
                  },
                  child: const Text(
                    "Cash Taken",
                    style: TextStyle(color: Colors.green),
                  ),
                ),
              ),
            ).toList(),
    ),
  );
}

}

class StatusData {
  final String status;
  final int count;
  final Color color;

  StatusData(this.status, this.count, this.color);
}
