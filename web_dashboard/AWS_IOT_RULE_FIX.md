# AWS IoT Core Rule Fix for Boolean Values

## Problem
Boolean values (`run`, `m1`, `m2`, `cp`, `heater`, `fan`) are being stored incorrectly in DynamoDB (showing `true` when they should be `false`).

## Solution: Update the AWS IoT Core Rule SQL Statement

### Current Table Structure
- **Table name**: `AHU_ESP2_AWSDB`
- **Partition key**: `thing` (String)
- **Sort key**: `ts` (Number)

### Corrected SQL Statement

Go to **AWS IoT Core → Rules → Your Rule → Edit**

Replace the SQL statement with:

```sql
SELECT 
  thing,
  ts,
  temp,
  hum,
  CASE WHEN m1 = true THEN true ELSE false END as m1,
  CASE WHEN m2 = true THEN true ELSE false END as m2,
  CASE WHEN run = true THEN true ELSE false END as run,
  CASE WHEN cp = true THEN true ELSE false END as cp,
  CASE WHEN heater = true THEN true ELSE false END as heater,
  CASE WHEN fan = true THEN true ELSE false END as fan,
  fanSpeed,
  tempSet,
  humSet,
  ip,
  type
FROM 'esp32/pub' 
WHERE type = 'telemetry'
```

**OR** (simpler version - AWS IoT Core should preserve booleans):

```sql
SELECT 
  *,
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

### DynamoDB Action Configuration

1. **Table name**: `AHU_ESP2_AWSDB`
2. **Partition key**: `thing` = `${thing}`
3. **Sort key**: `ts` = `${ts}`
4. **Write message data to this column**: Leave empty (all fields will be stored)

### Alternative: Use CAST to Ensure Boolean Types

If the above doesn't work, try this SQL with explicit casting:

```sql
SELECT 
  thing,
  ts,
  temp,
  hum,
  CAST(m1 AS BOOLEAN) as m1,
  CAST(m2 AS BOOLEAN) as m2,
  CAST(run AS BOOLEAN) as run,
  CAST(cp AS BOOLEAN) as cp,
  CAST(heater AS BOOLEAN) as heater,
  CAST(fan AS BOOLEAN) as fan,
  fanSpeed,
  tempSet,
  humSet,
  ip,
  type
FROM 'esp32/pub' 
WHERE type = 'telemetry'
```

## Verification Steps

1. **Check the rule is working**:
   - Go to AWS IoT Core → Rules → Your rule → Metrics
   - Check for execution errors

2. **Check CloudWatch Logs**:
   - Go to CloudWatch → Log groups
   - Look for `/aws/iot/YourRuleName`
   - Check for any errors

3. **Test with MQTT Test Client**:
   - Go to AWS IoT Core → Test
   - Subscribe to `esp32/pub`
   - Verify the message structure matches what the rule expects

4. **Check DynamoDB**:
   - Go to DynamoDB → Tables → `AHU_ESP2_AWSDB`
   - Check the latest items
   - Verify boolean values are correct

## Common Issues

### Issue 1: Boolean values stored as strings
- **Symptom**: DynamoDB shows `"true"` or `"false"` (strings) instead of `true`/`false` (booleans)
- **Solution**: Use `CAST(field AS BOOLEAN)` in SQL

### Issue 2: Boolean values stored as numbers
- **Symptom**: DynamoDB shows `1` or `0` instead of `true`/`false`
- **Solution**: Use `CASE WHEN field = true THEN true ELSE false END` in SQL

### Issue 3: Rule not executing
- **Check**: IoT Core → Rules → Metrics tab
- **Check**: CloudWatch Logs for errors
- **Verify**: ESP32 is publishing to `esp32/pub` with `type = 'telemetry'`

## Testing

After updating the rule:

1. Wait 5-10 seconds for new data to arrive
2. Check DynamoDB for new items
3. Verify boolean values match MQTT test client data
4. Check Flask server logs to see if data is being read correctly

## Expected Data Format in DynamoDB

```json
{
  "thing": "AHU_ESP2",
  "ts": 270121,
  "temp": 26.52209,
  "hum": 39.31166,
  "m1": false,
  "m2": false,
  "run": false,
  "cp": false,
  "heater": false,
  "fan": false,
  "fanSpeed": 0,
  "tempSet": 25.5,
  "humSet": 42,
  "ip": "10.42.0.245",
  "type": "telemetry"
}
```

Note: Boolean values should be actual booleans (`true`/`false`), not strings or numbers.

