class UserModel {
  final String fullName;
  final String deviceId;

  UserModel({
    required this.fullName,
    required this.deviceId,
  });

  Map<String, dynamic> toMap() {
    return {
      'fullName': fullName,
      'deviceId': deviceId,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      fullName: map['fullName'] ?? '',
      deviceId: map['deviceId'] ?? '',
    );
  }
}
