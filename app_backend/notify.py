"""
Notification system for sending alerts to contacts and authorities
"""
import os
import requests
from sqlalchemy.orm import Session
from typing import List, Optional
from datetime import datetime

from database import Contact, Alert, Notification, User
from location import generate_google_maps_link, get_address_from_coordinates

# SMS/Email service configuration
TWILIO_ACCOUNT_SID = os.getenv("TWILIO_ACCOUNT_SID", "")
TWILIO_AUTH_TOKEN = os.getenv("TWILIO_AUTH_TOKEN", "")
TWILIO_PHONE_NUMBER = os.getenv("TWILIO_PHONE_NUMBER", "")

SENDGRID_API_KEY = os.getenv("SENDGRID_API_KEY", "")
FROM_EMAIL = os.getenv("FROM_EMAIL", "noreply@safevoice.app")

def send_sms(phone: str, message: str) -> bool:
    """Send SMS using Twilio"""
    if not all([TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, TWILIO_PHONE_NUMBER]):
        print(f"[SMS] Would send to {phone}: {message}")
        return False
    
    try:
        url = f"https://api.twilio.com/2010-04-01/Accounts/{TWILIO_ACCOUNT_SID}/Messages.json"
        data = {
            "From": TWILIO_PHONE_NUMBER,
            "To": phone,
            "Body": message
        }
        response = requests.post(
            url,
            data=data,
            auth=(TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN),
            timeout=10
        )
        return response.status_code == 201
    except Exception as e:
        print(f"Error sending SMS: {e}")
        return False

def send_email(email: str, subject: str, message: str) -> bool:
    """Send email using SendGrid"""
    if not SENDGRID_API_KEY:
        print(f"[EMAIL] Would send to {email}: {subject} - {message}")
        return False
    
    try:
        url = "https://api.sendgrid.com/v3/mail/send"
        headers = {
            "Authorization": f"Bearer {SENDGRID_API_KEY}",
            "Content-Type": "application/json"
        }
        data = {
            "personalizations": [{
                "to": [{"email": email}],
                "subject": subject
            }],
            "from": {"email": FROM_EMAIL},
            "content": [{
                "type": "text/plain",
                "value": message
            }]
        }
        response = requests.post(url, json=data, headers=headers, timeout=10)
        return response.status_code == 202
    except Exception as e:
        print(f"Error sending email: {e}")
        return False

def create_alert_message(user: User, alert: Alert, maps_link: str) -> str:
    """Create alert message for contacts"""
    address = alert.address or f"{alert.latitude}, {alert.longitude}"
    severity_emoji = {
        "low": "⚠️",
        "medium": "🚨",
        "high": "🔴",
        "critical": "🆘"
    }
    emoji = severity_emoji.get(alert.severity, "🚨")
    
    message = f"""{emoji} EMERGENCY ALERT - {user.name.upper()}

{user.name} has triggered an emergency alert!

📍 Location: {address}
🔗 Track Live: {maps_link}
⏰ Time: {alert.created_at.strftime('%Y-%m-%d %H:%M:%S')}
⚠️ Severity: {alert.severity.upper()}

Please check on them immediately and contact authorities if needed.

Stay safe!"""
    
    return message

def notify_trusted_contacts(
    db: Session,
    user: User,
    alert: Alert,
    contacts: Optional[List[Contact]] = None
) -> List[Notification]:
    """Notify all trusted contacts about an emergency alert"""
    if contacts is None:
        contacts = db.query(Contact).filter(Contact.user_id == user.id).all()
    
    if not contacts:
        return []
    
    maps_link = generate_google_maps_link(alert.latitude, alert.longitude)
    message = create_alert_message(user, alert, maps_link)
    
    notifications = []
    
    for contact in contacts:
        # Send SMS
        if contact.phone:
            sms_sent = send_sms(contact.phone, message)
            notification = Notification(
                alert_id=alert.id,
                contact_id=contact.id,
                recipient_type="contact",
                recipient_phone=contact.phone,
                message=message,
                status="sent" if sms_sent else "failed"
            )
            db.add(notification)
            notifications.append(notification)
        
        # Send Email
        if contact.email:
            email_subject = f"🚨 Emergency Alert: {user.name} needs help!"
            email_sent = send_email(contact.email, email_subject, message)
            notification = Notification(
                alert_id=alert.id,
                contact_id=contact.id,
                recipient_type="contact",
                recipient_email=contact.email,
                message=message,
                status="sent" if email_sent else "failed"
            )
            db.add(notification)
            notifications.append(notification)
    
    db.commit()
    return notifications

def notify_authorities(
    db: Session,
    user: User,
    alert: Alert,
    authority_type: str = "police_112"
) -> Notification:
    """Notify authorities (police, emergency services)"""
    maps_link = generate_google_maps_link(alert.latitude, alert.longitude)
    address = alert.address or f"{alert.latitude}, {alert.longitude}"
    
    if authority_type == "police_112":
        # Emergency number 112 (European emergency number)
        # In production, this would integrate with actual emergency services API
        authority_phone = "112"  # This would be configured per region
        message = f"""EMERGENCY ALERT - HIGH PRIORITY

User: {user.name}
Phone: {user.phone}
Location: {address}
Coordinates: {alert.latitude}, {alert.longitude}
Live Tracking: {maps_link}
Severity: {alert.severity.upper()}
Time: {alert.created_at.strftime('%Y-%m-%d %H:%M:%S')}

IMMEDIATE RESPONSE REQUIRED"""
        
        # In production, this would call the actual emergency services API
        # For now, we log it
        print(f"[AUTHORITY ALERT] Would send to {authority_phone}: {message}")
        
        notification = Notification(
            alert_id=alert.id,
            recipient_type="authority",
            recipient_phone=authority_phone,
            message=message,
            status="sent"
        )
        db.add(notification)
        db.commit()
        return notification
    
    return None
