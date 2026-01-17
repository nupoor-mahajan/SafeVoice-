from pydantic import BaseModel, EmailStr, Field, validator
from typing import Optional, List
from datetime import datetime
from enum import Enum

# Request/Response Models

class SeverityLevel(str, Enum):
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"
    CRITICAL = "critical"

class AlertStatus(str, Enum):
    ACTIVE = "active"
    RESOLVED = "resolved"
    ESCALATED = "escalated"
    CANCELLED = "cancelled"

# Authentication Models
class UserRegister(BaseModel):
    name: str = Field(..., min_length=2, max_length=100)
    phone: str = Field(..., min_length=10, max_length=20)
    email: EmailStr
    password: str = Field(..., min_length=8)
    codeword: str = Field(..., min_length=3, max_length=50, description="Custom voice trigger word")

class UserLogin(BaseModel):
    phone: str
    password: str

class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user_id: int
    name: str

# User Profile Models
class UserProfile(BaseModel):
    id: int
    name: str
    phone: str
    email: str
    codeword: str
    is_active: bool
    created_at: datetime
    
    class Config:
        from_attributes = True

class UserProfileUpdate(BaseModel):
    name: Optional[str] = None
    email: Optional[EmailStr] = None
    codeword: Optional[str] = Field(None, min_length=3, max_length=50)

# Contact Models
class ContactCreate(BaseModel):
    name: str = Field(..., min_length=2, max_length=100)
    phone: str = Field(..., min_length=10, max_length=20)
    email: Optional[EmailStr] = None
    relation: str = "family"
    is_primary: bool = False

class ContactResponse(BaseModel):
    id: int
    name: str
    phone: str
    email: Optional[str]
    relation: str
    is_primary: bool
    created_at: datetime
    
    class Config:
        from_attributes = True

class ContactUpdate(BaseModel):
    name: Optional[str] = None
    phone: Optional[str] = None
    email: Optional[EmailStr] = None
    relation: Optional[str] = None
    is_primary: Optional[bool] = None

# Location Models
class LocationUpdate(BaseModel):
    latitude: float = Field(..., ge=-90, le=90)
    longitude: float = Field(..., ge=-180, le=180)
    address: Optional[str] = None
    accuracy: Optional[float] = None
    speed: Optional[float] = None
    heading: Optional[float] = None

class LocationResponse(BaseModel):
    id: int
    latitude: float
    longitude: float
    address: Optional[str]
    timestamp: datetime
    
    class Config:
        from_attributes = True

# Alert Models
class AlertCreate(BaseModel):
    latitude: float = Field(..., ge=-90, le=90)
    longitude: float = Field(..., ge=-180, le=180)
    severity: SeverityLevel = SeverityLevel.MEDIUM
    triggered_by: str = "voice"
    notes: Optional[str] = None

class AlertResponse(BaseModel):
    id: int
    user_id: int
    latitude: float
    longitude: float
    address: Optional[str]
    status: str
    severity: str
    triggered_by: str
    created_at: datetime
    resolved_at: Optional[datetime]
    google_maps_link: str
    
    class Config:
        from_attributes = True

class AlertUpdate(BaseModel):
    status: Optional[AlertStatus] = None
    severity: Optional[SeverityLevel] = None
    notes: Optional[str] = None

class AlertListResponse(BaseModel):
    alerts: List[AlertResponse]
    total: int

# Notification Models
class NotificationResponse(BaseModel):
    id: int
    recipient_type: str
    recipient_phone: Optional[str]
    message: str
    sent_at: datetime
    status: str
    
    class Config:
        from_attributes = True

# Emergency Escalation Models
class EscalationRequest(BaseModel):
    alert_id: int
    escalated_to: str = "police_112"
    severity: SeverityLevel = SeverityLevel.CRITICAL

class EscalationResponse(BaseModel):
    id: int
    alert_id: int
    escalated_to: str
    severity: str
    priority: int
    status: str
    created_at: datetime
    
    class Config:
        from_attributes = True

# Voice Detection Model
class VoiceCodeWordDetection(BaseModel):
    audio_data: Optional[str] = None  # Base64 encoded audio
    detected_word: str
    confidence: float = Field(..., ge=0, le=1)

# Dashboard/Stats Models
class UserStats(BaseModel):
    total_alerts: int
    active_alerts: int
    total_contacts: int
    last_alert_at: Optional[datetime]
