# Domain DNS Troubleshooting - Still Not Working on Mobile Data

## Problem

Even with custom domain `almedequipments.in`, app only works on WiFi, not mobile data.

## Possible Causes

### 1. DNS Propagation Not Complete (Most Likely)

**Issue**: Mobile carrier's DNS servers haven't updated yet.

**Check**:
- Visit: https://dnschecker.org
- Enter: `almedequipments.in`
- Check if DNS is propagated globally (especially in your country/region)

**Solution**: Wait 24-48 hours for full DNS propagation. Some mobile carriers cache DNS longer.

### 2. Railway Domain Not Properly Configured

**Check**:
1. Railway Dashboard → Your Service → Settings → Domains
2. Is `almedequipments.in` showing as "Verified"?
3. If not verified, check DNS records

**Solution**: Ensure Railway domain is verified and DNS records are correct.

### 3. DNS Records Incorrect in Hostinger

**Check**:
1. Hostinger → Domains → `almedequipments.in` → DNS Management
2. Verify the record type and value:
   - **CNAME**: Should point to Railway domain
   - **A Record**: Should point to Railway IP (if Railway provides one)

**Common Mistakes**:
- Wrong record type
- Typo in domain name
- Wrong TTL value
- Missing @ or root domain record

### 4. Mobile Carrier DNS Caching

**Issue**: Mobile carrier's DNS is caching old/incorrect records.

**Solution**: 
- Wait longer (up to 48 hours)
- Change DNS on Android device (see below)
- Use VPN temporarily to test

### 5. Railway Domain Configuration Issue

**Check**:
- Railway might need specific DNS configuration
- Some hosting providers need A records instead of CNAME for root domain

## Quick Diagnostic Steps

### Step 1: Test DNS Resolution

**On Computer (with mobile data via hotspot)**:
```bash
nslookup almedequipments.in
```

**On Android Device (via ADB)**:
```bash
adb shell nslookup almedequipments.in
```

**Expected**: Should return Railway IP address
**If fails**: DNS not resolving correctly

### Step 2: Test Domain in Mobile Browser

1. **Turn OFF WiFi** (use mobile data only)
2. **Open mobile browser**
3. **Go to**: `https://almedequipments.in/login`
4. **If browser loads**: Domain works, issue is in app
5. **If browser fails**: DNS/domain issue

### Step 3: Check Railway Logs

1. Railway Dashboard → Your Service → Logs
2. Look for domain-related errors
3. Check if requests are reaching Railway

### Step 4: Verify DNS Records

**In Hostinger DNS Management**, check:

**For Root Domain (@)**:
```
Type: CNAME or A
Name: @ (or blank)
Value: [Railway domain or IP]
TTL: 3600
```

**Common Issue**: Root domain might need A record instead of CNAME (some providers don't allow CNAME on root).

## Solutions

### Solution 1: Wait for DNS Propagation (24-48 hours)

DNS changes can take time, especially for mobile carriers:
- Some carriers cache DNS for 24-48 hours
- Different regions propagate at different speeds
- Root domain (@) can take longer than subdomains

**Action**: Wait and test again tomorrow.

### Solution 2: Use Subdomain Instead (Recommended)

**Why**: Subdomains (like `api.almedequipments.in`) propagate faster and are more reliable.

**Steps**:
1. **In Railway**: Add domain `api.almedequipments.in` (not root)
2. **In Hostinger DNS**: Add CNAME:
   ```
   Type: CNAME
   Name: api
   Value: [Railway-domain].up.railway.app
   TTL: 3600
   ```
3. **Update app_config.dart**:
   ```dart
   static const String baseUrl = 'https://api.almedequipments.in';
   ```
4. **Wait 15-30 minutes** (subdomains propagate faster)

### Solution 3: Change DNS on Android Device

Force device to use different DNS:

1. **Settings** → **Network & Internet** → **Private DNS**
2. Select **"Private DNS provider hostname"**
3. Enter: `dns.google` (Google DNS)
4. Save and test app again

**This bypasses carrier DNS** and should work immediately.

### Solution 4: Use A Record Instead of CNAME

Some providers don't allow CNAME on root domain. Use A record:

1. **Get Railway IP** (if Railway provides one)
2. **In Hostinger**: Add A record:
   ```
   Type: A
   Name: @
   Value: [Railway-IP-address]
   TTL: 3600
   ```

**Note**: Railway might not provide static IP. Check Railway domain settings.

### Solution 5: Check Railway Domain Settings

**In Railway**:
1. Go to domain settings
2. Check if Railway shows any warnings
3. Verify domain is properly verified
4. Check if Railway provides specific DNS instructions

## Recommended Approach

### Option A: Use Subdomain (Fastest Fix)

1. Set up `api.almedequipments.in` in Railway
2. Add CNAME record in Hostinger
3. Update app config
4. Test in 15-30 minutes

**Why**: Subdomains propagate faster and are more reliable.

### Option B: Change Android DNS (Immediate Fix)

1. Change DNS to Google (8.8.8.8) on device
2. Test immediately
3. Works for that device only

**Why**: Bypasses carrier DNS issues.

### Option C: Wait for Propagation (Easiest)

1. Wait 24-48 hours
2. Test again
3. Should work after full propagation

**Why**: DNS propagation takes time, especially for root domains.

## Testing Checklist

- [ ] Test domain in mobile browser (WiFi OFF)
- [ ] Check DNS propagation: https://dnschecker.org
- [ ] Verify Railway domain is "Verified"
- [ ] Check DNS records in Hostinger
- [ ] Test nslookup from command line
- [ ] Check Railway logs for errors
- [ ] Try changing Android DNS
- [ ] Wait 24-48 hours and retest

## Expected Timeline

| Action | Time |
|--------|------|
| DNS record added | Immediate |
| Subdomain propagation | 15-30 minutes |
| Root domain propagation | 1-24 hours |
| Mobile carrier DNS update | 24-48 hours |

## Still Not Working?

1. **Check Railway domain status** - Is it verified?
2. **Check DNS records** - Are they correct?
3. **Test in browser first** - Does browser work on mobile data?
4. **Check Railway logs** - Any errors?
5. **Try subdomain** - `api.almedequipments.in` instead of root
6. **Change Android DNS** - Use Google DNS temporarily

## Quick Test Commands

**Test DNS resolution**:
```bash
# On computer
nslookup almedequipments.in

# On Android (via ADB)
adb shell nslookup almedequipments.in
```

**Test HTTP connection**:
```bash
# On computer
curl -I https://almedequipments.in

# Should return 200 OK
```

**Check DNS propagation globally**:
- Visit: https://dnschecker.org
- Enter: `almedequipments.in`
- Check all locations (especially your country)

---

**Most Likely Issue**: DNS propagation not complete on mobile carrier's DNS servers. Wait 24-48 hours or use subdomain (`api.almedequipments.in`) which propagates faster.

