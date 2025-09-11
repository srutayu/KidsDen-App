class UserRequest {
  final String id;
  final String name;
  final String role;

  UserRequest({required this.id, required this.name, required this.role});

  factory UserRequest.fromJson(Map<String, dynamic> json){
    return UserRequest(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      role: json['role'] ??''
    );
  }
}