from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from database import init_db

# Create FastAPI app
app = FastAPI(
    title="SAFE-VOICE API",
    description="Voice-Activated Emergency Alert System for Women",
    version="1.0.0"
)

# CORS middleware for frontend integration
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, specify your frontend domain
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Create database on startup
@app.on_event("startup")
def startup_event():
    init_db()
    print("🚀 SAFE-VOICE Backend Server Started")

@app.get("/")
def read_root():
    return {
        "message": "SAFE-VOICE Backend Ready 🚨",
        "version": "1.0.0",
        "status": "operational"
    }

@app.get("/health")
def health_check():
    return {"status": "healthy"}

# Import and include routers
try:
    from routers import auth, profile, contacts, sos, location
except ImportError:
    # Fallback for direct execution
    import sys
    import os
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    from routers import auth, profile, contacts, sos, location

app.include_router(auth.router, prefix="/auth", tags=["Authentication"])
app.include_router(profile.router, prefix="/profile", tags=["User Profile"])
app.include_router(contacts.router, prefix="/contacts", tags=["Trusted Contacts"])
app.include_router(sos.router, prefix="/sos", tags=["SOS Alerts"])
app.include_router(location.router, prefix="/location", tags=["Location Tracking"])

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
