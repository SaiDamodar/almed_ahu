#!/bin/bash

# Check if API key file is in place

KEY_FILE="$HOME/.appstoreconnect/private_keys/AuthKey_F3WU9KJ42M.p8"

echo "🔍 Checking for API key file..."
echo ""

if [ -f "$KEY_FILE" ]; then
    echo "✅ Key file found: $KEY_FILE"
    ls -lh "$KEY_FILE"
    echo ""
    echo "✅ Ready to upload! Run: ./upload_to_testflight.sh"
else
    echo "❌ Key file NOT found: $KEY_FILE"
    echo ""
    echo "📥 Upload the file from your local machine:"
    echo "   scp -i /path/to/key.pem \\"
    echo "     ~/Downloads/AuthKey_F3WU9KJ42M.p8 \\"
    echo "     ec2-user@YOUR_EC2_IP:~/.appstoreconnect/private_keys/"
fi
