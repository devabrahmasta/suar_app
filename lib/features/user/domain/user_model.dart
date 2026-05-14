class UserModel {
  final String fullName;
  final String deviceId;
  final String homeType;
  final double? homeLatitude;
  final double? homeLongitude;

  UserModel({
    required this.fullName,
    required this.deviceId,
    required this.homeType,
    this.homeLatitude,
    this.homeLongitude,
  });

  Map<String, dynamic> toMap() {
    return {
      'fullName': fullName,
      'deviceId': deviceId,
      'homeType': homeType,
      'homeLatitude': homeLatitude,
      'homeLongitude': homeLongitude,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      fullName: map['fullName'] ?? '',
      deviceId: map['deviceId'] ?? '',
      homeType: map['homeType'] ?? '',
      homeLatitude: map['homeLatitude']?.toDouble(),
      homeLongitude: map['homeLongitude']?.toDouble(),
    );
  }
}