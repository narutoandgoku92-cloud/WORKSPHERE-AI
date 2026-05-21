// lib/services/profile_service.dart

import '../models/user_model.dart';
import 'api_client.dart';

class ProfileService {
  final ApiClient apiClient;

  ProfileService(this.apiClient);

  Future<User> getCurrentUserProfile() async {
    final response = await apiClient.get('/users/me');
    return User.fromJson(response.data);
  }

  Future<User> updateProfile({
    String? fullName,
    String? phone,
  }) async {
    final response = await apiClient.put(
      '/users/me',
      data: {
        'full_name': ?fullName,
        'phone': ?phone,
      },
    );
    return User.fromJson(response.data);
  }
}