class UserModel {
  final String fullName;
  final String phoneNumber;
  final String username;

  UserModel({
    required this.fullName,
    required this.phoneNumber,
    required this.username,
  });

  Map<String, dynamic> toMap() {
    return {
      'fullName': fullName,
      'phoneNumber': phoneNumber,
      'username': username,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      fullName: map['fullName'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      username: map['username'] ?? '',
    );
  }
}
