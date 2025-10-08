import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:frontend/constants/url.dart';
import 'package:frontend/controllers/class_controller.dart';
import 'package:frontend/controllers/fees_controller.dart';
import 'package:frontend/controllers/payment_controller.dart';
import 'package:frontend/models/payment_model.dart';
import 'package:frontend/provider/auth_provider.dart';
import 'package:http/http.dart' as http;
import 'package:month_year_picker/month_year_picker.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

class CombinedFeesPaymentsPage extends StatelessWidget {
  const CombinedFeesPaymentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final token = Provider.of<AuthProvider>(context, listen: false).token;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Fees & Payment Records"),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Update Fees", style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            UpdateFeesContent(token: token!),
            const Divider(thickness: 2, height: 40),
            Text("Payment Records",
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
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
  String? selectedClass;
  List<String> classes = [];
  final TextEditingController _amountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchClasses();
  }

  Future<void> fetchClasses() async {
    try {
      final value = await FeesController.getAllClasses(widget.token);
      setState(() => classes = value);
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
        selectedClass,
        _amountController.text,
        widget.token,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(value ? "Successfully Fees Updated" : "Error occurred")),
      );
    } catch (e) {
      debugPrint("Error updating fees: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        DropdownButton<String>(
          hint: const Text("Select Class"),
          value: selectedClass,
          onChanged: (value) {
            setState(() => selectedClass = value);
            if (value != null) fetchFeesForClass(value);
          },
          items: classes
              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
              .toList(),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _amountController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: "Fees Amount",
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () {
            if (selectedClass != null && _amountController.text.isNotEmpty) {
              updateFees();
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text("Please select a class and enter amount")),
              );
            }
          },
          child: const Text("Update Fees"),
        ),
      ],
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

  String? selectedClass;
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

  List<String> classes = [];

  final Map<String, String> _userNameCache = {};

  @override
  void initState() {
    super.initState();
    fetchClasses();
  }

  void fetchClasses() async {
    List<String> fetchedClasses =
        await ClassController.getClasses(widget.token);
    
    if (!mounted) return;
    
    setState(() {
      classes = fetchedClasses;
      if (classes.isNotEmpty) {
        selectedClass = classes[0];
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
    if (selectedClass == null) return;

    setState(() => loading = true);

    final year = selectedDate.year.toString();
    final monthNumber = selectedDate.month;
    final monthName = PaymentModel.getMonthName(monthNumber);

    final url = Uri.parse(
        '$_baseURL/admin/get-status?classId=$selectedClass&year=$year&month=$monthName');

    try {
      final response = await http.get(url, headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${widget.token}',
      });

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

        // listOfUnpaidStudents = studentsRaw['unpaid'] ?? [];

        final namedStudents = await fetchStudentsWithNames(studentsRaw);
        // print(namedStudents);

        setState(() {
          statusCounts['paid'] = counts['paid'] ?? 0;
          statusCounts['pending'] = counts['pending'] ?? 0;
          statusCounts['unpaid'] = namedStudents['unpaid']?.length ?? 0;

          studentsByStatus['paid'] = namedStudents['paid']?.values.toList() ?? [];
          studentsByStatus['pending'] = namedStudents['pending']?.values.toList() ?? [];
          studentsByStatus['unpaid'] = namedStudents['unpaid']?.values.toList() ?? [];

          listOfUnpaidStudent = namedStudents['unpaid']!;
          listOfPendingStudent = namedStudents['pending']!;
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
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(0.9)),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        selectedDate = DateTime(picked.year, picked.month);
      });
      await fetchPaymentStatus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalCount = statusCounts.values.fold(0, (sum, val) => sum + val);

    if (classes.isEmpty || loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        DropdownButton<String>(
          value: selectedClass,
          onChanged: (value) {
            if (value != null) {
              setState(() => selectedClass = value);
              fetchPaymentStatus();
            }
          },
          items: classes
              .map((cls) => DropdownMenuItem(value: cls, child: Text(cls)))
              .toList(),
          hint: const Text('Select Class'),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Text(
                'Month: ${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}'),
            const SizedBox(width: 10),
            ElevatedButton(
                onPressed: pickMonth, child: const Text('Select Month')),
          ],
        ),
        const SizedBox(height: 20),
        if (totalCount > 0)
          SizedBox(
            height: 250,
            child: SfCircularChart(
              legend: Legend(
                  isVisible: true, overflowMode: LegendItemOverflowMode.wrap),
              tooltipBehavior: TooltipBehavior(enable: true),
              series: <PieSeries<StatusData, String>>[
                PieSeries<StatusData, String>(
                  dataSource: [
                    StatusData('Paid', statusCounts['paid'] ?? 0, Colors.green),
                    StatusData(
                        'Pending', statusCounts['pending'] ?? 0, Colors.orange),
                    StatusData(
                        'Unpaid', statusCounts['unpaid'] ?? 0, Colors.red),
                  ].where((e) => e.count > 0).toList(),
                  xValueMapper: (StatusData data, _) => data.status,
                  yValueMapper: (StatusData data, _) => data.count,
                  pointColorMapper: (StatusData data, _) => data.color,
                  dataLabelMapper: (StatusData data, _) =>
                      '${data.status}: ${data.count}',
                  dataLabelSettings: const DataLabelSettings(isVisible: true),
                  enableTooltip: true,
                ),
              ],
            ),
          )
        else
          const Text('No payment data for this month and class'),
        const SizedBox(height: 20),
        buildPaidStudentList('Paid Students', studentsByStatus['paid']!),
        buildStudentList('Pending Students', listOfPendingStudent),
        buildStudentList('Unpaid Students', listOfUnpaidStudent),
      ],
    );
  }

  Widget buildPaidStudentList(String title, List<String> students) {
    return ExpansionTile(
      title: Text('$title (${students.length})'),
      children: students.isEmpty
          ? [const ListTile(title: Text('No students'))]
          : students.map((name) => ListTile(title: Text(name))).toList(),
    );
  }

  Widget buildStudentList(String title, Map<String, String> students) {
    return ExpansionTile(
      title: Text('$title (${students.length})'),
      children: students.isEmpty ? [const ListTile(title: Text('No students'))] : students.entries.map(
              (entry) => ListTile(
            title: Text(entry.value),
            trailing: TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  backgroundColor: Colors.green.shade100,
                ),
                onPressed: () {
                  String monthName = PaymentModel.getMonthName(selectedDate.month);
                  monthName = monthName.substring(0, 1).toLowerCase() + monthName.substring(1);
                  GetFeesController.updateCashPayment(widget.token,monthName, selectedDate.year.toString(), entry.key).then((value) {
                    if(value) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Cash Taken Successfully")),
                      );
                      fetchPaymentStatus();
                    }
                  },);
                }, child: const Text("Cash Taken", style: TextStyle(color: Colors.green),)),
          ))
          .toList(),
    );
  }
}

class StatusData {
  final String status;
  final int count;
  final Color color;

  StatusData(this.status, this.count, this.color);
}
