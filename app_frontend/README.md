# Guardian Safety App - Flutter Frontend

Voice-Activated Emergency Alert System for Women - Flutter Mobile Application

## Features

- ✅ Voice-activated SOS alerts with custom code word
- ✅ Real-time GPS location tracking
- ✅ Live map tracking with Flutter Map
- ✅ Trusted contacts management
- ✅ Automatic notifications to contacts
- ✅ Emergency escalation to authorities
- ✅ Settings for voice command configuration

## Setup Instructions

### 1. Install Flutter Dependencies

```bash
cd app_frontend
flutter pub get
```

### 2. Configure Backend URL

Edit `lib/services/api_config.dart` and update the `baseUrl`:

```dart
static const String baseUrl = 'http://YOUR_BACKEND_IP:8000';
```

**Important URLs:**
- **Android Emulator**: `http://10.0.2.2:8000`
- **iOS Simulator**: `http://localhost:8000`
- **Physical Device**: `http://YOUR_COMPUTER_IP:8000` (e.g., `http://192.168.1.100:8000`)

### 3. Configure Permissions

#### Android (`android/app/src/main/AndroidManifest.xml`):

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
```

#### iOS (`ios/Runner/Info.plist`):

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>We need your location to send emergency alerts</string>
<key>NSLocationAlwaysUsageDescription</key>
<string>We need your location for continuous tracking during emergencies</string>
<key>NSMicrophoneUsageDescription</key>
<string>We need microphone access for voice-activated SOS</string>
```

### 4. Run the App

```bash
flutter run
```

## Backend Integration

The app is fully integrated with the SAFE-VOICE backend API. All features connect to the backend:

- **Authentication**: User registration and login
- **SOS Alerts**: Voice-triggered emergency alerts with location
- **Location Tracking**: Continuous GPS tracking during emergencies
- **Contacts**: Manage trusted contacts via backend
- **Settings**: Update codeword and preferences

## API Services

The app uses the following service classes:

- `ApiService`: Base HTTP client
- `AuthService`: Authentication and user management
- `SosService`: SOS alert management
- `ContactsService`: Trusted contacts management
- `LocationService`: Location tracking
- `StorageService`: Local data persistence

## Features Breakdown

### 1. Home Screen (SOS Button)
- Long press to activate voice recognition
- Say the configured code word to trigger SOS
- Automatically sends alert to backend with GPS location
- Starts continuous location tracking

### 2. Live Tracking Map
- Real-time location display on map
- Updates location every 10 seconds
- Sends location updates to backend

### 3. Trusted Contacts
- View all contacts from backend
- Add new contacts
- Delete contacts
- Automatic notifications on SOS trigger

### 4. Settings
- Configure voice activation code word
- Update codeword in backend
- Adjust shake sensitivity (UI only)
- Logout functionality

## Troubleshooting

### Backend Connection Issues

1. **Check backend is running**: Ensure the backend server is running on port 8000
2. **Check URL**: Verify the `baseUrl` in `api_config.dart` matches your setup
3. **Check network**: For physical devices, ensure phone and computer are on same network
4. **Check CORS**: Backend should have CORS enabled (already configured)

### Location Issues

1. **Enable GPS**: Ensure location services are enabled on device
2. **Grant permissions**: App will request location permissions on first use
3. **Check accuracy**: Location accuracy depends on GPS signal strength

### Voice Recognition Issues

1. **Grant microphone permission**: App will request on first use
2. **Check code word**: Ensure code word matches exactly (case-insensitive)
3. **Check internet**: Speech recognition may require internet connection

## Development Notes

- The app uses `shared_preferences` for local token storage
- JWT tokens are automatically included in API requests
- Location tracking runs in background during active alerts
- All API calls include proper error handling

## Production Deployment

Before deploying to production:

1. Update `baseUrl` to production API URL
2. Enable HTTPS for API calls
3. Configure proper app signing
4. Update app permissions in platform-specific files
5. Test on physical devices
6. Configure push notifications (if needed)
