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

# DynamoDB
DYNAMODB_TABLE_NAME = 'AHU_ESP2_AWSDB'
DYNAMODB_REGION = AWS_REGION

# Local MQTT (Raspberry Pi) - Optional fallback
LOCAL_MQTT_BROKER = '10.42.0.1'
LOCAL_MQTT_PORT = 1883
LOCAL_MQTT_USERNAME = 'almed'
LOCAL_MQTT_PASSWORD = 'Almed1234$'

# Flask Configuration
SECRET_KEY = os.getenv('SECRET_KEY', 'change-this-secret-key-in-production')
DEBUG = os.getenv('FLASK_DEBUG', 'False').lower() == 'true'
HOST = '0.0.0.0'
PORT = 5000

# Admin Configuration
ADMIN_PASSCODE = '1234'  # Change in production!

# CORS Configuration
CORS_ORIGINS = ['*']  # Restrict in production

