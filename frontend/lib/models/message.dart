import 'package:hive/hive.dart';

part 'message.g.dart';

@HiveType(typeId: 1)
class Message extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String classId;

  @HiveField(2)
  final String sender;

  @HiveField(3)
  final String content;

  @HiveField(4)
  final String timestamp;

  Message({
    required this.id,
    required this.classId,
    required this.sender,
    required this.content,
    required this.timestamp,
  });

  // Helper: convert API JSON → Message
  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['_id'],
      classId: json['classId'],
      sender: json['sender'],
      content: json['content'],
      timestamp: json['timestamp'],
    );
  }
}
