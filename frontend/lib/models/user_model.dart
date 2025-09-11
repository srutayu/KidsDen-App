
class User{
  final String id;
  final String name;
  final String email;
  final String role;
  final List<String> assignedClasses;

  User({required this.id, required this.name, required this.email, required this.role, required this.assignedClasses});

  factory User.fromJson(Map<String, dynamic> json){
    return User(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ??'',
      assignedClasses: json['assignedClasses'] != null ? List<String>.from(json['assignedClasses']) : []
    );
  }
}