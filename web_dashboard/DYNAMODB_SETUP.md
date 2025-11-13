# DynamoDB Setup Guide for ALMED AHU

## Step 1: Create DynamoDB Table

1. Go to AWS Console → DynamoDB
2. Click "Create table"

### Table Configuration

- **Table name**: `AHU_Telemetry_DB`
- **Partition key**: `device_id` (String)
- **Sort key**: `timestamp` (Number)
- **Table settings**: Use default settings (or customize as needed)

### Capacity Settings

- **Read/Write capacity mode**: On-demand (recommended for variable workloads)
- Or use Provisioned with:
  - Read capacity: 5 units
  - Write capacity: 5 units

Click "Create table"

## Step 2: Create AWS IoT Core Rule

1. Go to AWS IoT Core → Rules
2. Click "Create rule"

### Rule Configuration

**Rule name**: `AHU_ESP2_To_DynamoDB`

**SQL statement**:
```sql
SELECT 
  thing,
  ts,
  temp,
  hum,
  m1,
  m2,
  run,
  cp,
  heater,
  fan,
  fanSpeed,
  tempSet,
  humSet,
  ip,
  type
FROM 'esp32/pub' 
WHERE type = 'telemetry'
```

**Important**: Keep field names as-is (`thing`, `ts`, not `device_id`, `timestamp`) to match your table structure.

**SQL version**: `2016-03-23`

### Add Action: DynamoDB

1. Click "Add action"
2. Select "Insert a message into a DynamoDB table"
3. Click "Configure action"

**Action configuration**:
- **Table name**: `AHU_ESP2_AWSDB` (or your actual table name)
- **Partition key**: `thing` = `${thing}`
- **Sort key**: `ts` = `${ts}`
- **Write message data to this column**: Leave empty (all fields will be stored)
- **IAM role**: Select or create `AHU-IoT-DynamoDB-Role`

### IAM Role Permissions

The IAM role needs these permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:PutItem"
      ],
      "Resource": "arn:aws:dynamodb:*:*:table/AHU_Telemetry_DB"
    }
  ]
}
```

Click "Create rule"

## Step 3: Verify Data Flow

1. **Check ESP32 is publishing**:
   - Go to AWS IoT Core → Test
   - Subscribe to topic: `esp32/pub`
   - You should see messages from your ESP32

2. **Check DynamoDB**:
   - Go to DynamoDB → Tables → `AHU_Telemetry_DB`
   - Click "Explore table items"
   - You should see data appearing within 5-10 seconds

3. **Query data**:
   ```json
   {
     "device_id": "AHU_ESP2",
     "timestamp": 1234567890
   }
   ```

## Step 4: Test Web Dashboard

1. Start the Flask server:
   ```bash
   cd web_dashboard
   python app.py
   ```

2. Open browser: http://localhost:5000

3. Verify data appears in:
   - Dashboard (device cards)
   - AHU Control page
   - Graphs page

## Troubleshooting

### No data in DynamoDB

1. **Check IoT Rule**:
   - Go to IoT Core → Rules → Your rule
   - Check "Metrics" tab for execution errors

2. **Check IAM Role**:
   - Verify role has `dynamodb:PutItem` permission
   - Check resource ARN matches your table

3. **Check SQL Statement**:
   - Test in IoT Core → Test → Subscribe to `esp32/pub`
   - Verify messages match your WHERE clause

4. **Check ESP32**:
   - Verify ESP32 is connected to AWS IoT Core
   - Check serial monitor for publish confirmations

### Rule execution errors

1. **Check CloudWatch Logs**:
   - Go to CloudWatch → Log groups
   - Look for `/aws/iot/AHU_ESP2_To_DynamoDB`

2. **Common issues**:
   - IAM role missing permissions
   - Table name mismatch
   - Invalid data types
   - Timestamp format issues

## Data Structure

Each DynamoDB item contains:

```json
{
  "device_id": "AHU_ESP2",
  "timestamp": 1704067200000,
  "temperature": 22.5,
  "humidity": 55.0,
  "m1": false,
  "m2": false,
  "run": true,
  "cp": false,
  "heater": false,
  "fan": true,
  "fanSpeed": 2,
  "tempSet": 22.0,
  "humSet": 55.0,
  "ip": "192.168.1.100",
  "type": "telemetry"
}
```

## Cost Optimization

- Use **On-demand** billing for variable workloads
- Set up **TTL** (Time To Live) to auto-delete old data:
  - Add `ttl` attribute (Number)
  - Set TTL to expire after 365 days
- Use **DynamoDB Streams** for real-time processing (optional)

## Next Steps

1. Set up data visualization
2. Create CloudWatch alarms for thresholds
3. Configure data retention policies
4. Set up backup/archival if needed

