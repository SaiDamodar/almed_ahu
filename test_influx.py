#!/usr/bin/env python3
"""
Test InfluxDB connectivity and data writing
"""

from influxdb_client import InfluxDBClient, Point
from datetime import datetime
import time

# InfluxDB Configuration
INFLUX_URL = "YOUR_INFLUX_URL"
INFLUX_TOKEN = "YOUR_TOKEN"
INFLUX_ORG = "YOUR_ORG"
INFLUX_BUCKET = "ahu_telemetry"

def test_influx_connection():
    """Test InfluxDB connection and write sample data"""
    
    print("="*60)
    print("Testing InfluxDB Connection")
    print("="*60)
    
    # Create client
    try:
        client = InfluxDBClient(
            url=INFLUX_URL,
            token=INFLUX_TOKEN,
            org=INFLUX_ORG
        )
        print("✓ InfluxDB client created")
    except Exception as e:
        print(f"✗ Failed to create client: {e}")
        return False
    
    # Get write API
    write_api = client.write_api()
    
    # Create test data point
    point = Point("ahu_sensors") \
        .tag("device_id", "ahu-01") \
        .tag("site", "hospitalA") \
        .tag("room", "icu1") \
        .field("temperature", 24.5) \
        .field("humidity", 60.0) \
        .field("fanSpeed", 1) \
        .field("motor1", False) \
        .field("motor2", False) \
        .field("compressor", True) \
        .field("heater", False) \
        .time(datetime.utcnow())
    
    # Write to InfluxDB
    try:
        write_api.write(bucket=INFLUX_BUCKET, record=point)
        print("✓ Data written to InfluxDB")
    except Exception as e:
        print(f"✗ Failed to write data: {e}")
        return False
    
    # Query test
    query_api = client.query_api()
    query = f'''
    from(bucket: "{INFLUX_BUCKET}")
      |> range(start: -1h)
      |> filter(fn: (r) => r["_measurement"] == "ahu_sensors")
      |> filter(fn: (r) => r["device_id"] == "ahu-01")
      |> last()
    '''
    
    try:
        result = query_api.query(query=query)
        print("✓ Query successful")
        for table in result:
            for record in table.records:
                print(f"  {record.get_field()}: {record.get_value()}")
    except Exception as e:
        print(f"✗ Query failed: {e}")
        return False
    
    # Cleanup
    client.close()
    print("✓ Connection closed")
    
    return True

if __name__ == "__main__":
    print("\nImportant: Update INFLUX_URL, INFLUX_TOKEN, INFLUX_ORG first!")
    print("Then run: python3 test_influx.py\n")
    
    # Comment out this return to run actual test
    # test_influx_connection()
    
    print("\nTest script ready - update config and uncomment test_influx_connection()")

