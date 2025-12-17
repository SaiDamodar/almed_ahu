# DNS Resolution Issue - Mobile Data Not Working

## Problem

The app works on WiFi but fails on mobile data with error:
```
Failed host lookup: 'almedahuwebapp-production.up.railway.app'
(OS Error: No address associated with hostname, errno = 7)
```

## Explanation

### Why WiFi Works but Mobile Data Doesn't:

1. **DNS Servers Are Different**:
   - **WiFi**: Uses your router's DNS or ISP's DNS servers (usually Google 8.8.8.8 or Cloudflare 1.1.1.1)
   - **Mobile Data**: Uses your mobile carrier's DNS servers (which may not resolve Railway domains properly)

2. **Railway Domain Accessibility**:
   - Railway domains like `*.up.railway.app` are accessible from ANY network (WiFi, mobile data, etc.)
   - The issue is DNS resolution, not the Railway service itself
   - Your mobile carrier's DNS may be:
     - Blocking certain domains
     - Having DNS propagation issues
     - Using older DNS cache

3. **Network Security**:
   - Mobile carriers sometimes block or filter certain domains
   - Railway subdomains might be flagged by carrier filters

## Solutions

### Solution 1: Use Custom Domain (RECOMMENDED)

Since you mentioned getting `almed.org.in`, this is the best solution:

1. **Get Custom Domain**: Purchase/configure `almed.org.in` (or subdomain like `api.almed.org.in`)
2. **Configure in Railway**:
   - Go to Railway dashboard → Your service → Settings → Domains
   - Add custom domain: `api.almed.org.in` (or whatever you prefer)
   - Railway will provide DNS records to add to your domain registrar
3. **Update App Config**:
   ```dart
   // In lib/config/app_config.dart
   static const String baseUrl = 'https://api.almed.org.in';
   ```
4. **Benefits**:
   - More professional
   - Better DNS resolution
   - Not blocked by carriers
   - Easier to remember

### Solution 2: Change DNS on Android Device

Force the device to use a different DNS server:

**Method 1: Change DNS in Android Settings**
1. Go to Settings → Network & Internet → Private DNS
2. Select "Private DNS provider hostname"
3. Enter one of:
   - `dns.google` (Google DNS)
   - `1dot1dot1dot1.cloudflare-dns.com` (Cloudflare DNS)
4. Save and restart the app

**Method 2: Change DNS per WiFi/Network** (won't help mobile data)
- This only works for WiFi connections

**Method 3: Use VPN**
- Install a VPN app (like Cloudflare WARP or any VPN)
- This routes DNS through VPN's servers
- Works but adds latency

### Solution 3: Test if Railway Domain is Accessible

First, verify if the domain is accessible from mobile data:

1. **Open Mobile Browser** (with mobile data, WiFi OFF):
   - Go to: `https://almedahuwebapp-production.up.railway.app/login`
   - If this loads → DNS is working, issue is in the app
   - If this doesn't load → DNS is blocked by carrier

2. **Test DNS Resolution** (using terminal/adb):
   ```bash
   # Connect device via USB and run:
   adb shell nslookup almedahuwebapp-production.up.railway.app
   ```
   - If it returns an IP → DNS is working
   - If it times out → DNS is blocked

### Solution 4: Use IP Address (Not Recommended)

Railway doesn't provide static IPs, so this won't work long-term. IPs change with each deployment.

### Solution 5: Wait for DNS Propagation

Sometimes DNS changes take time to propagate. Wait 24-48 hours if Railway domain was recently created.

## Immediate Workaround

While you set up a custom domain:

1. **For Testing**: Use WiFi (works reliably)
2. **For Users**: 
   - Ask users to change DNS to Google/Cloudflare (see Solution 2)
   - Or wait for custom domain setup

## Why This Happens

### Technical Details:

1. **DNS Lookup Process**:
   ```
   App → Carrier DNS → Railway DNS → IP Address
   ```
   If carrier DNS fails to resolve Railway domain, lookup fails.

2. **Railway Domains**:
   - Railway uses Cloudflare for DNS
   - Some mobile carriers block Cloudflare DNS or Railway domains
   - This is a carrier-side issue, not Railway's fault

3. **Network Policies**:
   - Mobile carriers implement network policies for security
   - These may inadvertently block legitimate services

## Best Long-term Solution

**Use Custom Domain** (`almed.org.in` or subdomain):

1. **More Reliable**: Not blocked by carriers
2. **Better Branding**: Professional appearance
3. **Control**: You own the domain, full control
4. **SSL**: Railway provides automatic SSL certificates

## Testing After Fix

1. **With Mobile Data** (WiFi OFF):
   - Open app
   - Try to login
   - Should work now

2. **With WiFi**:
   - Should continue working

3. **Both Networks**:
   - App should work identically on both

## Summary

**Root Cause**: Mobile carrier's DNS cannot resolve Railway's domain name.

**Best Fix**: Use custom domain (`almed.org.in` or subdomain) - most reliable solution.

**Quick Fix**: Change Android device DNS to Google/Cloudflare (works for that device only).

**Workaround**: Use WiFi for now (works reliably).

---

**Next Steps**:
1. Set up custom domain in Railway (recommended)
2. Or change DNS on Android devices (quick fix)
3. Update `app_config.dart` with new domain
4. Test on mobile data

