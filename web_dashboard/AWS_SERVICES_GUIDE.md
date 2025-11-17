# AWS Services Integration Guide

This document explains several AWS services that complement the ALMED AHU dashboard. Each section covers what the service does, why it matters for this project, and high-level implementation steps.

---

## 1. AWS IoT Device Shadow & IoT Jobs

**What it is**

- *Device Shadow*: A persistent JSON document that stores the desired and reported state of each IoT device. AWS maintains it even when the device is offline.
- *IoT Jobs*: A managed way to schedule and track remote operations (e.g., firmware updates, configuration pushes) across one or many devices.

**Why use it here**

- The dashboard can read a device’s reported status from the shadow instead of relying solely on in-memory caches or MongoDB.
- You can set desired commands (temperature, humidity, fan speed) by updating the shadow; devices sync when they reconnect.
- Use IoT Jobs to orchestrate OTA updates or batch configuration changes with audit trails.

**How to implement**

1. **Create a Thing** for each AHU in AWS IoT Core (if not already).
2. **Enable shadow**: use the AWS console or `aws iot-data update-thing-shadow`.
3. **Device firmware update**: make ESP32 firmware subscribe to `$aws/things/{thingName}/shadow/update`.
4. **Backend changes**:
   - Replace direct MQTT publishes for state changes with `UpdateThingShadow` calls via `boto3` (`iot-data` client).
   - Subscribe to shadow delta events to keep `device_cache` synchronized.
5. **IoT Jobs**:
   - Define a job document (JSON describing the action/URL for firmware).
   - Create jobs via console or `create-job` API when rolling out OTA updates.
   - Device code polls `$aws/things/{thingName}/jobs/notify-next` to receive tasks.

**Testing**

- Use AWS CLI: `aws iot-data get-thing-shadow --thing-name AHU_ESP2`.
- Update desired state and confirm device shadow reports after the device acknowledges.
- For jobs, monitor status in console (QUEUED → IN_PROGRESS → SUCCEEDED/FAILED).

---

## 2. Amazon SNS & Amazon EventBridge

**What they are**

- *SNS (Simple Notification Service)*: Pub/sub messaging for sending emails, SMS, webhooks, or triggering Lambda functions.
- *EventBridge*: A serverless event bus that routes events from AWS services (including IoT) to targets (Lambda, Step Functions, SNS, etc.).

**Why use them**

- Trigger alerts when a device goes offline, exceeds temperature thresholds, or when a job fails.
- Pipe IoT lifecycle events or custom CloudWatch alarms to downstream automation (ticketing, on-call alerts).

**How to implement**

1. **Create an SNS topic** (`almed-alerts`), add email/SMS subscriptions.
2. **Set EventBridge rule**:
   - Source: `aws.iot`.
   - Event pattern: Thing lifecycle events, IoT Jobs status, or custom events from Lambda.
   - Target: the SNS topic (or direct Lambda call).
3. **Emit custom events**: from your Flask app call `events = boto3.client('events')` → `put_events` with detail JSON.
4. **CloudWatch alarm integration**: set alarm → notify SNS topic.

**Testing**

- Publish a test event: `aws sns publish --topic-arn ... --message "AHU offline"`.
- Use EventBridge console’s “Test event” feature to ensure routing works.

---

## 3. AWS Lambda for Backend Automation

**What it is**

- Lambda runs backend code (Python, Node.js, etc.) without managing servers. Perfect for scheduled tasks or reacting to events.

**Why use it**

- Offload jobs that shouldn’t run inside the Flask app (nightly reports, data cleanup, alert enrichment).
- React to IoT events or SNS notifications without keeping an EC2 instance alive.

**How to implement**

1. Author a Lambda function (Python 3.11) with dependencies zipped/layered.
2. Grant IAM permissions (e.g., read from Mongo Atlas via VPC peering, or read from DynamoDB/Timestream if you migrate).
3. Trigger options:
   - EventBridge schedule (e.g., every 5 minutes to reconcile device state).
   - IoT Rule / SNS / S3 upload events.
4. Use Lambda to write aggregated metrics back to DynamoDB, S3, or CloudWatch.

**Testing**

- Use the Lambda console “Test” button with sample payloads.
- Review CloudWatch Logs for each invocation to confirm success/failures.

---

## 4. Amazon S3 + AWS Glue

**What they are**

- *S3*: Durable object storage, great for archiving raw telemetry and logs.
- *Glue*: Managed ETL service that discovers schemas, transforms data, and exposes it to Athena or Redshift for querying.

**Why use them**

- Keep long-term history of telemetry beyond what Mongo can handle cheaply.
- Run ad-hoc analytics (Athena SQL) or machine learning prep using Glue jobs.

**How to implement**

1. Create an S3 bucket (`almed-ahu-data`).
2. Add an IoT Rule that delivers every telemetry message to S3 (JSON) or Firehose.
3. Configure Glue Crawler pointing to the bucket to catalog the data schema.
4. Use Glue jobs (PySpark or Python shell) to transform data, partition by date/device, or load into Athena/Redshift.
5. Query via Amazon Athena (`SELECT * FROM telemetry WHERE device_id='AHU_ESP2' ORDER BY timestamp DESC LIMIT 100;`).

**Testing**

- After the IoT rule runs, check S3 for new files.
- Run the Glue crawler and see tables appear in the Glue Data Catalog.
- Use Athena to run SQL queries; verify results match recent telemetry.

---

## 5. Amazon Cognito (or IAM Identity Center)

**What it is**

- Cognito User Pools provide managed user authentication (sign-up, sign-in, MFA).
- IAM Identity Center (formerly AWS SSO) handles workforce identities with SAML/OIDC integration.

**Why use it**

- Replace the hardcoded `ADMIN_USERNAME`/`ADMIN_PASSWORD` in `config.py`.
- Enforce password policies, multi-factor auth, and social/enterprise federation.
- Issue JWTs that the Flask backend can verify before serving dashboard pages.

**How to implement**

1. **Cognito User Pool**
   - Create a user pool (e.g., `almed-users`), configure app client (no secret for SPA usage).
   - Enable hosted UI for login or embed the SDK.
   - In Flask, verify tokens with `python-jose` or AWS-provided middleware.
   - Replace `/api/login` logic with Cognito OAuth code grant (or use Amplify for front-end).
2. **IAM Identity Center** (if for employees)
   - Configure SSO with your IdP (Google Workspace, Azure AD).
   - Protect the dashboard behind an Application Load Balancer or CloudFront that requires SSO auth.

**Testing**

- Use Cognito hosted UI to log in; confirm you get ID/access tokens.
- Call a protected API endpoint with the token; verify the backend validates signature and claims.
- Attempt invalid tokens to ensure access is denied.

---

### Next Steps

1. Prioritize which services solve your most pressing issues (e.g., start with Cognito for security, Device Shadow for reliability).
2. Create small proof-of-concept integrations before rolling out broadly.
3. Document IAM policies and infrastructure-as-code (CloudFormation/Terraform) as you add services to keep environments reproducible.

Feel free to ask for implementation help on any specific service.

