import 'dart:convert';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:frontend/constants/url.dart';
import 'package:frontend/controllers/auth_controller.dart';
import 'package:frontend/controllers/classroom_controller.dart';
import 'package:frontend/controllers/teacher_controller.dart';
import 'package:frontend/models/classroom_model.dart';
import 'package:frontend/provider/auth_provider.dart';
import 'package:frontend/provider/user_data_provider.dart';
import 'package:frontend/screens/widgets/toast_message.dart';
import 'package:frontend/services/text_formatting.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

class Section {
  String heading;
  String body;
  final TextEditingController controller = TextEditingController();

  Section({this.heading = '', this.body = ''});
}


class DailyClassUpdatePage extends StatefulWidget {
  const DailyClassUpdatePage({super.key});
  
   

  @override
  State<DailyClassUpdatePage> createState() => _DailyClassUpdatePageState();
}

class _DailyClassUpdatePageState extends State<DailyClassUpdatePage> {
  List classes = [];
   List<ClassroomModel> _classes = [];
  ClassroomModel? _selectedClass;
  Set<String> selectedClassIds = {};
  late final userId = Provider.of<UserProvider>(context, listen: false).user!.id;
  late final userRole =  Provider.of<UserProvider>(context, listen: false).user!.role;
  late final String username = Provider.of<UserProvider>(context, listen: false).user!.name;
  final ClassroomController _controllerAdmin = ClassroomController();
  final TeacherController _controllerTeacher = TeacherController();
  late String token;


  @override
  void initState() {
    super.initState();
    token = Provider.of<AuthProvider>(context, listen: false).token!;
    _initializeData();
    for (final section in _sections) {
      section.controller.addListener(() {
        _autoAddBullets(section);
      });
    }
  }

   Future<void> _initializeData() async {
    final role = await AuthController.getRole(token);
    if (role == 'admin') {
      try {
        final classes = await _controllerAdmin.getAllClasses(token);
        setState(() {
          _classes = classes;
        });
      }
      catch (e){
        showToast('Failed to load classes: $e');
      }
    } else if (role == 'teacher') {
      try {
        final classes = await _controllerTeacher.getAllClasses(token);
        setState(() {
          _classes = classes;
        });
      } catch (e) {
        showToast('Failed to load classes: $e');
      }
    }
  }
 

  void _autoAddBullets(Section section) {
  var text = section.controller.text;
  
   // 🔹 Add a bullet at the very start if not already there
  if (text.isNotEmpty && !text.trimLeft().startsWith('•')) {
    text = '• $text';
    section.controller
      ..text = text
      ..selection = TextSelection.fromPosition(
        TextPosition(offset: text.length),
      );

    section.body = text;
  }

  // If user just pressed Enter (i.e. last char is \n)
  if (text.isNotEmpty && text.endsWith('\n')) {
    final newText = '$text• ';
    section.controller
      ..text = newText
      ..selection = TextSelection.fromPosition(
        TextPosition(offset: newText.length),
      );

    setState(() {
      section.body = newText;
    });
  }
}

  /// List of all rows on the page
  final List<Section> _sections = [Section()];

  /// Add a new empty row
  void _addRow() {
    final newSection = Section();
    newSection.controller.addListener(() {
      _autoAddBullets(newSection);
    });
    setState(() => _sections.add(newSection));
  }

  /// Delete a specific row
  void _removeRow(int index) {
    setState(() => _sections.removeAt(index));
  }

  /// Build and format the final message
  void _sendFormattedMessage() async {

  if (_selectedClass == null){
    showToast("No class selected");
    return;
  }
  final buffer = StringBuffer();
  buffer.writeln("Today's Work\n");

  for (final section in _sections) {
    if (section.heading.trim().isNotEmpty || section.body.trim().isNotEmpty) {
      buffer.writeln("**__${section.heading.toUpperCase()}__**");
      buffer.writeln(section.body.trim());
      buffer.writeln('');
    }
  }

  buffer.writeln("Regards,\n$username");

  final formattedMessage =  buffer.toString().trim();

  if (formattedMessage.isEmpty) {
    showToast('No message composed');
    return;
  }

  // 🔹 Show preview + confirmation dialog
  final shouldSend = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Preview Message'),
      content: SingleChildScrollView(
        child: Text(
          stripFormatting(buffer.toString().trim()),
          style: const TextStyle(height: 1.4),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: () => Navigator.pop(context, true),
          icon: const Icon(Icons.send, size: 18),
          label: const Text('Send'),
        ),
      ],
    ),
  );

  // 🔹 Cancel if user pressed "Cancel" or closed the dialog
  if (shouldSend != true) return;

  // 🔹 Proceed to send request
  try {
    final response = await http.post(
      Uri.parse('${URL.chatURL}/classes/broadcast-message'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'senderId': userId,
        'senderRole': userRole,
        'message': formattedMessage,
        'classIds': selectedClassIds.toList(),
      }),
    );

    if (response.statusCode == 200) {
      showToast('✅ Update sent to selected classes.');
    } else {
      showToast('Failed to send update');
    }
  } catch (e) {
    showToast(' Error sending update.');
  }
}


  /// Build each (heading + body) row
  Widget _buildRow(int index) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Heading field
        Expanded(
          flex: 3,
          child: TextField(
            decoration: const InputDecoration(
              labelText: 'Heading',
              border: OutlineInputBorder(),
            ),
            onChanged: (val) => _sections[index].heading = val,
          ),
        ),
        const SizedBox(width: 12),
        // Body field
        Expanded(
          flex: 5,
          child: TextField(
            controller: _sections[index].controller,
            maxLines: null,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            decoration: const InputDecoration(
              labelText: 'Details',
              hintText: 'Write update here...',
              border: OutlineInputBorder(),
            ),
            onChanged: (val) => _sections[index].body = val,
          ),
        ),

        const SizedBox(width: 8),
        // Delete button
        if (_sections.length > 1)
          IconButton(
            onPressed: () => _removeRow(index),
            icon: const Icon(Icons.delete_forever_outlined, color: Colors.red,),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Class Update'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [DropdownButtonHideUnderline(
              child: DropdownButton2<ClassroomModel>(
                isExpanded: true,
                value: _selectedClass,
                hint: Text(
                'Select Class',
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey.shade400 // softer grey for dark mode
                      : Colors.grey.shade600, // darker grey for light mode
                ),
              ),
              items: _classes.map((cls) {
                return DropdownMenuItem(
                  value: cls,
                  child: Text(
                    cls.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black87,
                    ),
                  ),
                );
                }).toList(),
                onChanged: (cls) {
                  if (cls != null) {
                    selectedClassIds.clear();
                    selectedClassIds.add(cls.id);
                    setState(() {
                      _selectedClass = cls;
                    });
                  }
                },
                buttonStyleData: ButtonStyleData(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF2A2A2A)
                      : const Color(0xFFF7F7F7),
                  border: Border.all(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey.shade700
                        : Colors.grey.shade300,
                  ),
                ),
              ),
               dropdownStyleData: DropdownStyleData(
                maxHeight: 300,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF1E1E1E)
                      : Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.black45
                          : Colors.grey.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
              ),
              ),
            ),
            const SizedBox(height: 20,),
            for (int i = 0; i < _sections.length; i++) ...[
              _buildRow(i),
              const SizedBox(height: 16),
            ],
            OutlinedButton.icon(
              onPressed: _addRow,
              icon: const Icon(Icons.add),
              label: const Text("Add Row"),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _sendFormattedMessage,
              icon: const Icon(Icons.send),
              label: const Text('Send Update'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
