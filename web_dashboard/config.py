"""
Configuration file for ALMED AHU Web Dashboard
Copy this to config.py and update with your AWS credentials
"""

import os

# AWS Configuration
AWS_REGION = os.getenv('AWS_REGION', 'ap-south-1')
AWS_ACCESS_KEY_ID = os.getenv('AWS_ACCESS_KEY_ID', 'AKIAXJ5YBP2HHKNQ334T')
AWS_SECRET_ACCESS_KEY = os.getenv('AWS_SECRET_ACCESS_KEY', '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')

# AWS IoT Core
AWS_IOT_ENDPOINT = os.getenv('AWS_IOT_ENDPOINT', 'al924mkqhctlg-ats.iot.ap-south-1.amazonaws.com')
AWS_IOT_TOPIC_PUBLISH = os.getenv('AWS_IOT_TOPIC_PUBLISH', 'esp32/pub')
AWS_IOT_TOPIC_SUBSCRIBE = os.getenv('AWS_IOT_TOPIC_SUBSCRIBE', 'esp32/sub')

# MongoDB Atlas (historical data storage)
MONGO_URI = os.getenv(
    'MONGO_URI',
    'mongodb+srv://almed_user_db:KpMUufXy4D5tNaWK@almed-ahu-cluster.ffdxv72.mongodb.net/?retryWrites=true&w=majority&appName=almed-ahu-cluster'
)
MONGO_DB_NAME = os.getenv('MONGO_DB_NAME', 'almed_ahu')
MONGO_COLLECTION = os.getenv('MONGO_COLLECTION', 'telemetry')

# Flask Configuration
SECRET_KEY = os.getenv('SECRET_KEY', 'change-this-secret-key-in-production')
DEBUG = os.getenv('FLASK_DEBUG', 'False').lower() == 'true'
HOST = os.getenv('HOST', '0.0.0.0')
# Railway sets PORT automatically, fallback to 5000 for local development
PORT = int(os.getenv('PORT', 5000))

# SSL Configuration
SSL_ENABLED = os.getenv('SSL_ENABLED', 'True').lower() == 'true'
# For Let's Encrypt (recommended for production):
# SSL_CERT_PATH = os.getenv('SSL_CERT_PATH', '/etc/letsencrypt/live/app.almedequipments.in/fullchain.pem')
# SSL_KEY_PATH = os.getenv('SSL_KEY_PATH', '/etc/letsencrypt/live/app.almedequipments.in/privkey.pem')
# For self-signed (development only):
SSL_CERT_PATH = '/etc/letsencrypt/live/app.almedequipments.in/fullchain.pem'
SSL_KEY_PATH = '/etc/letsencrypt/live/app.almedequipments.in/privkey.pem'
HTTPS_PORT = int(os.getenv('HTTPS_PORT', 443))

# Admin Configuration
ADMIN_USERNAME = os.getenv('ADMIN_USERNAME', 'admin')
ADMIN_PASSWORD = os.getenv('ADMIN_PASSWORD', '1234')
ADMIN_PASSCODE = os.getenv('ADMIN_PASSCODE', '1234')  # For backward compatibility

# CORS Configuration
# Allow specific origins in production, use '*' for development
CORS_ORIGINS_STR = os.getenv('CORS_ORIGINS', '*')
CORS_ORIGINS = CORS_ORIGINS_STR.split(',') if ',' in CORS_ORIGINS_STR else [CORS_ORIGINS_STR] if CORS_ORIGINS_STR != '*' else ['*']

# GitHub OTA Configuration - ESP32
GITHUB_TOKEN = os.getenv('GITHUB_TOKEN', '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')  # GitHub Personal Access Token with repo permissions
GITHUB_REPO_OWNER = os.getenv('GITHUB_REPO_OWNER', 'ESPUpdaterzaid')  # Your GitHub username/organization
GITHUB_REPO_NAME = os.getenv('GITHUB_REPO_NAME', 'almed-esp32-firmware')  # Repository name for ESP32 firmware (e.g., 'almed-esp32-firmware')
GITHUB_REPO_BRANCH = os.getenv('GITHUB_REPO_BRANCH', 'main')  # Branch to push firmware to
GITHUB_FIRMWARE_PATH = os.getenv('GITHUB_FIRMWARE_PATH', 'firmware/esp32_main.ino')  # Path in repo for firmware file
GITHUB_FIRMWARE_ASSET_NAME = os.getenv('GITHUB_FIRMWARE_ASSET_NAME', 'esp32_main.ino.bin')  # Name of .bin file in GitHub Releases

# GitHub OTA Configuration - RPi Dashboard
RPI_GITHUB_REPO_NAME = os.getenv('RPI_GITHUB_REPO_NAME', 'almed-rpi-dashboard')  # Repository for RPi dashboard releases

# Local MQTT Broker (for RPi OTA communication)
LOCAL_MQTT_BROKER = os.getenv('LOCAL_MQTT_BROKER', '10.42.0.1')
LOCAL_MQTT_PORT = int(os.getenv('LOCAL_MQTT_PORT', '1883'))
LOCAL_MQTT_USERNAME = os.getenv('LOCAL_MQTT_USERNAME', 'ahu_user')
LOCAL_MQTT_PASSWORD = os.getenv('LOCAL_MQTT_PASSWORD', 'ahu_pass_2024')

# Firebase Cloud Messaging Configuration
# Path to Firebase service account JSON file (download from Firebase Console > Project Settings > Service Accounts)
FIREBASE_SERVICE_ACCOUNT_PATH = os.getenv('FIREBASE_SERVICE_ACCOUNT_PATH', 'firebase-service-account.json')
# Or use inline credentials (base64 encoded JSON)
FIREBASE_SERVICE_ACCOUNT_JSON = os.getenv('FIREBASE_SERVICE_ACCOUNT_JSON', '')

