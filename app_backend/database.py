from sqlalchemy import create_engine, Column, Integer, String, Text, Float, DateTime, ForeignKey, Boolean, Enum as SQLEnum
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, relationship
from datetime import datetime
import os
import enum

# Database config - Use SQLite for development, can be changed to PostgreSQL for production
SQLALCHEMY_DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./safevoice.db")

if SQLALCHEMY_DATABASE_URL.startswith("sqlite"):
    engine = create_engine(
        SQLALCHEMY_DATABASE_URL, 
        connect_args={"check_same_thread": False}
    )
else:
    engine = create_engine(SQLALCHEMY_DATABASE_URL)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

# Enums
class AlertStatus(str, enum.Enum):
    ACTIVE = "active"
    RESOLVED = "resolved"
    ESCALATED = "escalated"
    CANCELLED = "cancelled"

class SeverityLevel(str, enum.Enum):
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"
    CRITICAL = "critical"

class ContactRelation(str, enum.Enum):
    FAMILY = "family"
    FRIEND = "friend"
    AUTHORITY = "authority"
    OTHER = "other"

# Database Models
class User(Base):
    __tablename__ = "users"
    
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(100), nullable=False, index=True)
    phone = Column(String(20), unique=True, nullable=False, index=True)
    email = Column(String(100), unique=True, nullable=False, index=True)
    password_hash = Column(String(255), nullable=False)
    codeword = Column(String(50), nullable=False)  # Custom SOS trigger word
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Relationships
    contacts = relationship("Contact", back_populates="owner", cascade="all, delete-orphan")
    alerts = relationship("Alert", back_populates="user", cascade="all, delete-orphan")
    location_updates = relationship("LocationUpdate", back_populates="user", cascade="all, delete-orphan")

class Contact(Base):
    __tablename__ = "contacts"
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    name = Column(String(100), nullable=False)
    phone = Column(String(20), nullable=False, index=True)
    email = Column(String(100))
    relation = Column(String(20), default=ContactRelation.FAMILY.value)
    is_primary = Column(Boolean, default=False)  # Primary emergency contact
    created_at = Column(DateTime, default=datetime.utcnow)
    
    owner = relationship("User", back_populates="contacts")

class Alert(Base):
    __tablename__ = "alerts"
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    latitude = Column(Float, nullable=False)
    longitude = Column(Float, nullable=False)
    address = Column(String(255))  # Human-readable address
    status = Column(String(20), default=AlertStatus.ACTIVE.value, index=True)
    severity = Column(String(20), default=SeverityLevel.MEDIUM.value, index=True)
    triggered_by = Column(String(20), default="voice")  # voice, manual, panic_button
    created_at = Column(DateTime, default=datetime.utcnow, index=True)
    resolved_at = Column(DateTime, nullable=True)
    escalated_at = Column(DateTime, nullable=True)
    notes = Column(Text)  # Additional information
    
    # Relationships
    user = relationship("User", back_populates="alerts")
    location_updates = relationship("LocationUpdate", back_populates="alert", cascade="all, delete-orphan")
    notifications = relationship("Notification", back_populates="alert", cascade="all, delete-orphan")

class LocationUpdate(Base):
    __tablename__ = "location_updates"
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    alert_id = Column(Integer, ForeignKey("alerts.id", ondelete="CASCADE"), nullable=True)
    latitude = Column(Float, nullable=False)
    longitude = Column(Float, nullable=False)
    address = Column(String(255))
    accuracy = Column(Float)  # GPS accuracy in meters
    speed = Column(Float)  # Speed in m/s
    heading = Column(Float)  # Direction in degrees
    timestamp = Column(DateTime, default=datetime.utcnow, index=True)
    
    # Relationships
    user = relationship("User", back_populates="location_updates")
    alert = relationship("Alert", back_populates="location_updates")

class Notification(Base):
    __tablename__ = "notifications"
    
    id = Column(Integer, primary_key=True, index=True)
    alert_id = Column(Integer, ForeignKey("alerts.id", ondelete="CASCADE"), nullable=False)
    contact_id = Column(Integer, ForeignKey("contacts.id", ondelete="SET NULL"), nullable=True)
    recipient_type = Column(String(20), nullable=False)  # contact, authority, police
    recipient_phone = Column(String(20))
    recipient_email = Column(String(100))
    message = Column(Text, nullable=False)
    sent_at = Column(DateTime, default=datetime.utcnow)
    status = Column(String(20), default="sent")  # sent, delivered, failed
    response_received = Column(Boolean, default=False)
    
    alert = relationship("Alert", back_populates="notifications")

class EmergencyEscalation(Base):
    __tablename__ = "emergency_escalations"
    
    id = Column(Integer, primary_key=True, index=True)
    alert_id = Column(Integer, ForeignKey("alerts.id", ondelete="CASCADE"), nullable=False)
    escalated_to = Column(String(50), nullable=False)  # police_112, patrol_unit, hospital
    severity = Column(String(20), nullable=False)
    priority = Column(Integer, default=1)  # 1 = highest priority
    status = Column(String(20), default="pending")  # pending, dispatched, responded, resolved
    dispatch_id = Column(String(100))  # External dispatch reference
    created_at = Column(DateTime, default=datetime.utcnow)
    responded_at = Column(DateTime, nullable=True)
    
    alert = relationship("Alert")

# Dependency
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# Create tables function
def init_db():
    Base.metadata.create_all(bind=engine)
    print("✅ Database & tables created successfully")

# Export for other modules
__all__ = [
    "engine", "SessionLocal", "get_db", "init_db", "Base",
    "User", "Contact", "Alert", "LocationUpdate", "Notification", "EmergencyEscalation",
    "AlertStatus", "SeverityLevel", "ContactRelation"
]
