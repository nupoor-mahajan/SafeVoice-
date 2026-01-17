"""
SOS Alert System - Core emergency alert functionality
"""
from sqlalchemy.orm import Session
from datetime import datetime
from typing import Optional

from database import Alert, LocationUpdate, EmergencyEscalation, SeverityLevel, AlertStatus
from location import get_address_from_coordinates
from notify import notify_trusted_contacts, notify_authorities

def create_sos_alert(
    db: Session,
    user_id: int,
    latitude: float,
    longitude: float,
    severity: str = "medium",
    triggered_by: str = "voice",
    notes: Optional[str] = None
) -> Alert:
    """Create a new SOS alert"""
    # Get address from coordinates
    address = get_address_from_coordinates(latitude, longitude)
    
    # Create alert
    alert = Alert(
        user_id=user_id,
        latitude=latitude,
        longitude=longitude,
        address=address,
        severity=severity,
        triggered_by=triggered_by,
        status=AlertStatus.ACTIVE.value,
        notes=notes
    )
    
    db.add(alert)
    db.commit()
    db.refresh(alert)
    
    # Create initial location update
    location_update = LocationUpdate(
        user_id=user_id,
        alert_id=alert.id,
        latitude=latitude,
        longitude=longitude,
        address=address
    )
    db.add(location_update)
    db.commit()
    
    return alert

def update_alert_location(
    db: Session,
    alert_id: int,
    latitude: float,
    longitude: float,
    accuracy: Optional[float] = None,
    speed: Optional[float] = None,
    heading: Optional[float] = None
) -> LocationUpdate:
    """Update location for an active alert"""
    alert = db.query(Alert).filter(Alert.id == alert_id).first()
    if not alert:
        raise ValueError("Alert not found")
    
    if alert.status != AlertStatus.ACTIVE.value:
        raise ValueError("Alert is not active")
    
    address = get_address_from_coordinates(latitude, longitude)
    
    location_update = LocationUpdate(
        user_id=alert.user_id,
        alert_id=alert_id,
        latitude=latitude,
        longitude=longitude,
        address=address,
        accuracy=accuracy,
        speed=speed,
        heading=heading
    )
    
    db.add(location_update)
    db.commit()
    db.refresh(location_update)
    
    return location_update

def resolve_alert(
    db: Session,
    alert_id: int,
    user_id: int
) -> Alert:
    """Mark an alert as resolved"""
    alert = db.query(Alert).filter(
        Alert.id == alert_id,
        Alert.user_id == user_id
    ).first()
    
    if not alert:
        raise ValueError("Alert not found")
    
    alert.status = AlertStatus.RESOLVED.value
    alert.resolved_at = datetime.utcnow()
    
    db.commit()
    db.refresh(alert)
    
    return alert

def escalate_alert(
    db: Session,
    alert_id: int,
    escalated_to: str = "police_112",
    severity: str = "critical"
) -> EmergencyEscalation:
    """Escalate an alert to authorities"""
    alert = db.query(Alert).filter(Alert.id == alert_id).first()
    if not alert:
        raise ValueError("Alert not found")
    
    # Update alert severity if higher
    if severity in ["high", "critical"]:
        alert.severity = severity
    
    # Create escalation record
    priority = 1 if severity == "critical" else 2
    
    escalation = EmergencyEscalation(
        alert_id=alert_id,
        escalated_to=escalated_to,
        severity=severity,
        priority=priority,
        status="pending"
    )
    
    db.add(escalation)
    
    # Update alert status
    if alert.status != AlertStatus.ESCALATED.value:
        alert.status = AlertStatus.ESCALATED.value
        alert.escalated_at = datetime.utcnow()
    
    db.commit()
    db.refresh(escalation)
    
    return escalation

def get_alert_location_history(
    db: Session,
    alert_id: int
) -> list:
    """Get location history for an alert"""
    location_updates = db.query(LocationUpdate).filter(
        LocationUpdate.alert_id == alert_id
    ).order_by(LocationUpdate.timestamp.asc()).all()
    
    return [
        {
            "latitude": loc.latitude,
            "longitude": loc.longitude,
            "address": loc.address,
            "timestamp": loc.timestamp.isoformat(),
            "accuracy": loc.accuracy,
            "speed": loc.speed,
            "heading": loc.heading
        }
        for loc in location_updates
    ]
