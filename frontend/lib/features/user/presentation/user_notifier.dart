import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../main.dart';
import '../domain/user_model.dart';
import '../data/user_local_service.dart';
import '../../../core/services/suar_backend_service.dart';

class UserNotifier extends Notifier<UserModel?> {
  @override
  UserModel? build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final String? userJson = prefs.getString('user_cache');

    if (userJson != null) {
      final user = UserModel.fromMap(jsonDecode(userJson));
      
      // Sinkronisasi status perangkat ke backend secara asynchronous di background
      Future.microtask(() async {
        try {
          final backendService = ref.read(suarBackendServiceProvider);
          await backendService.registerDevice(
            deviceId: user.deviceId,
            fcmToken: 'mock_token_${user.deviceId.substring(0, 8)}',
            homeType: user.homeType,
            homeLatitude: user.homeLatitude,
            homeLongitude: user.homeLongitude,
          );
        } catch (e) {
          // Gagal koneksi backend diabaikan agar offline-first tetap berjalan mulus
        }
      });
      
      return user;
    }
    return null;
  }

  Future<void> createUser({
    required String name,
    required String homeType,
    required double? homeLat,
    required double? homeLng,
  }) async {
    final String generatedDeviceId = const Uuid().v4();
    final user = UserModel(
      fullName: name,
      deviceId: generatedDeviceId,
      homeType: homeType,
      homeLatitude: homeLat,
      homeLongitude: homeLng,
    );

    await UserLocalService.saveUser(user);
    state = user;

    // Registrasi perangkat baru ke cloud backend
    try {
      final backendService = ref.read(suarBackendServiceProvider);
      await backendService.registerDevice(
        deviceId: generatedDeviceId,
        fcmToken: 'mock_token_${generatedDeviceId.substring(0, 8)}',
        homeType: homeType,
        homeLatitude: homeLat,
        homeLongitude: homeLng,
      );
    } catch (e) {
      // Gagal koneksi backend diabaikan agar offline-first tetap berjalan mulus
    }
  }
}

final userProvider = NotifierProvider<UserNotifier, UserModel?>(() {
  return UserNotifier();
});
