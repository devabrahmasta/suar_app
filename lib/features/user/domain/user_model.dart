class UserModel {
  final String fullName;
  final String deviceId;
  final String homeType;
  final double? homeLatitude;
  final double? homeLongitude;

  UserModel({
    required this.fullName,
    required this.deviceId,
    this.homeType = 'Rumah Tapak',
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
      homeType: map['homeType'] ?? 'Rumah Tapak',
      homeLatitude: map['homeLatitude']?.toDouble(),
      homeLongitude: map['homeLongitude']?.toDouble(),
    );
  }
}