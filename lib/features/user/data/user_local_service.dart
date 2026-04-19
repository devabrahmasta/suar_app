import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/user_model.dart';

class UserLocalService {
  // Fungsi Simpan
  static Future<void> saveUser(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_cache', jsonEncode(user.toMap()));
    await prefs.setBool('has_onboarded', true);
  }

  // Fungsi Ambil
  static Future<UserModel?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final String? userJson = prefs.getString('user_cache');
    if (userJson != null) {
      return UserModel.fromMap(jsonDecode(userJson));
    }
    return null;
  }
}