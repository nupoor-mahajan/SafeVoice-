from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from typing import List

from database import get_db, User, LocationUpdate
from models import LocationUpdate as LocationUpdateModel, LocationResponse
from auth import get_current_user
from location import get_address_from_coordinates

router = APIRouter()

@router.post("/update", response_model=LocationResponse)
async def update_user_location(
    location_data: LocationUpdateModel,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Update user's current location (for tracking)"""
    address = get_address_from_coordinates(
        location_data.latitude,
        location_data.longitude
    )
    
    location_update = LocationUpdate(
        user_id=current_user.id,
        latitude=location_data.latitude,
        longitude=location_data.longitude,
        address=address,
        accuracy=location_data.accuracy,
        speed=location_data.speed,
        heading=location_data.heading
    )
    
    db.add(location_update)
    db.commit()
    db.refresh(location_update)
    
    return location_update

@router.get("/history", response_model=List[LocationResponse])
async def get_location_history(
    limit: int = 100,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get user's location history"""
    locations = db.query(LocationUpdate).filter(
        LocationUpdate.user_id == current_user.id
    ).order_by(LocationUpdate.timestamp.desc()).limit(limit).all()
    
    return locations
