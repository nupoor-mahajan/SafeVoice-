from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List

from database import get_db, User, Contact
from models import ContactCreate, ContactResponse, ContactUpdate
from auth import get_current_user

router = APIRouter()

@router.post("/", response_model=ContactResponse, status_code=status.HTTP_201_CREATED)
async def create_contact(
    contact_data: ContactCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Add a trusted contact"""
    existing_contact = db.query(Contact).filter(
        Contact.user_id == current_user.id,
        Contact.phone == contact_data.phone
    ).first()
    
    if existing_contact:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Contact with this phone number already exists"
        )
    
    if contact_data.is_primary:
        db.query(Contact).filter(
            Contact.user_id == current_user.id,
            Contact.is_primary == True
        ).update({"is_primary": False})
    
    new_contact = Contact(
        user_id=current_user.id,
        name=contact_data.name,
        phone=contact_data.phone,
        email=contact_data.email,
        relation=contact_data.relation,
        is_primary=contact_data.is_primary
    )
    
    db.add(new_contact)
    db.commit()
    db.refresh(new_contact)
    
    return new_contact

@router.get("/", response_model=List[ContactResponse])
async def get_contacts(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get all trusted contacts"""
    contacts = db.query(Contact).filter(Contact.user_id == current_user.id).all()
    return contacts

@router.post("/open/", response_model=ContactResponse, status_code=status.HTTP_201_CREATED)
async def create_contact_open(
    contact_data: ContactCreate,
    db: Session = Depends(get_db)
):
    """Add a trusted contact without authentication, using the first user in DB (dev/demo use)"""
    current_user = db.query(User).first()
    if not current_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No user found to attach contact"
        )

    existing_contact = db.query(Contact).filter(
        Contact.user_id == current_user.id,
        Contact.phone == contact_data.phone
    ).first()

    if existing_contact:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Contact with this phone number already exists"
        )

    if contact_data.is_primary:
        db.query(Contact).filter(
            Contact.user_id == current_user.id,
            Contact.is_primary == True
        ).update({"is_primary": False})

    new_contact = Contact(
        user_id=current_user.id,
        name=contact_data.name,
        phone=contact_data.phone,
        email=contact_data.email,
        relation=contact_data.relation,
        is_primary=contact_data.is_primary
    )

    db.add(new_contact)
    db.commit()
    db.refresh(new_contact)

    return new_contact

@router.get("/open/", response_model=List[ContactResponse])
async def get_contacts_open(
    db: Session = Depends(get_db)
):
    """Get all trusted contacts without authentication, using the first user in DB (dev/demo use)"""
    current_user = db.query(User).first()
    if not current_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No user found to read contacts"
        )

    contacts = db.query(Contact).filter(Contact.user_id == current_user.id).all()
    return contacts

@router.get("/{contact_id}", response_model=ContactResponse)
async def get_contact(
    contact_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get a specific contact"""
    contact = db.query(Contact).filter(
        Contact.id == contact_id,
        Contact.user_id == current_user.id
    ).first()
    
    if not contact:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Contact not found"
        )
    
    return contact

@router.put("/{contact_id}", response_model=ContactResponse)
async def update_contact(
    contact_id: int,
    contact_update: ContactUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Update a contact"""
    contact = db.query(Contact).filter(
        Contact.id == contact_id,
        Contact.user_id == current_user.id
    ).first()
    
    if not contact:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Contact not found"
        )
    
    if contact_update.is_primary is True:
        db.query(Contact).filter(
            Contact.user_id == current_user.id,
            Contact.id != contact_id,
            Contact.is_primary == True
        ).update({"is_primary": False})
    
    if contact_update.name:
        contact.name = contact_update.name
    if contact_update.phone:
        contact.phone = contact_update.phone
    if contact_update.email is not None:
        contact.email = contact_update.email
    if contact_update.relation:
        contact.relation = contact_update.relation
    if contact_update.is_primary is not None:
        contact.is_primary = contact_update.is_primary
    
    db.commit()
    db.refresh(contact)
    
    return contact

@router.delete("/{contact_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_contact(
    contact_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Delete a contact"""
    contact = db.query(Contact).filter(
        Contact.id == contact_id,
        Contact.user_id == current_user.id
    ).first()
    
    if not contact:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Contact not found"
        )
    
    db.delete(contact)
    db.commit()
    
    return None

@router.delete("/open/{contact_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_contact_open(
    contact_id: int,
    db: Session = Depends(get_db)
):
    """Delete a contact without authentication, using the first user in DB (dev/demo use)"""
    current_user = db.query(User).first()
    if not current_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No user found to delete contact"
        )

    contact = db.query(Contact).filter(
        Contact.id == contact_id,
        Contact.user_id == current_user.id
    ).first()

    if not contact:
      # For dev/demo, return 204 even if contact is missing,
      # so frontend doesn't break if already removed.
      return None

    db.delete(contact)
    db.commit()

    return None
