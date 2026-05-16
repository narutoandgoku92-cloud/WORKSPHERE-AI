#!/usr/bin/env python3
"""
backend/seed_data.py - Database seeding script
Creates default organization and admin user for testing
"""

import sys
import os
from dotenv import load_dotenv

# Add backend directory to path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

# Load environment variables from .env file (project root)
env_path = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), '.env')
load_dotenv(env_path)
print(f"📄 Loading .env from: {env_path}")

from sqlalchemy.orm import Session
from core.database import engine, SessionLocal, Base, init_db
from core.security import hash_password
from models import Organization, User, Employee, Department, Geofence
import uuid

# Default credentials
DEFAULT_ORG_NAME = "OptiWork Demo"
DEFAULT_ORG_EMAIL = "demo@optiwork.ai"
DEFAULT_ADMIN_EMAIL = "admin@optiwork.ai"
DEFAULT_ADMIN_PASSWORD = "password123"
DEFAULT_ADMIN_NAME = "Admin User"
DEFAULT_EMPLOYEE_EMAIL = "emp@optiwork.ai"
DEFAULT_EMPLOYEE_PASSWORD = "password123"
DEFAULT_EMPLOYEE_NAME = "Demo Employee"


def seed_database():
    """Seed the database with default data"""
    print("🌱 Starting database seeding...")
    
    # Initialize database (create tables)
    print("📦 Creating database tables...")
    Base.metadata.create_all(bind=engine)
    print("✅ Database tables created")
    
    db = SessionLocal()
    try:
        # Check if default organization already exists
        default_org = db.query(Organization).filter(
            Organization.email == DEFAULT_ORG_EMAIL
        ).first()
        
        if not default_org:
            # Create default organization
            print(f"🏢 Creating organization: {DEFAULT_ORG_NAME}")
            default_org = Organization(
                id="default",
                name=DEFAULT_ORG_NAME,
                email=DEFAULT_ORG_EMAIL,
                phone="+1-555-0100",
                address="123 Demo Street",
                city="San Francisco",
                country="USA",
                subscription_plan="pro",
                is_active=True
            )
            db.add(default_org)
            db.commit()
            db.refresh(default_org)
            print(f"✅ Organization created with ID: {default_org.id}")
        else:
            print(f"ℹ️  Organization already exists: {default_org.name}")
        
        # Check if default admin user already exists
        admin_user = db.query(User).filter(
            User.email == DEFAULT_ADMIN_EMAIL
        ).first()
        
        if not admin_user:
            # Create default admin user
            print(f"👤 Creating admin user: {DEFAULT_ADMIN_NAME}")
            admin_user = User(
                id=str(uuid.uuid4()),
                org_id=default_org.id,
                email=DEFAULT_ADMIN_EMAIL,
                password_hash=hash_password(DEFAULT_ADMIN_PASSWORD),
                full_name=DEFAULT_ADMIN_NAME,
                role="admin",
                is_active=True
            )
            db.add(admin_user)
            db.commit()
            db.refresh(admin_user)
            print(f"✅ Admin user created with ID: {admin_user.id}")
        else:
            print(f"ℹ️  Admin user already exists: {admin_user.email}")
        
        # Check if default employee already exists
        emp_employee = db.query(Employee).filter(
            Employee.email == DEFAULT_EMPLOYEE_EMAIL
        ).first()
        
        if not emp_employee:
            # Create default employee
            print(f"👷 Creating employee: {DEFAULT_EMPLOYEE_NAME}")
            emp_employee = Employee(
                id=str(uuid.uuid4()),
                org_id=default_org.id,
                employee_id="EMP001",
                full_name=DEFAULT_EMPLOYEE_NAME,
                email=DEFAULT_EMPLOYEE_EMAIL,
                phone="+1-555-0101",
                job_title="Software Engineer",
                salary_per_hour=25.0,
                hire_date=None,
                status="active",
                is_verified=False
            )
            db.add(emp_employee)
            db.commit()
            db.refresh(emp_employee)
            print(f"✅ Employee created with ID: {emp_employee.id}")
        else:
            print(f"ℹ️  Employee already exists: {emp_employee.email}")
        
        # Create a default geofence for testing
        geofence = db.query(Geofence).filter(
            Geofence.org_id == default_org.id
        ).first()
        
        if not geofence:
            print("📍 Creating default geofence...")
            geofence = Geofence(
                id=str(uuid.uuid4()),
                org_id=default_org.id,
                name="Office HQ",
                latitude=37.7749,  # San Francisco
                longitude=-122.4194,
                radius_meters=100.0,
                description="Main office geofence",
                is_active=True
            )
            db.add(geofence)
            db.commit()
            print("✅ Geofence created")
        else:
            print("ℹ️  Geofence already exists")
        
        print("\n" + "=" * 50)
        print("🎉 Database seeding completed successfully!")
        print("=" * 50)
        print(f"\n📋 Demo Credentials:")
        print(f"   Admin:   {DEFAULT_ADMIN_EMAIL} / {DEFAULT_ADMIN_PASSWORD}")
        print(f"   Employee: {DEFAULT_EMPLOYEE_EMAIL} / {DEFAULT_EMPLOYEE_PASSWORD}")
        print(f"\n🏢 Organization: {DEFAULT_ORG_NAME}")
        print(f"📍 Geofence: San Francisco (lat: 37.7749, lng: -122.4194)")
        
    except Exception as e:
        db.rollback()
        print(f"❌ Error during seeding: {e}")
        raise
    finally:
        db.close()


if __name__ == "__main__":
    seed_database()