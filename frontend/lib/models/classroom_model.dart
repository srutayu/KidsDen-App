class ClassroomModel {
  final String id;
  final String name;

  ClassroomModel({required this.id, required this.name});

  factory ClassroomModel.fromJson(Map<String, dynamic> json) {
    return ClassroomModel(
        id: json['_id'] as String,
      name: json['name'] as String
    );
  }
}