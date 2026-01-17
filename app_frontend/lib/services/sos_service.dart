import 'api_service.dart';
import 'api_config.dart';

class SosService {
  final ApiService _api = ApiService();

  Future<Map<String, dynamic>> triggerSos({
    required double latitude,
    required double longitude,
    String severity = 'high',
    String triggeredBy = 'voice',
    String? notes,
  }) async {
    try {
      return await _api.post(
        ApiConfig.sosTrigger,
        {
          'latitude': latitude,
          'longitude': longitude,
          'severity': severity,
          'triggered_by': triggeredBy,
          if (notes != null) 'notes': notes,
        },
      );
    } catch (e) {
      throw Exception('Failed to trigger SOS: $e');
    }
  }

  Future<Map<String, dynamic>> triggerSosByVoice({
    required double latitude,
    required double longitude,
    required String detectedWord,
    required double confidence,
    String severity = 'critical',
  }) async {
    try {
      return await _api.post(
        ApiConfig.sosVoiceTrigger,
        {
          'voice_data': {
            'detected_word': detectedWord,
            'confidence': confidence,
          },
          'alert_data': {
            'latitude': latitude,
            'longitude': longitude,
            'severity': severity,
          },
        },
      );
    } catch (e) {
      throw Exception('Failed to trigger SOS by voice: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getAlerts({
    String? statusFilter,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      String endpoint = ApiConfig.sosAlerts;
      if (statusFilter != null) {
        endpoint += '?status_filter=$statusFilter&limit=$limit&offset=$offset';
      } else {
        endpoint += '?limit=$limit&offset=$offset';
      }

      final response = await _api.get(endpoint);
      return List<Map<String, dynamic>>.from(response['alerts'] ?? []);
    } catch (e) {
      throw Exception('Failed to get alerts: $e');
    }
  }

  Future<Map<String, dynamic>> updateAlertLocation({
    required int alertId,
    required double latitude,
    required double longitude,
    double? accuracy,
    double? speed,
    double? heading,
  }) async {
    try {
      final endpoint = ApiConfig.sosLocation.replaceAll('{id}', alertId.toString());
      return await _api.post(
        endpoint,
        {
          'latitude': latitude,
          'longitude': longitude,
          if (accuracy != null) 'accuracy': accuracy,
          if (speed != null) 'speed': speed,
          if (heading != null) 'heading': heading,
        },
      );
    } catch (e) {
      throw Exception('Failed to update alert location: $e');
    }
  }

  Future<Map<String, dynamic>> resolveAlert(int alertId) async {
    try {
      final endpoint = ApiConfig.sosResolve.replaceAll('{id}', alertId.toString());
      return await _api.put(endpoint, {});
    } catch (e) {
      throw Exception('Failed to resolve alert: $e');
    }
  }

  Future<Map<String, dynamic>> escalateAlert({
    required int alertId,
    String escalatedTo = 'police_112',
    String severity = 'critical',
  }) async {
    try {
      final endpoint = ApiConfig.sosEscalate.replaceAll('{id}', alertId.toString());
      return await _api.post(
        endpoint,
        {
          'alert_id': alertId,
          'escalated_to': escalatedTo,
          'severity': severity,
        },
      );
    } catch (e) {
      throw Exception('Failed to escalate alert: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getLocationHistory(int alertId) async {
    try {
      final endpoint = '${ApiConfig.sosAlerts}$alertId/location-history';
      final response = await _api.get(endpoint);
      return List<Map<String, dynamic>>.from(response['location_history'] ?? []);
    } catch (e) {
      throw Exception('Failed to get location history: $e');
    }
  }
}
