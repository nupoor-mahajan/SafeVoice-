import 'api_service.dart';
import 'api_config.dart';

class LocationService {
  final ApiService _api = ApiService();

  Future<Map<String, dynamic>> updateLocation({
    required double latitude,
    required double longitude,
    String? address,
    double? accuracy,
    double? speed,
    double? heading,
  }) async {
    try {
      return await _api.post(
        ApiConfig.locationUpdate,
        {
          'latitude': latitude,
          'longitude': longitude,
          if (address != null) 'address': address,
          if (accuracy != null) 'accuracy': accuracy,
          if (speed != null) 'speed': speed,
          if (heading != null) 'heading': heading,
        },
      );
    } catch (e) {
      throw Exception('Failed to update location: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getLocationHistory({int limit = 100}) async {
    try {
      final response = await _api.get('${ApiConfig.locationHistory}?limit=$limit');
      final List<dynamic> data = response as List<dynamic>;
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      throw Exception('Failed to get location history: $e');
    }
  }
}
