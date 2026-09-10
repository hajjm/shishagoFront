import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_models.dart';
import 'chichago_api.dart';

class SessionController extends ChangeNotifier {
  SessionController(this.api);

  static const _tokenKey = 'chichago_access_token';
  final ChichagoApi api;

  AppUser? user;
  bool loading = false;
  String? error;
  String? developmentCode;

  Future<void> restore() async {
    final preferences = await SharedPreferences.getInstance();
    final token = preferences.getString(_tokenKey);
    if (token == null) return;
    api.accessToken = token;
    try {
      user = AppUser.fromJson(await api.getMe());
    } catch (_) {
      api.accessToken = null;
      await preferences.remove(_tokenKey);
    }
    notifyListeners();
  }

  Future<void> requestSignInCode(String phone) =>
      _requestCode(phone: phone, flow: 'sign_in');

  Future<void> requestSignUpCode(String phone) =>
      _requestCode(phone: phone, flow: 'sign_up');

  Future<void> _requestCode({
    required String phone,
    required String flow,
  }) async {
    await _run(() async {
      final response = await api.requestVerificationCode(
        phone: phone,
        flow: flow,
      );
      developmentCode = response['dev_code'] as String?;
    });
  }

  Future<void> signIn({required String phone, required String code}) =>
      _verify(phone: phone, code: code, flow: 'sign_in');

  Future<void> signUp({
    required String phone,
    required String code,
    required String name,
    required String address,
    double? latitude,
    double? longitude,
  }) => _verify(
    phone: phone,
    code: code,
    flow: 'sign_up',
    name: name,
    address: address,
    latitude: latitude,
    longitude: longitude,
  );

  Future<void> _verify({
    required String phone,
    required String code,
    required String flow,
    String? name,
    String? address,
    double? latitude,
    double? longitude,
  }) async {
    await _run(() async {
      final response = await api.verifyCode(
        phone: phone,
        code: code,
        flow: flow,
        name: name,
        address: address,
        latitude: latitude,
        longitude: longitude,
      );
      user = AppUser.fromJson(response['user'] as Map<String, dynamic>);
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_tokenKey, api.accessToken!);
    });
  }

  Future<void> refreshProfile() async {
    user = AppUser.fromJson(await api.getMe());
    notifyListeners();
  }

  Future<void> updateProfile({
    required String name,
    required String address,
    required double latitude,
    required double longitude,
  }) async {
    await _run(() async {
      user = AppUser.fromJson(
        await api.updateMe({
          'name': name,
          'address': address,
          'latitude': latitude,
          'longitude': longitude,
        }),
      );
    });
  }

  Future<void> logout() async {
    api.accessToken = null;
    user = null;
    developmentCode = null;
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_tokenKey);
    notifyListeners();
  }

  Future<void> _run(Future<void> Function() operation) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      await operation();
    } catch (exception) {
      error = exception.toString();
      rethrow;
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}
