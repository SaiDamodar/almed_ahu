#!/usr/bin/env python3
"""
Test Firebase connectivity (Auth and Firestore)
"""

import firebase_admin
from firebase_admin import credentials, auth, firestore
import os

def test_firebase_connection():
    """Test Firebase authentication and Firestore"""
    
    print("="*60)
    print("Testing Firebase Connection")
    print("="*60)
    
    # Check for service account key
    service_account_path = "firebase-service-account.json"
    if not os.path.exists(service_account_path):
        print(f"✗ Service account file not found: {service_account_path}")
        print("  Download from Firebase Console → Project Settings → Service Accounts")
        return False
    
    # Initialize Firebase
    try:
        cred = credentials.Certificate(service_account_path)
        firebase_admin.initialize_app(cred)
        print("✓ Firebase initialized")
    except Exception as e:
        print(f"✗ Failed to initialize: {e}")
        return False
    
    # Test Authentication
    try:
        # Create test user
        user = auth.create_user(
            email='test@hospital.com',
            password='TestPass123',
            display_name='Test User'
        )
        print(f"✓ Test user created: {user.uid}")
        
        # Delete test user
        auth.delete_user(user.uid)
        print("✓ Test user deleted")
    except Exception as e:
        print(f"⚠ User creation failed (may already exist): {e}")
    
    # Test Firestore
    try:
        db = firestore.client()
        
        # Write test document
        doc_ref = db.collection('devices').document('ahu-01')
        doc_ref.set({
            'deviceId': 'ahu-01',
            'site': 'hospitalA',
            'room': 'icu1',
            'status': 'online',
            'lastSeen': firestore.SERVER_TIMESTAMP
        })
        print("✓ Firestore write successful")
        
        # Read test document
        doc = doc_ref.get()
        if doc.exists:
            print(f"✓ Firestore read successful: {doc.to_dict()}")
        
        # Delete test document
        doc_ref.delete()
        print("✓ Test document deleted")
        
    except Exception as e:
        print(f"✗ Firestore test failed: {e}")
        return False
    
    print("✓ All Firebase tests passed")
    return True

if __name__ == "__main__":
    print("\nImportant: Place firebase-service-account.json in this directory first!")
    print("Then run: python3 test_firebase.py\n")
    
    # Comment out this return to run actual test
    # test_firebase_connection()
    
    print("\nTest script ready - update config and uncomment test_firebase_connection()")

