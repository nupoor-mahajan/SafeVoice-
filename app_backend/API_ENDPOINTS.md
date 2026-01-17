# API Endpoints Reference

## Authentication (`/auth`)

### POST `/auth/register`
Register a new user account.

**Request Body:**
```json
{
  "name": "string",
  "phone": "string",
  "email": "string",
  "password": "string",
  "codeword": "string"
}
```

**Response:** `TokenResponse` with access token

---

### POST `/auth/login`
Login and get access token.

**Request Body:**
```json
{
  "phone": "string",
  "password": "string"
}
```

**Response:** `TokenResponse` with access token

---

### GET `/auth/me`
Get current user profile (requires authentication).

**Headers:** `Authorization: Bearer <token>`

**Response:** `UserProfile`

---

## User Profile (`/profile`)

### GET `/profile/`
Get user profile.

**Headers:** `Authorization: Bearer <token>`

**Response:** `UserProfile`

---

### PUT `/profile/`
Update user profile.

**Headers:** `Authorization: Bearer <token>`

**Request Body:**
```json
{
  "name": "string (optional)",
  "email": "string (optional)",
  "codeword": "string (optional)"
}
```

**Response:** `UserProfile`

---

### GET `/profile/stats`
Get user statistics.

**Headers:** `Authorization: Bearer <token>`

**Response:** `UserStats` (total alerts, active alerts, contacts count, etc.)

---

## Trusted Contacts (`/contacts`)

### POST `/contacts/`
Add a trusted contact.

**Headers:** `Authorization: Bearer <token>`

**Request Body:**
```json
{
  "name": "string",
  "phone": "string",
  "email": "string (optional)",
  "relation": "string (family|friend|authority|other)",
  "is_primary": "boolean"
}
```

**Response:** `ContactResponse`

---

### GET `/contacts/`
Get all trusted contacts.

**Headers:** `Authorization: Bearer <token>`

**Response:** `List[ContactResponse]`

---

### GET `/contacts/{contact_id}`
Get a specific contact.

**Headers:** `Authorization: Bearer <token>`

**Response:** `ContactResponse`

---

### PUT `/contacts/{contact_id}`
Update a contact.

**Headers:** `Authorization: Bearer <token>`

**Request Body:** `ContactUpdate` (all fields optional)

**Response:** `ContactResponse`

---

### DELETE `/contacts/{contact_id}`
Delete a contact.

**Headers:** `Authorization: Bearer <token>`

**Response:** `204 No Content`

---

## SOS Alerts (`/sos`)

### POST `/sos/trigger`
Trigger an SOS alert manually.

**Headers:** `Authorization: Bearer <token>`

**Request Body:**
```json
{
  "latitude": 28.6139,
  "longitude": 77.2090,
  "severity": "low|medium|high|critical",
  "triggered_by": "manual|voice|panic_button",
  "notes": "string (optional)"
}
```

**Response:** `AlertResponse` with Google Maps link

---

### POST `/sos/voice-trigger`
Trigger SOS alert via voice code word detection.

**Headers:** `Authorization: Bearer <token>`

**Request Body:**
```json
{
  "voice_data": {
    "detected_word": "string",
    "confidence": 0.0-1.0
  },
  "alert_data": {
    "latitude": 28.6139,
    "longitude": 77.2090,
    "severity": "low|medium|high|critical"
  }
}
```

**Response:** `AlertResponse`

---

### GET `/sos/`
Get all alerts for current user.

**Headers:** `Authorization: Bearer <token>`

**Query Parameters:**
- `status_filter`: Filter by status (optional)
- `limit`: Number of results (default: 50)
- `offset`: Pagination offset (default: 0)

**Response:** `AlertListResponse`

---

### GET `/sos/{alert_id}`
Get a specific alert.

**Headers:** `Authorization: Bearer <token>`

**Response:** `AlertResponse`

---

### GET `/sos/{alert_id}/location-history`
Get location history for an alert.

**Headers:** `Authorization: Bearer <token>`

**Response:**
```json
{
  "alert_id": 1,
  "location_history": [...],
  "total_points": 10
}
```

---

### POST `/sos/{alert_id}/location`
Update location for an active alert (live tracking).

**Headers:** `Authorization: Bearer <token>`

**Request Body:**
```json
{
  "latitude": 28.6140,
  "longitude": 77.2091,
  "accuracy": 10.5,
  "speed": 5.2,
  "heading": 45.0
}
```

**Response:** `LocationResponse`

---

### PUT `/sos/{alert_id}/resolve`
Mark an alert as resolved.

**Headers:** `Authorization: Bearer <token>`

**Response:** `AlertResponse`

---

### PUT `/sos/{alert_id}`
Update an alert.

**Headers:** `Authorization: Bearer <token>`

**Request Body:**
```json
{
  "status": "active|resolved|escalated|cancelled (optional)",
  "severity": "low|medium|high|critical (optional)",
  "notes": "string (optional)"
}
```

**Response:** `AlertResponse`

---

### POST `/sos/{alert_id}/escalate`
Escalate an alert to authorities.

**Headers:** `Authorization: Bearer <token>`

**Request Body:**
```json
{
  "alert_id": 1,
  "escalated_to": "police_112",
  "severity": "critical"
}
```

**Response:** `EscalationResponse`

---

## Location Tracking (`/location`)

### POST `/location/update`
Update user's current location.

**Headers:** `Authorization: Bearer <token>`

**Request Body:**
```json
{
  "latitude": 28.6139,
  "longitude": 77.2090,
  "address": "string (optional)",
  "accuracy": 10.5,
  "speed": 5.2,
  "heading": 45.0
}
```

**Response:** `LocationResponse`

---

### GET `/location/history`
Get user's location history.

**Headers:** `Authorization: Bearer <token>`

**Query Parameters:**
- `limit`: Number of results (default: 100)

**Response:** `List[LocationResponse]`

---

## Error Responses

All endpoints may return:

- `400 Bad Request` - Invalid input data
- `401 Unauthorized` - Missing or invalid token
- `403 Forbidden` - User account inactive
- `404 Not Found` - Resource not found
- `500 Internal Server Error` - Server error

Error response format:
```json
{
  "detail": "Error message"
}
```
