# ALMED AHU Web Dashboard

Modern web dashboard for ALMED AHU system with AWS IoT Core and DynamoDB integration.

## Architecture

```
ESP32 → AWS IoT Core → DynamoDB
                ↓
         Python Flask API
                ↓
         Web Dashboard (HTML/CSS/JS)
```

## Features

- **Hospitals → Devices View**: Hierarchical view of all hospitals and their AHU devices
- **AHU Control Page**: Full control interface matching Flutter dashboard
- **Graphs & Analytics**: Temperature, humidity, motor cycles visualization
- **Settings Page**: Admin configuration (WiFi, broker, motor timings)
- **OTA Updates**: Over-the-air firmware updates (placeholder)

## Setup

### Prerequisites

1. Python 3.8+
2. AWS Account with:
   - IoT Core configured
   - DynamoDB table created
   - IAM role with permissions

### Installation

```bash
cd web_dashboard
pip install -r requirements.txt
```

### Configuration

1. Copy `config.example.py` to `config.py`
2. Update AWS credentials and settings
3. Configure DynamoDB table name
4. Set MQTT broker details

### Run

```bash
python app.py
```

Access at: http://localhost:5000

## Project Structure

```
web_dashboard/
├── app.py                 # Flask application
├── config.py              # Configuration (create from config.example.py)
├── requirements.txt       # Python dependencies
├── static/
│   ├── css/
│   │   └── style.css     # Main stylesheet
│   ├── js/
│   │   ├── app.js        # Main application logic
│   │   ├── charts.js     # Chart.js integration
│   │   └── api.js        # API client
│   └── images/           # Images and logos
└── templates/
    ├── index.html        # Main dashboard
    ├── hospitals.html    # Hospitals → Devices view
    ├── ahu_control.html   # AHU control page
    ├── graphs.html       # Graphs and analytics
    ├── settings.html     # Admin settings
    └── ota.html          # OTA updates (placeholder)
```

## AWS Setup

### DynamoDB Table

- **Table Name**: `AHU_Telemetry_DB`
- **Partition Key**: `device_id` (String)
- **Sort Key**: `timestamp` (Number)

### AWS IoT Core Rule

SQL Statement:
```sql
SELECT * FROM 'esp32/pub' WHERE type = 'telemetry'
```

Action: DynamoDB
- Table: `AHU_Telemetry_DB`
- Partition Key: `${thing}`
- Sort Key: `${ts}`

## Admin Access

Default admin passcode: `1234` (change in production!)

