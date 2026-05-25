"""
Configuration file for ALMED AHU Web Dashboard
Copy this to config.py and update with your AWS credentials
"""

import os

# AWS Configuration
AWS_REGION = 'ap-south-1'  # Change to your region
AWS_ACCESS_KEY_ID = 'AKIAXJ5YBP2HHKNQ334T'  # Set directly or use: os.getenv('AWS_ACCESS_KEY_ID', '')
AWS_SECRET_ACCESS_KEY = '3L6R2WDezRxDZfpPbNenkIS6Amb+lOwkMvHWNnAA'  # Set directly or use: os.getenv('AWS_SECRET_ACCESS_KEY', '')

# AWS IoT Core
AWS_IOT_ENDPOINT = 'al924mkqhctlg-ats.iot.ap-south-1.amazonaws.com'  # Your IoT endpoint
AWS_IOT_TOPIC_PUBLISH = 'esp32/pub'
AWS_IOT_TOPIC_SUBSCRIBE = 'esp32/sub'
# OTA: set True only if you must also publish to esp32/sub (legacy). Prefer per-thing topics only.
# OTA_ALSO_PUBLISH_SHARED_SUBSCRIBE = False

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
HOST = '0.0.0.0'
PORT = 5000

# Admin Configuration
ADMIN_USERNAME = 'admin'  # Change in production!
ADMIN_PASSWORD = '1234'  # Change in production!
ADMIN_PASSCODE = '1234'  # Change in production! (for backward compatibility)

# CORS Configuration
CORS_ORIGINS = ['*']  # Restrict in production

# GitHub OTA Configuration
GITHUB_TOKEN = os.getenv('GITHUB_TOKEN', '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')  # GitHub Personal Access Token with repo permissions
GITHUB_REPO_OWNER = os.getenv('GITHUB_REPO_OWNER', 'ESPUpdaterzaid')  # Your GitHub username/organization
GITHUB_REPO_NAME = os.getenv('GITHUB_REPO_NAME', 'almed-esp32-firmware')  # Repository name for ESP32 firmware (e.g., 'almed-esp32-firmware')
GITHUB_REPO_BRANCH = os.getenv('GITHUB_REPO_BRANCH', 'main')  # Branch to push firmware to
GITHUB_FIRMWARE_PATH = os.getenv('GITHUB_FIRMWARE_PATH', 'firmware/esp32_main.ino')  # Path in repo for firmware file
GITHUB_FIRMWARE_ASSET_NAME = os.getenv('GITHUB_FIRMWARE_ASSET_NAME', 'esp32_main.ino.bin')  # Name of .bin file in GitHub Releases

