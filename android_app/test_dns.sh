#!/bin/bash
# Quick DNS Test Script
# Tests if domain resolves on mobile data

echo "=== DNS Resolution Test ==="
echo ""
echo "Testing: almedequipments.in"
echo ""

# Test root domain
echo "1. Testing root domain (almedequipments.in):"
nslookup almedequipments.in
echo ""

# Test subdomain (if exists)
echo "2. Testing subdomain (api.almedequipments.in):"
nslookup api.almedequipments.in
echo ""

# Test HTTP connection
echo "3. Testing HTTP connection (root):"
curl -I https://almedequipments.in/login 2>&1 | head -n 5
echo ""

echo "4. Testing HTTP connection (subdomain):"
curl -I https://api.almedequipments.in/login 2>&1 | head -n 5
echo ""

echo "=== Test Complete ==="
echo ""
echo "If root domain fails but subdomain works:"
echo "  → Use subdomain (api.almedequipments.in)"
echo ""
echo "If both fail:"
echo "  → DNS not propagated yet or DNS records incorrect"
echo ""
echo "If both work:"
echo "  → Domain is fine, issue might be app-specific"

