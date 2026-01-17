from fastapi import APIRouter, Depends, HTTPException, status, BackgroundTasks
from sqlalchemy.orm import Session
from typing import List, Optional
from datetime import datetime

from database import get_db, User, Alert, Contact
from models import (
    AlertCreate, AlertResponse, AlertUpdate, AlertListResponse,
    LocationUpdate, LocationResponse, EscalationRequest, EscalationResponse,
    VoiceCodeWordDetection
)
from auth import get_current_user
from sos import (
    create_sos_alert, update_alert_location, resolve_alert,
    escalate_alert, get_alert_location_history
)
from notify import notify_trusted_contacts, notify_authorities
from location import generate_google_maps_link

router = APIRouter()

def process_alert_notifications(db: Session, user: User, alert: Alert):
    """Background task to send notifications"""
    # Notify trusted contacts
    notify_trusted_contacts(db, user, alert)
    
    # Auto-escalate critical/high severity alerts to authorities
    if alert.severity in ["high", "critical"]:
        notify_authorities(db, user, alert, "police_112")

@router.post("/trigger", response_model=AlertResponse, status_code=status.HTTP_201_CREATED)
async def trigger_sos(
    alert_data: AlertCreate,
    background_tasks: BackgroundTasks,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Trigger an SOS alert"""
    # Create the alert
    alert = create_sos_alert(
        db=db,
        user_id=current_user.id,
        latitude=alert_data.latitude,
        longitude=alert_data.longitude,
        severity=alert_data.severity.value,
        triggered_by=alert_data.triggered_by,
        notes=alert_data.notes
    )
    
    # Send notifications in background
    background_tasks.add_task(process_alert_notifications, db, current_user, alert)
    
    # Add Google Maps link to response
    response_data = AlertResponse(
        id=alert.id,
        user_id=alert.user_id,
        latitude=alert.latitude,
        longitude=alert.longitude,
        address=alert.address,
        status=alert.status,
        severity=alert.severity,
        triggered_by=alert.triggered_by,
        created_at=alert.created_at,
        resolved_at=alert.resolved_at,
        google_maps_link=generate_google_maps_link(alert.latitude, alert.longitude)
    )
    
    return response_data

@router.post("/voice-trigger", response_model=AlertResponse, status_code=status.HTTP_201_CREATED)
async def trigger_sos_by_voice(
    voice_data: VoiceCodeWordDetection,
    alert_data: AlertCreate,
    background_tasks: BackgroundTasks,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Trigger SOS alert via voice code word detection"""
    # Verify code word matches user's codeword
    detected_word = voice_data.detected_word.lower().strip()
    user_codeword = current_user.codeword.lower().strip()
    
    if detected_word != user_codeword:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Code word does not match"
        )
    
    # Check confidence threshold (optional, can be adjusted)
    if voice_data.confidence < 0.7:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Voice detection confidence too low"
        )
    
    # Create alert with voice trigger
    alert = create_sos_alert(
        db=db,
        user_id=current_user.id,
        latitude=alert_data.latitude,
        longitude=alert_data.longitude,
        severity=alert_data.severity.value,
        triggered_by="voice",
        notes=f"Triggered by voice code word (confidence: {voice_data.confidence:.2f})"
    )
    
    # Send notifications in background
    background_tasks.add_task(process_alert_notifications, db, current_user, alert)
    
    response_data = AlertResponse(
        id=alert.id,
        user_id=alert.user_id,
        latitude=alert.latitude,
        longitude=alert.longitude,
        address=alert.address,
        status=alert.status,
        severity=alert.severity,
        triggered_by=alert.triggered_by,
        created_at=alert.created_at,
        resolved_at=alert.resolved_at,
        google_maps_link=generate_google_maps_link(alert.latitude, alert.longitude)
    )
    
    return response_data

@router.post("/{alert_id}/location", response_model=LocationResponse)
async def update_location(
    alert_id: int,
    location_data: LocationUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Update location for an active alert"""
    alert = db.query(Alert).filter(
        Alert.id == alert_id,
        Alert.user_id == current_user.id
    ).first()
    
    if not alert:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Alert not found"
        )
    
    if alert.status != "active":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Alert is not active"
        )
    
    location_update = update_alert_location(
        db=db,
        alert_id=alert_id,
        latitude=location_data.latitude,
        longitude=location_data.longitude,
        accuracy=location_data.accuracy,
        speed=location_data.speed,
        heading=location_data.heading
    )
    
    return location_update

@router.get("/", response_model=AlertListResponse)
async def get_alerts(
    status_filter: Optional[str] = None,
    limit: int = 50,
    offset: int = 0,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get all alerts for current user"""
    query = db.query(Alert).filter(Alert.user_id == current_user.id)
    
    if status_filter:
        query = query.filter(Alert.status == status_filter)
    
    total = query.count()
    alerts = query.order_by(Alert.created_at.desc()).offset(offset).limit(limit).all()
    
    alert_responses = [
        AlertResponse(
            id=alert.id,
            user_id=alert.user_id,
            latitude=alert.latitude,
            longitude=alert.longitude,
            address=alert.address,
            status=alert.status,
            severity=alert.severity,
            triggered_by=alert.triggered_by,
            created_at=alert.created_at,
            resolved_at=alert.resolved_at,
            google_maps_link=generate_google_maps_link(alert.latitude, alert.longitude)
        )
        for alert in alerts
    ]
    
    return AlertListResponse(alerts=alert_responses, total=total)

@router.get("/{alert_id}", response_model=AlertResponse)
async def get_alert(
    alert_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get a specific alert"""
    alert = db.query(Alert).filter(
        Alert.id == alert_id,
        Alert.user_id == current_user.id
    ).first()
    
    if not alert:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Alert not found"
        )
    
    return AlertResponse(
        id=alert.id,
        user_id=alert.user_id,
        latitude=alert.latitude,
        longitude=alert.longitude,
        address=alert.address,
        status=alert.status,
        severity=alert.severity,
        triggered_by=alert.triggered_by,
        created_at=alert.created_at,
        resolved_at=alert.resolved_at,
        google_maps_link=generate_google_maps_link(alert.latitude, alert.longitude)
    )

@router.get("/{alert_id}/location-history")
async def get_location_history(
    alert_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get location history for an alert"""
    alert = db.query(Alert).filter(
        Alert.id == alert_id,
        Alert.user_id == current_user.id
    ).first()
    
    if not alert:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Alert not found"
        )
    
    history = get_alert_location_history(db, alert_id)
    return {"alert_id": alert_id, "location_history": history, "total_points": len(history)}

@router.put("/{alert_id}/resolve", response_model=AlertResponse)
async def resolve_alert_endpoint(
    alert_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Mark an alert as resolved"""
    alert = resolve_alert(db, alert_id, current_user.id)
    
    return AlertResponse(
        id=alert.id,
        user_id=alert.user_id,
        latitude=alert.latitude,
        longitude=alert.longitude,
        address=alert.address,
        status=alert.status,
        severity=alert.severity,
        triggered_by=alert.triggered_by,
        created_at=alert.created_at,
        resolved_at=alert.resolved_at,
        google_maps_link=generate_google_maps_link(alert.latitude, alert.longitude)
    )

@router.put("/{alert_id}", response_model=AlertResponse)
async def update_alert(
    alert_id: int,
    alert_update: AlertUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Update an alert"""
    alert = db.query(Alert).filter(
        Alert.id == alert_id,
        Alert.user_id == current_user.id
    ).first()
    
    if not alert:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Alert not found"
        )
    
    if alert_update.status:
        alert.status = alert_update.status.value
        if alert_update.status.value == "resolved":
            alert.resolved_at = datetime.utcnow()
    
    if alert_update.severity:
        alert.severity = alert_update.severity.value
    
    if alert_update.notes:
        alert.notes = alert_update.notes
    
    db.commit()
    db.refresh(alert)
    
    return AlertResponse(
        id=alert.id,
        user_id=alert.user_id,
        latitude=alert.latitude,
        longitude=alert.longitude,
        address=alert.address,
        status=alert.status,
        severity=alert.severity,
        triggered_by=alert.triggered_by,
        created_at=alert.created_at,
        resolved_at=alert.resolved_at,
        google_maps_link=generate_google_maps_link(alert.latitude, alert.longitude)
    )

@router.post("/{alert_id}/escalate", response_model=EscalationResponse)
async def escalate_alert_endpoint(
    alert_id: int,
    escalation_data: EscalationRequest,
    background_tasks: BackgroundTasks,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Escalate an alert to authorities"""
    alert = db.query(Alert).filter(
        Alert.id == alert_id,
        Alert.user_id == current_user.id
    ).first()
    
    if not alert:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Alert not found"
        )
    
    escalation = escalate_alert(
        db=db,
        alert_id=alert_id,
        escalated_to=escalation_data.escalated_to,
        severity=escalation_data.severity.value
    )
    
    # Notify authorities in background
    background_tasks.add_task(notify_authorities, db, current_user, alert, escalation_data.escalated_to)
    
    return EscalationResponse(
        id=escalation.id,
        alert_id=escalation.alert_id,
        escalated_to=escalation.escalated_to,
        severity=escalation.severity,
        priority=escalation.priority,
        status=escalation.status,
        created_at=escalation.created_at
    )
