# InfluxDB Quick Setup Guide

## Step 1: Create InfluxDB Cloud Account

Go to https://cloud2.influxdata.com/ → Sign up with email → Verify email → Login

---

## Step 2: Create Organization

Click "Create Organization" → Enter name (e.g., "ALMED AHU") → Click "Create"

---

## Step 3: Create Bucket

Go to Data → Buckets → Click "Create Bucket" → Name it "ahu_telemetry" → Click "Create Bucket"

---

## Step 4: Create API Token

Go to Data → API Tokens → Click "Generate API Token" → Select "Read/Write Token" → Click "Save Token" → **Copy and save the token!**

---

## Step 5: Get Connection Details

From your InfluxDB dashboard, copy these values:
- **Organization**: Your org name
- **Bucket**: ahu_telemetry
- **Token**: Your API token
- **URL**: https://us-east-1-1.aws.cloud2.influxdata.com (or your region)

---

## Step 6: Install InfluxDB Client Library

```bash
pip install influxdb-client
```

---

## Step 7: Configure Connection in Python

```python
from influxdb_client import InfluxDBClient

client = InfluxDBClient(
    url="YOUR_URL",
    token="YOUR_TOKEN",
    org="YOUR_ORG"
)

write_api = client.write_api()
```

---

## Step 8: Write Data

```python
# Write sensor data
write_api.write(
    bucket="ahu_telemetry",
    record={
        "measurement": "temperature",
        "tags": {"device": "ahu-01", "location": "icu1"},
        "fields": {"value": 24.5},
        "time": "2025-01-01T00:00:00Z"
    }
)
```

---

## Step 9: Query Data

```python
query_api = client.query_api()

query = '''
from(bucket: "ahu_telemetry")
  |> range(start: -1h)
  |> filter(fn: (r) => r["_measurement"] == "temperature")
'''

result = query_api.query(query=query)
```

---

## Step 10: Test Connection

Run a simple write + query to verify everything works

---

## Done!

Your InfluxDB is ready to store AHU telemetry data.

