# Complete Integration Guide - SAFE-VOICE App

This guide will help you set up and run both the backend and frontend together.

## Prerequisites

1. **Python 3.8+** installed
2. **Flutter SDK** installed (latest stable version)
3. **Backend server** running
4. **Network connectivity** between mobile device/emulator and backend

## Step 1: Backend Setup

### 1.1 Install Backend Dependencies

```bash
cd app_backend
pip install -r requirements.txt
```

### 1.2 Configure Environment (Optional)

Create a `.env` file in `app_backend/` directory:

```env
DATABASE_URL=sqlite:///./safevoice.db
SECRET_KEY=your-secret-key-change-in-production-min-32-chars-long
GOOGLE_MAPS_API_KEY=your-google-maps-api-key
```

### 1.3 Start Backend Server

```bash
cd app_backend
python run.py
```

Or:

```bash
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

The backend will be available at:
- API: `http://localhost:8000`
- Docs: `http://localhost:8000/docs`

**Important**: Use `--host 0.0.0.0` to allow connections from mobile devices/emulators.

## Step 2: Frontend Setup

### 2.1 Install Flutter Dependencies

```bash
cd app_frontend
flutter pub get
```

### 2.2 Configure Backend URL

Edit `app_frontend/lib/services/api_config.dart`:

**For Android Emulator:**
```dart
static const String baseUrl = 'http://10.0.2.2:8000';
```

**For iOS Simulator:**
```dart
static const String baseUrl = 'http://localhost:8000';
```

**For Physical Device:**
1. Find your computer's IP address:
   - Windows: `ipconfig` (look for IPv4 Address)
   - Mac/Linux: `ifconfig` or `ip addr`
2. Update the URL:
```dart
static const String baseUrl = 'http://192.168.1.XXX:8000'; // Replace XXX with your IP
```

### 2.3 Configure Permissions

#### Android Permissions

Edit `android/app/src/main/AndroidManifest.xml` (create if doesn't exist):

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
    <uses-permission android:name="android.permission.RECORD_AUDIO"/>
    
    <application
        android:label="Guardian Safety"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher">
        <!-- Your app configuration -->
    </application>
</manifest>
```

#### iOS Permissions

Edit `ios/Runner/Info.plist`:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>We need your location to send emergency alerts</string>
<key>NSLocationAlwaysUsageDescription</key>
<string>We need your location for continuous tracking during emergencies</string>
<key>NSMicrophoneUsageDescription</key>
<string>We need microphone access for voice-activated SOS</string>
```

### 2.4 Run the App

```bash
cd app_frontend
flutter run
```

## Step 3: Testing the Integration

### 3.1 Test Backend Connection

1. Open the app
2. Check if backend is reachable (app will show errors if connection fails)
3. Visit `http://localhost:8000/docs` in browser to verify backend is running

### 3.2 Test User Registration/Login

**Note**: The current app doesn't have a login screen. You'll need to either:
- Add a login screen, OR
- Register a user via the API first:

```bash
curl -X POST "http://localhost:8000/auth/register" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Test User",
    "phone": "+1234567890",
    "email": "test@example.com",
    "password": "password123",
    "codeword": "HELP ME"
  }'
```

Then the app will use the stored token.

### 3.3 Test Voice SOS

1. Go to Home screen
2. Long press the SOS button
3. Say your code word (default: "HELP ME")
4. SOS alert should be sent to backend
5. Check backend logs to see the alert

### 3.4 Test Location Tracking

1. Go to "Track Me" screen
2. App should request location permission
3. Map should show your current location
4. Location updates are sent to backend every 10 seconds

### 3.5 Test Contacts

1. Go to "Contacts" screen
2. Click "ADD NEW CONTACT"
3. Fill in details and save
4. Contact should be saved to backend
5. Refresh to see the contact

## Troubleshooting

### Backend Not Connecting

1. **Check backend is running**: `curl http://localhost:8000/health`
2. **Check firewall**: Ensure port 8000 is not blocked
3. **Check URL**: Verify `baseUrl` in `api_config.dart`
4. **Check CORS**: Backend has CORS enabled for all origins (already configured)

### Location Not Working

1. **Grant permissions**: App will request on first use
2. **Enable GPS**: Ensure location services are enabled
3. **Check emulator**: Physical device has better GPS than emulator

### Voice Recognition Not Working

1. **Grant microphone permission**: App will request on first use
2. **Check code word**: Must match exactly (case-insensitive)
3. **Check internet**: Some speech recognition requires internet

### API Errors

1. **Check token**: Ensure user is logged in (token stored)
2. **Check backend logs**: See what errors backend is returning
3. **Check network**: Ensure device can reach backend URL

## Quick Start (All-in-One)

```bash
# Terminal 1: Start Backend
cd app_backend
pip install -r requirements.txt
python run.py

# Terminal 2: Start Frontend
cd app_frontend
flutter pub get
flutter run
```

## Features Working

✅ **Voice-Activated SOS**: Long press button, say code word, SOS sent to backend
✅ **Location Tracking**: GPS location sent to backend continuously
✅ **Trusted Contacts**: Add/delete contacts via backend API
✅ **Settings**: Update code word, saved to backend
✅ **Live Map**: Shows current location on map
✅ **Emergency Escalation**: Can escalate alerts to authorities via backend

## Next Steps

1. Add login/registration screen to the app
2. Add push notifications for alerts
3. Add audio recording during emergencies
4. Add panic button (manual SOS trigger)
5. Add shake detection for fall detection
6. Add battery optimization for background tracking

## Support

If you encounter issues:
1. Check backend logs for API errors
2. Check Flutter console for app errors
3. Verify network connectivity
4. Ensure all permissions are granted
