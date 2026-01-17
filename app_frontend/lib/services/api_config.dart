class ApiConfig {
  // Change this to your backend URL
  // For local development: http://10.0.2.2:8000 (Android emulator)
  // For physical device: http://YOUR_COMPUTER_IP:8000
  // For production: https://your-api-domain.com
  static const String baseUrl = 'http://10.0.2.2:8000';
  
  // API Endpoints
  static const String register = '/auth/register';
  static const String login = '/auth/login';
  static const String me = '/auth/me';
  static const String profile = '/profile/';
  static const String profileStats = '/profile/stats';
  static const String contacts = '/contacts/open/';
  static const String sosTrigger = '/sos/trigger';
  static const String sosVoiceTrigger = '/sos/voice-trigger';
  static const String sosAlerts = '/sos/';
  static const String sosLocation = '/sos/{id}/location';
  static const String sosResolve = '/sos/{id}/resolve';
  static const String sosEscalate = '/sos/{id}/escalate';
  static const String locationUpdate = '/location/update';
  static const String locationHistory = '/location/history';
}
