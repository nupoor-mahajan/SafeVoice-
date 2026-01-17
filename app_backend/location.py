"""
Location tracking and Google Maps integration utilities
"""
import os
import requests
from typing import Optional, Tuple

# Google Maps API configuration
GOOGLE_MAPS_API_KEY = os.getenv("GOOGLE_MAPS_API_KEY", "")

def get_address_from_coordinates(latitude: float, longitude: float) -> Optional[str]:
    """Reverse geocode coordinates to get human-readable address"""
    if not GOOGLE_MAPS_API_KEY:
        return None
    
    try:
        url = "https://maps.googleapis.com/maps/api/geocode/json"
        params = {
            "latlng": f"{latitude},{longitude}",
            "key": GOOGLE_MAPS_API_KEY
        }
        response = requests.get(url, params=params, timeout=5)
        data = response.json()
        
        if data.get("status") == "OK" and data.get("results"):
            return data["results"][0].get("formatted_address")
    except Exception as e:
        print(f"Error getting address: {e}")
    
    return None

def generate_google_maps_link(latitude: float, longitude: float) -> str:
    """Generate a Google Maps link for sharing location"""
    return f"https://www.google.com/maps?q={latitude},{longitude}"

def generate_google_maps_embed_url(latitude: float, longitude: float) -> str:
    """Generate Google Maps embed URL for iframe"""
    if GOOGLE_MAPS_API_KEY:
        return f"https://www.google.com/maps/embed/v1/place?key={GOOGLE_MAPS_API_KEY}&q={latitude},{longitude}"
    return generate_google_maps_link(latitude, longitude)

def calculate_distance(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Calculate distance between two coordinates in kilometers using Haversine formula"""
    from math import radians, sin, cos, sqrt, atan2
    
    R = 6371  # Earth's radius in kilometers
    
    lat1_rad = radians(lat1)
    lat2_rad = radians(lat2)
    delta_lat = radians(lat2 - lat1)
    delta_lon = radians(lon2 - lon1)
    
    a = sin(delta_lat / 2) ** 2 + cos(lat1_rad) * cos(lat2_rad) * sin(delta_lon / 2) ** 2
    c = 2 * atan2(sqrt(a), sqrt(1 - a))
    
    return R * c
