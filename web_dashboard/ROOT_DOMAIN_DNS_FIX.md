# Root Domain DNS Fix - Railway Setup

## Problem

Root domain (`almedequipments.in`) not working on mobile data after 24 hours, only works on WiFi.

## Root Cause

**Root domains (@) often don't support CNAME records**. Many DNS providers require **A records** for root domains, but Railway might not provide a static IP.

## Railway Root Domain Setup

### Issue: Railway Root Domain Requirements

Railway has specific requirements for root domains:

1. **CNAME NOT supported for root** (@) in many cases
2. **A Record needed** but Railway might not provide static IP
3. **Alternative**: Use subdomain (CNAME works reliably)

### Check Your Railway Setup

1. **Go to Railway Dashboard** → Your Service → Settings → Domains
2. **Check**:
   - Is `almedequipments.in` listed?
   - What status does it show? (Verified / Pending / Error)
   - What DNS instructions does Railway show?

3. **Railway Domain Instructions**:
   - Railway will show you exactly what DNS records to add
   - **Don't guess** - follow Railway's exact instructions

## Solutions

### Solution 1: Use Subdomain (RECOMMENDED - Fastest)

**Why**: Subdomains support CNAME and propagate faster.

**Steps**:

1. **In Railway**:
   - Add domain: `api.almedequipments.in` (subdomain)
   - Railway will show DNS instructions (usually CNAME)

2. **In Hostinger DNS**:
   - Remove any incorrect root domain records
   - Add CNAME record:
     ```
     Type: CNAME
     Name: api
     Value: [your-railway-app].up.railway.app
     TTL: 3600
     ```

3. **Wait 15-30 minutes** (subdomains propagate faster)

4. **App is already configured** for `api.almedequipments.in`

**This should work within 30 minutes!**

### Solution 2: Fix Root Domain (If Railway Supports It)

**Only if Railway explicitly allows root domain CNAME or provides A record**.

1. **Check Railway Domain Instructions**:
   - Railway dashboard → Domain settings
   - Railway will tell you exactly what to add
   - **Follow Railway's instructions exactly**

2. **In Hostinger DNS**:

   **Option A: If Railway says CNAME is OK**
   ```
   Type: CNAME
   Name: @ (or blank)
   Value: [railway-app].up.railway.app
   TTL: 3600
   ```

   **Option B: If Railway provides IP (A Record)**
   ```
   Type: A
   Name: @
   Value: [Railway IP address]
   TTL: 3600
   ```

3. **Wait 24-48 hours** for propagation

### Solution 3: Check What Railway Actually Needs

**Contact Railway Support or Check Documentation**:

1. Railway dashboard → Domain settings
2. Look for help/support link
3. Ask: "Does root domain need CNAME or A record?"
4. Railway will tell you exactly what's needed

## Diagnostic Steps

### Step 1: Check Railway Domain Status

1. **Railway Dashboard** → Service → Settings → Domains
2. **Is domain showing**?
   - ✅ **Verified (green)**: Domain is set up correctly
   - ⚠️ **Pending**: DNS not set up correctly
   - ❌ **Error**: DNS records are wrong

### Step 2: Check DNS Records in Hostinger

1. **Hostinger** → Domains → `almedequipments.in` → DNS Management
2. **Check current records** for root (@):
   - What type? (A or CNAME)
   - What value?
   - Is it correct according to Railway?

### Step 3: Test DNS Resolution

**On Mobile Data (WiFi OFF)**:

```bash
# Via ADB
adb shell nslookup almedequipments.in

# Should return IP address
# If "No address found" → DNS not resolving
```

**In Mobile Browser (WiFi OFF)**:
- Visit: `https://almedequipments.in/login`
- If browser works → Domain is fine, issue might be app-specific
- If browser fails → DNS issue

### Step 4: Check DNS Propagation

Visit: https://dnschecker.org
- Enter: `almedequipments.in`
- Select: `A` and `CNAME` record types
- Check all locations
- **If many show "Failed"** → DNS not configured correctly

## Common Mistakes

### Mistake 1: Using CNAME for Root When Not Allowed

**Problem**: Many DNS providers don't allow CNAME on root (@).

**Fix**: Use subdomain or A record.

### Mistake 2: Wrong DNS Record Type

**Problem**: Using A record when Railway needs CNAME (or vice versa).

**Fix**: **Check Railway's exact instructions** - don't guess!

### Mistake 3: Wrong Value in DNS Record

**Problem**: Typo or wrong Railway domain in DNS record.

**Fix**: Copy Railway domain exactly as shown in Railway dashboard.

### Mistake 4: DNS Not Propagated Yet

**Problem**: Added DNS record but waiting for propagation.

**Fix**: Wait 24-48 hours (or use subdomain which is faster).

## Recommended Action Plan

### Option A: Use Subdomain (FASTEST - DO THIS)

1. ✅ App already configured for `api.almedequipments.in`
2. **Set up in Railway**: Add `api.almedequipments.in` domain
3. **Set up in Hostinger**: Add CNAME for `api`
4. **Wait 30 minutes**
5. **Test on mobile data**

**Why**: Fastest and most reliable solution!

### Option B: Fix Root Domain (If You Must)

1. **Check Railway**: What exactly does Railway need for root domain?
2. **Update Hostinger**: Add correct DNS record type
3. **Wait 24-48 hours**
4. **Test on mobile data**

## Verification Checklist

Before testing, verify:

- [ ] Railway domain is "Verified" (green checkmark)
- [ ] DNS records match Railway's instructions exactly
- [ ] DNS type is correct (A or CNAME)
- [ ] DNS value is correct (Railway domain or IP)
- [ ] DNS propagation shows success on dnschecker.org
- [ ] Domain loads in mobile browser (WiFi OFF)

## Testing

1. **Turn OFF WiFi** (use mobile data only)
2. **Open mobile browser**
3. **Visit**: 
   - `https://almedequipments.in/login` (if using root)
   - `https://api.almedequipments.in/login` (if using subdomain)
4. **If browser works**: Domain is fine, test app
5. **If browser fails**: DNS issue, check records

## Still Not Working?

1. **Check Railway Dashboard**:
   - Is domain showing as "Verified"?
   - What does Railway say about DNS setup?
   - Are there any warnings or errors?

2. **Check Hostinger DNS**:
   - Are DNS records correct?
   - Do they match Railway's instructions?
   - Try removing and re-adding records

3. **Try Subdomain Instead**:
   - Set up `api.almedequipments.in` (much faster!)
   - App is already configured for it

---

## Quick Fix: Use Subdomain

**The app is already configured for subdomain** (`api.almedequipments.in`).

**Just set it up**:
1. Railway: Add `api.almedequipments.in`
2. Hostinger: Add CNAME for `api`
3. Wait 30 minutes
4. Test!

This should work much faster than root domain! 🚀

