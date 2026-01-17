# SAFE-VOICE Backend API

Voice-Activated Emergency Alert System for Women - Backend API

## Features

- ✅ Secure user authentication with JWT tokens
- ✅ User profile management
- ✅ Trusted contacts management
- ✅ Voice-activated SOS alerts
- ✅ Real-time GPS location tracking
- ✅ Google Maps integration
- ✅ Automatic notifications to contacts
- ✅ Emergency escalation to authorities
- ✅ Location history tracking

## Setup Instructions

### 1. Install Dependencies

```bash
pip install -r requirements.txt
```

### 2. Configure Environment Variables

Copy `.env.example` to `.env` and fill in your configuration:

```bash
cp .env.example .env
```

Edit `.env` with your API keys:
- `GOOGLE_MAPS_API_KEY`: For reverse geocoding and maps
- `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`, `TWILIO_PHONE_NUMBER`: For SMS notifications
- `SENDGRID_API_KEY`: For email notifications
- `SECRET_KEY`: JWT secret (use a strong random string in production)

### 3. Run the Server

```bash
# Development
uvicorn main:app --reload

# Production
uvicorn main:app --host 0.0.0.0 --port 8000
```

The API will be available at `http://localhost:8000`

### 4. API Documentation

Once the server is running, visit:
- Swagger UI: `http://localhost:8000/docs`
- ReDoc: `http://localhost:8000/redoc`

## API Endpoints

### Authentication
- `POST /auth/register` - Register new user
- `POST /auth/login` - Login and get token
- `GET /auth/me` - Get current user profile

### User Profile
- `GET /profile/` - Get user profile
- `PUT /profile/` - Update user profile
- `GET /profile/stats` - Get user statistics

### Trusted Contacts
- `POST /contacts/` - Add trusted contact
- `GET /contacts/` - Get all contacts
- `GET /contacts/{id}` - Get specific contact
- `PUT /contacts/{id}` - Update contact
- `DELETE /contacts/{id}` - Delete contact

### SOS Alerts
- `POST /sos/trigger` - Trigger SOS alert manually
- `POST /sos/voice-trigger` - Trigger SOS via voice code word
- `GET /sos/` - Get all alerts
- `GET /sos/{id}` - Get specific alert
- `GET /sos/{id}/location-history` - Get location history for alert
- `POST /sos/{id}/location` - Update alert location
- `PUT /sos/{id}/resolve` - Mark alert as resolved
- `POST /sos/{id}/escalate` - Escalate alert to authorities

### Location Tracking
- `POST /location/update` - Update user location
- `GET /location/history` - Get location history

## Database

The application uses SQLite by default (for development). For production, use PostgreSQL by setting the `DATABASE_URL` environment variable.

Database models:
- `User` - User accounts
- `Contact` - Trusted contacts
- `Alert` - Emergency alerts
- `LocationUpdate` - Location tracking data
- `Notification` - Notification records
- `EmergencyEscalation` - Authority escalation records

## Security Notes

1. **Change SECRET_KEY**: Use a strong, random secret key in production
2. **Use HTTPS**: Always use HTTPS in production
3. **CORS**: Update CORS settings to allow only your frontend domain
4. **Database**: Use PostgreSQL with proper authentication in production
5. **API Keys**: Keep all API keys secure and never commit them to version control

## Testing

Example API calls using curl:

```bash
# Register
curl -X POST "http://localhost:8000/auth/register" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Test User",
    "phone": "+1234567890",
    "email": "test@example.com",
    "password": "securepassword123",
    "codeword": "helpme"
  }'

# Login
curl -X POST "http://localhost:8000/auth/login" \
  -H "Content-Type: application/json" \
  -d '{
    "phone": "+1234567890",
    "password": "securepassword123"
  }'

# Trigger SOS (with token)
curl -X POST "http://localhost:8000/sos/trigger" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "latitude": 28.6139,
    "longitude": 77.2090,
    "severity": "high"
  }'
```

## Production Deployment

1. Set up PostgreSQL database
2. Configure environment variables
3. Use a production ASGI server (Gunicorn + Uvicorn)
4. Set up reverse proxy (Nginx)
5. Enable HTTPS with SSL certificates
6. Set up monitoring and logging
7. Configure backup strategy for database

## License

This project is part of the SAFE-VOICE emergency alert system.
