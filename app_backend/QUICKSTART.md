# Quick Start Guide

## Installation & Setup

1. **Install Python dependencies:**
   ```bash
   cd app_backend
   pip install -r requirements.txt
   ```

2. **Set up environment variables:**
   - Copy `config.env.example` to `.env`
   - Fill in your API keys (optional for basic testing):
     - `GOOGLE_MAPS_API_KEY` - For address lookup and maps
     - `TWILIO_*` - For SMS notifications
     - `SENDGRID_API_KEY` - For email notifications
     - `SECRET_KEY` - Change to a random string (min 32 chars)

3. **Run the server:**
   ```bash
   python run.py
   ```
   Or:
   ```bash
   uvicorn main:app --reload
   ```

4. **Access the API:**
   - API Base: `http://localhost:8000`
   - Swagger Docs: `http://localhost:8000/docs`
   - ReDoc: `http://localhost:8000/redoc`

## Basic API Usage

### 1. Register a User
```bash
POST /auth/register
{
  "name": "Jane Doe",
  "phone": "+1234567890",
  "email": "jane@example.com",
  "password": "securepass123",
  "codeword": "helpme"
}
```

### 2. Login
```bash
POST /auth/login
{
  "phone": "+1234567890",
  "password": "securepass123"
}
```
Returns: `access_token` - Use this in Authorization header

### 3. Add Trusted Contact
```bash
POST /contacts/
Authorization: Bearer <token>
{
  "name": "Mom",
  "phone": "+1987654321",
  "email": "mom@example.com",
  "relation": "family",
  "is_primary": true
}
```

### 4. Trigger SOS Alert
```bash
POST /sos/trigger
Authorization: Bearer <token>
{
  "latitude": 28.6139,
  "longitude": 77.2090,
  "severity": "high",
  "triggered_by": "manual"
}
```

### 5. Trigger SOS by Voice
```bash
POST /sos/voice-trigger
Authorization: Bearer <token>
{
  "voice_data": {
    "detected_word": "helpme",
    "confidence": 0.95
  },
  "alert_data": {
    "latitude": 28.6139,
    "longitude": 77.2090,
    "severity": "critical"
  }
}
```

### 6. Update Alert Location (for live tracking)
```bash
POST /sos/{alert_id}/location
Authorization: Bearer <token>
{
  "latitude": 28.6140,
  "longitude": 77.2091,
  "accuracy": 10.5
}
```

### 7. Resolve Alert
```bash
PUT /sos/{alert_id}/resolve
Authorization: Bearer <token>
```

## Testing Without External Services

The backend works without external API keys for basic functionality:
- Database operations work
- Alert creation works
- Location tracking works
- Notifications will be logged (not sent) if API keys are missing

## Database

The app uses SQLite by default (`safevoice.db`). For production, use PostgreSQL by setting:
```
DATABASE_URL=postgresql://user:password@localhost/safevoice
```

## Next Steps

1. Set up Google Maps API for address lookup
2. Configure Twilio for SMS notifications
3. Set up SendGrid for email notifications
4. Deploy to production server
5. Connect your mobile app frontend
