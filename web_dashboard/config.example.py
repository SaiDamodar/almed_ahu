"""
Configuration file for ALMED AHU Web Dashboard
Copy this to config.py and update with your AWS credentials
"""

import os

# AWS Configuration
AWS_REGION = 'ap-south-1'  # Change to your region
AWS_ACCESS_KEY_ID = 'AKIAXJ5YBP2HHKNQ334T'
AWS_SECRET_ACCESS_KEY = '3L6R2WDezRxDZfpPbNenkIS6Amb+lOwkMvHWNnAA'
# AWS IoT Core
AWS_IOT_ENDPOINT = 'al924mkqhctlg-ats.iot.ap-south-1.amazonaws.com'  # Your IoT endpoint
AWS_IOT_TOPIC_PUBLISH = 'esp32/pub'
AWS_IOT_TOPIC_SUBSCRIBE = 'esp32/sub'

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
ADMIN_PASSCODE = '1234'  # Change in production!

# CORS Configuration
CORS_ORIGINS = ['*']  # Restrict in production

