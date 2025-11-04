#!/bin/bash
# Create AWS IoT Device Certificates
# This script creates certificates for ESP32 devices

set -e

if [ $# -lt 1 ]; then
    echo "Usage: $0 <device-name>"
    echo "Example: $0 ahu-01"
    exit 1
fi

DEVICE_NAME=$1
REGION="ap-south-1"
CERT_DIR="device_certs/$DEVICE_NAME"

# Create certificate directory
mkdir -p $CERT_DIR

echo "=========================================="
echo "Creating certificates for: $DEVICE_NAME"
echo "=========================================="

# Check if Thing exists, create if not
echo "Checking/Creating IoT Thing..."
if ! aws iot describe-thing --thing-name $DEVICE_NAME --region $REGION &> /dev/null; then
    echo "Creating IoT Thing: $DEVICE_NAME"
    aws iot create-thing \
        --thing-name $DEVICE_NAME \
        --thing-type-name AHUDevice \
        --region $REGION
    echo "✓ Thing created"
else
    echo "✓ Thing already exists"
fi

# Create certificate and keys
echo "Creating certificate and keys..."
CERT_OUTPUT=$(aws iot create-keys-and-certificate \
    --set-as-active \
    --certificate-pem-outfile $CERT_DIR/certificate.pem \
    --public-key-outfile $CERT_DIR/public-key.pem \
    --private-key-outfile $CERT_DIR/private-key.pem \
    --region $REGION)

CERT_ARN=$(echo $CERT_OUTPUT | jq -r '.certificateArn')
CERT_ID=$(echo $CERT_OUTPUT | jq -r '.certificateId')

echo "✓ Certificate created: $CERT_ID"

# Attach certificate to Thing
echo "Attaching certificate to Thing..."
aws iot attach-thing-principal \
    --thing-name $DEVICE_NAME \
    --principal $CERT_ARN \
    --region $REGION
echo "✓ Certificate attached to Thing"

# Attach policy to certificate
echo "Attaching policy to certificate..."
aws iot attach-policy \
    --policy-name AHUDevicePolicy \
    --target $CERT_ARN \
    --region $REGION
echo "✓ Policy attached"

# Download Amazon Root CA
echo "Downloading Amazon Root CA..."
curl -o $CERT_DIR/AmazonRootCA1.pem https://www.amazontrust.com/repository/AmazonRootCA1.pem
echo "✓ Root CA downloaded"

# Get IoT endpoint
IOT_ENDPOINT=$(aws iot describe-endpoint --endpoint-type iot:Data-ATS --region $REGION --output text)

# Create config file
cat > $CERT_DIR/config.txt <<EOF
Device Name: $DEVICE_NAME
Certificate ID: $CERT_ID
Certificate ARN: $CERT_ARN
IoT Endpoint: $IOT_ENDPOINT
Region: $REGION

Files created:
- certificate.pem (Device certificate)
- private-key.pem (Device private key)
- public-key.pem (Device public key)
- AmazonRootCA1.pem (Root CA)

Next steps:
1. Copy these files to your ESP32 device
2. Update ESP32 code with endpoint: $IOT_ENDPOINT
3. Embed certificates in ESP32 code or store in SPIFFS
EOF

echo ""
echo "=========================================="
echo "CERTIFICATES CREATED"
echo "=========================================="
echo "Certificate files saved to: $CERT_DIR"
echo ""
echo "IoT Endpoint: $IOT_ENDPOINT"
echo ""
echo "IMPORTANT: Keep private-key.pem secure!"
echo "=========================================="

