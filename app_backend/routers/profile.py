from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from database import get_db, User
from models import UserProfile, UserProfileUpdate, UserStats
from auth import get_current_user
from datetime import datetime

router = APIRouter()

@router.get("/", response_model=UserProfile)
async def get_profile(current_user: User = Depends(get_current_user)):
    """Get user profile"""
    return current_user

@router.put("/", response_model=UserProfile)
async def update_profile(
    profile_update: UserProfileUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Update user profile"""
    if profile_update.email and profile_update.email != current_user.email:
        existing_user = db.query(User).filter(User.email == profile_update.email).first()
        if existing_user:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Email already registered"
            )
        current_user.email = profile_update.email
    
    if profile_update.name:
        current_user.name = profile_update.name
    
    if profile_update.codeword:
        current_user.codeword = profile_update.codeword.lower().strip()
    
    current_user.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(current_user)
    
    return current_user

@router.get("/stats", response_model=UserStats)
async def get_user_stats(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get user statistics"""
    from database import Alert, Contact
    
    total_alerts = db.query(Alert).filter(Alert.user_id == current_user.id).count()
    active_alerts = db.query(Alert).filter(
        Alert.user_id == current_user.id,
        Alert.status == "active"
    ).count()
    total_contacts = db.query(Contact).filter(Contact.user_id == current_user.id).count()
    
    last_alert = db.query(Alert).filter(
        Alert.user_id == current_user.id
    ).order_by(Alert.created_at.desc()).first()
    
    return UserStats(
        total_alerts=total_alerts,
        active_alerts=active_alerts,
        total_contacts=total_contacts,
        last_alert_at=last_alert.created_at if last_alert else None
    )
