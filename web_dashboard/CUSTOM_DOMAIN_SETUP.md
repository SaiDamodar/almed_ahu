# Custom Domain Setup for Railway.com

## Overview

Setting up a custom domain (`almed.org.in`) with Railway will:
- ✅ Fix DNS resolution issues on mobile data
- ✅ Provide professional branding
- ✅ Avoid carrier DNS blocking
- ✅ Allow multiple subdomains

## Prerequisites

1. **Domain Purchased**: `almed.org.in` (or any domain you own)
2. **Domain Registrar Access**: Where you bought the domain (GoDaddy, Namecheap, etc.)
3. **Railway Account**: With your service deployed

## Step-by-Step Setup

### Step 1: Add Domain in Railway

1. Go to Railway Dashboard
2. Select your project → Your service
3. Go to **Settings** tab
4. Scroll to **Domains** section
5. Click **"Generate Domain"** or **"Add Custom Domain"**
6. Enter your domain: `api.almed.org.in` (or any subdomain you want)
7. Railway will show you DNS records to add

### Step 2: Configure DNS Records

Railway will provide you with DNS records. Typically:

**Option A: CNAME Record (Recommended)**
```
Type: CNAME
Name: api (or @ for root domain)
Value: [Railway-provided-domain].up.railway.app
TTL: 3600 (or Auto)
```

**Option B: A Record (If CNAME not supported)**
```
Type: A
Name: api (or @ for root domain)
Value: [Railway-provided-IP-address]
TTL: 3600
```

### Step 3: Add DNS Records in Your Domain Registrar

**For GoDaddy:**
1. Login to GoDaddy
2. Go to **My Products** → **DNS** → **Manage DNS**
3. Click **Add** record
4. Enter the CNAME or A record from Railway
5. Save

**For Namecheap:**
1. Login to Namecheap
2. Go to **Domain List** → Select `almed.org.in` → **Manage**
3. Go to **Advanced DNS** tab
4. Click **Add New Record**
5. Enter the CNAME or A record from Railway
6. Save

**For Other Registrars:**
- Look for "DNS Management" or "DNS Settings"
- Add the CNAME or A record provided by Railway

### Step 4: Wait for DNS Propagation

- DNS changes can take **5 minutes to 48 hours** to propagate
- Usually takes **15-30 minutes**
- Check propagation: https://dnschecker.org

### Step 5: Verify Domain in Railway

1. Railway will automatically verify the domain
2. Once verified, Railway will provision SSL certificate (automatic, free)
3. Your domain will be ready: `https://api.almed.org.in`

## Multiple Subdomains Setup

You can set up multiple subdomains for different services:

### Example Setup:

1. **API/Dashboard**: `api.almed.org.in`
   - Railway service: Web dashboard
   - DNS: CNAME `api` → Railway domain

2. **Admin Panel** (if separate): `admin.almed.org.in`
   - Railway service: Same or different service
   - DNS: CNAME `admin` → Railway domain

3. **Future Services**: `app.almed.org.in`, `www.almed.org.in`, etc.
   - Each can point to different Railway services

### DNS Records Example:

```
Type    Name    Value                           TTL
CNAME   api     [railway-domain].up.railway.app 3600
CNAME   admin   [railway-domain].up.railway.app 3600
CNAME   app     [railway-domain].up.railway.app 3600
A       @       [railway-ip]                    3600  (for root domain)
```

## Update Android App

After domain is set up and verified:

1. **Update `app_config.dart`**:
   ```dart
   // Change from:
   static const String baseUrl = 'https://almedahuwebapp-production.up.railway.app';
   
   // To:
   static const String baseUrl = 'https://api.almed.org.in';
   ```

2. **Rebuild and test**:
   ```bash
   flutter build apk --debug
   ```

3. **Test on mobile data** (WiFi OFF):
   - Should now work without DNS issues!

## SSL Certificate

- Railway automatically provisions **free SSL certificates** via Let's Encrypt
- Certificate is valid for 90 days and auto-renews
- No manual configuration needed
- HTTPS works automatically once domain is verified

## Troubleshooting

### Domain Not Resolving

1. **Check DNS Propagation**:
   - Use https://dnschecker.org
   - Enter: `api.almed.org.in`
   - Check if DNS records are propagated globally

2. **Verify DNS Records**:
   - Ensure CNAME/A record is correct
   - Check TTL is not too high (3600 is good)
   - Ensure no typos in domain name

3. **Check Railway Status**:
   - Railway dashboard → Service → Domains
   - Should show "Verified" status
   - If not verified, check DNS records again

### SSL Certificate Issues

1. **Certificate Not Provisioned**:
   - Wait 5-10 minutes after domain verification
   - Railway automatically provisions SSL
   - Check Railway logs for SSL errors

2. **Mixed Content Warnings**:
   - Ensure all API calls use HTTPS
   - Check `app_config.dart` uses `https://`

### Still Having DNS Issues

1. **Flush DNS Cache** (on device):
   - Android: Restart device or use different network
   - Or change DNS to Google (8.8.8.8) temporarily

2. **Test from Different Networks**:
   - Test from mobile data
   - Test from different WiFi
   - Use online DNS checker tools

## Cost

- **Domain**: One-time purchase (~$10-15/year for `.org.in`)
- **Railway**: Same pricing (domain doesn't add cost)
- **SSL Certificate**: Free (provided by Railway/Let's Encrypt)

## Benefits of Custom Domain

1. ✅ **No DNS Blocking**: Custom domains rarely blocked by carriers
2. ✅ **Professional**: Better branding than Railway subdomain
3. ✅ **Flexible**: Multiple subdomains for different services
4. ✅ **Reliable**: Better DNS resolution globally
5. ✅ **Future-Proof**: Easy to migrate to different hosting

## Next Steps After Setup

1. ✅ Update `app_config.dart` with new domain
2. ✅ Rebuild Android app
3. ✅ Test on mobile data (should work now!)
4. ✅ Update any documentation with new URL
5. ✅ Consider setting up other subdomains if needed

## Example: Complete Setup

**Domain**: `almed.org.in`

**Subdomains**:
- `api.almed.org.in` → Web dashboard API
- `admin.almed.org.in` → Admin panel (optional)
- `www.almed.org.in` → Website (optional)

**Android App Config**:
```dart
static const String baseUrl = 'https://api.almed.org.in';
```

**Result**: App works on WiFi AND mobile data! 🎉

