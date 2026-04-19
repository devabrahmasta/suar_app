import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/user_model.dart';
import '../data/user_local_service.dart';

class UserNotifier extends Notifier<UserModel?> {
  @override
  UserModel? build() {
    return null; 
  }

  Future<void> createUser(String name, String phone, String uname) async {
    final user = UserModel(
      fullName: name,
      phoneNumber: phone,
      username: uname,
    );

    await UserLocalService.saveUser(user);
    state = user;
  }
}

final userProvider = NotifierProvider<UserNotifier, UserModel?>(() {
  return UserNotifier();
});