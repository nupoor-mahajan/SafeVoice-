import 'api_service.dart';
import 'api_config.dart';
import 'storage_service.dart';

class AuthService {
  final ApiService _api = ApiService();
  final StorageService _storage = StorageService();

  Future<Map<String, dynamic>> register({
    required String name,
    required String phone,
    required String email,
    required String password,
    required String codeword,
  }) async {
    try {
      final response = await _api.post(
        ApiConfig.register,
        {
          'name': name,
          'phone': phone,
          'email': email,
          'password': password,
          'codeword': codeword,
        },
        auth: false,
      );

      // Save token and user data
      await _storage.saveToken(response['access_token']);
      await _storage.saveUserData(
        userId: response['user_id'],
        name: name,
        phone: phone,
        email: email,
        codeword: codeword,
      );

      return response;
    } catch (e) {
      throw Exception('Registration failed: $e');
    }
  }

  Future<Map<String, dynamic>> login({
    required String phone,
    required String password,
  }) async {
    try {
      final response = await _api.post(
        ApiConfig.login,
        {
          'phone': phone,
          'password': password,
        },
        auth: false,
      );

      // Save token
      await _storage.saveToken(response['access_token']);

      // Get user profile to save full data
      final profile = await getProfile();
      await _storage.saveUserData(
        userId: response['user_id'],
        name: profile['name'],
        phone: profile['phone'],
        email: profile['email'],
        codeword: profile['codeword'],
      );

      return response;
    } catch (e) {
      throw Exception('Login failed: $e');
    }
  }

  Future<Map<String, dynamic>> getProfile() async {
    try {
      return await _api.get(ApiConfig.me);
    } catch (e) {
      throw Exception('Failed to get profile: $e');
    }
  }

  Future<Map<String, dynamic>> updateProfile({
    String? name,
    String? email,
    String? codeword,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (name != null) data['name'] = name;
      if (email != null) data['email'] = email;
      if (codeword != null) data['codeword'] = codeword;

      final response = await _api.put(ApiConfig.profile, data);
      
      // Update stored codeword if changed
      if (codeword != null) {
        final userData = await _storage.getUserData();
        if (userData != null) {
          await _storage.saveUserData(
            userId: userData['id'],
            name: userData['name'],
            phone: userData['phone'],
            email: userData['email'],
            codeword: codeword,
          );
        }
      }

      return response;
    } catch (e) {
      throw Exception('Failed to update profile: $e');
    }
  }

  Future<bool> isLoggedIn() async {
    final token = await _storage.getToken();
    return token != null;
  }

  Future<void> logout() async {
    await _storage.clearAll();
  }
}
