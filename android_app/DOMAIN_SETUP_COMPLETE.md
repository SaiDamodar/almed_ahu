# Domain Setup Complete - almedequipments.in

## ✅ What's Done

1. **Domain Purchased**: `almedequipments.in`
2. **VPS Hosting**: Hostinger (will set up later)
3. **Current Setup**: Domain configured with Railway
4. **App Config**: Updated to use new domain

## 📝 Configuration

### App Config Updated

**File**: `android_app/lib/config/app_config.dart`

```dart
static const String baseUrl = 'https://api.almedequipments.in';
```

### Railway Domain Setup

Make sure in Railway:
1. Go to Railway Dashboard → Your Service → Settings → Domains
2. Add custom domain: `api.almedequipments.in`
3. Railway will show DNS records to add
4. Add CNAME record in your domain registrar

### DNS Records (In Domain Registrar)

**For Hostinger Domain Management:**

1. Login to Hostinger
2. Go to **Domains** → **almedequipments.in** → **DNS / Name Servers**
3. Add CNAME record:
   ```
   Type: CNAME
   Name: api
   Value: [Railway-provided-domain].up.railway.app
   TTL: 3600
   ```

4. Wait 15-30 minutes for DNS propagation

## ✅ Next Steps

### 1. Verify Railway Domain

1. Check Railway dashboard - domain should show "Verified"
2. Test in browser: `https://api.almedequipments.in/login`
3. Should load successfully

### 2. Rebuild Android App

```bash
cd android_app
flutter clean
flutter build apk --debug
```

Or install directly:
```bash
flutter install
```

### 3. Test on Mobile Data

1. **Turn OFF WiFi**
2. **Open app**
3. **Try to login**
4. **Should work now!** ✅

The DNS issue should be fixed because custom domains (`almedequipments.in`) are not blocked by mobile carriers.

## 🔄 Future: Migrate to Hostinger VPS

When you're ready to move to Hostinger VPS:

1. Follow `web_dashboard/HOSTINGER_VPS_SETUP.md`
2. Point DNS A record to VPS IP instead of Railway
3. Update app config if needed (usually same domain works)

**No need to change app config** - just update DNS records!

## 📋 Checklist

- [x] Domain purchased: `almedequipments.in`
- [x] Domain added to Railway
- [x] DNS CNAME record added in Hostinger
- [x] Railway domain verified
- [x] App config updated
- [ ] Test in browser: `https://api.almedequipments.in`
- [ ] Rebuild Android app
- [ ] Test on mobile data (WiFi OFF)
- [ ] Verify login works

## 🎉 Expected Result

After DNS propagates (15-30 minutes):
- ✅ App works on WiFi
- ✅ App works on mobile data (DNS issue fixed!)
- ✅ Professional domain name
- ✅ No more "Failed host lookup" errors

## 🔍 Troubleshooting

### Domain Not Resolving

1. **Check DNS Propagation**:
   - Visit: https://dnschecker.org
   - Enter: `api.almedequipments.in`
   - Check if DNS records are propagated globally

2. **Verify Railway Domain**:
   - Railway dashboard → Service → Domains
   - Should show "Verified" status

3. **Check DNS Records**:
   - Hostinger → DNS Management
   - Ensure CNAME record is correct
   - No typos in domain name

### SSL Certificate Issues

- Railway automatically provisions SSL certificates
- Wait 5-10 minutes after domain verification
- Check Railway logs if SSL fails

### Still Getting DNS Errors

1. **Flush DNS Cache** (on device):
   - Restart Android device
   - Or use different network temporarily

2. **Test from Browser First**:
   - Open mobile browser (WiFi OFF)
   - Go to: `https://api.almedequipments.in/login`
   - If this works, app should work too

## 📞 Support

If issues persist:
1. Check Railway logs
2. Check DNS propagation status
3. Verify DNS records in Hostinger
4. Test domain in browser first

---

**Status**: ✅ App config updated, ready to test!

