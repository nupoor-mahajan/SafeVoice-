import 'api_service.dart';
import 'api_config.dart';

class ContactsService {
  final ApiService _api = ApiService();

  Future<Map<String, dynamic>> createContact({
    required String name,
    required String phone,
    String? email,
    String relation = 'family',
    bool isPrimary = false,
  }) async {
    try {
      return await _api.post(
        ApiConfig.contacts,
        {
          'name': name,
          'phone': phone,
          if (email != null) 'email': email,
          'relation': relation,
          'is_primary': isPrimary,
        },
      );
    } catch (e) {
      throw Exception('Failed to create contact: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getContacts() async {
    try {
      final response = await _api.get(ApiConfig.contacts);
      final List<dynamic> data = response as List<dynamic>;
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      throw Exception('Failed to get contacts: $e');
    }
  }

  Future<Map<String, dynamic>> getContact(int contactId) async {
    try {
      return await _api.get('${ApiConfig.contacts}$contactId');
    } catch (e) {
      throw Exception('Failed to get contact: $e');
    }
  }

  Future<Map<String, dynamic>> updateContact({
    required int contactId,
    String? name,
    String? phone,
    String? email,
    String? relation,
    bool? isPrimary,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (name != null) data['name'] = name;
      if (phone != null) data['phone'] = phone;
      if (email != null) data['email'] = email;
      if (relation != null) data['relation'] = relation;
      if (isPrimary != null) data['is_primary'] = isPrimary;

      return await _api.put('${ApiConfig.contacts}$contactId', data);
    } catch (e) {
      throw Exception('Failed to update contact: $e');
    }
  }

  Future<void> deleteContact(int contactId) async {
    try {
      await _api.delete('${ApiConfig.contacts}$contactId');
    } catch (e) {
      throw Exception('Failed to delete contact: $e');
    }
  }
}
