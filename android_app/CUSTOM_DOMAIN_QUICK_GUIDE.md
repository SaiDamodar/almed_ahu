# Custom Domain Quick Guide

## Will `almed.org.in` Fix the DNS Issue?

**YES!** ✅ Using a custom domain will fix the DNS resolution issue on mobile data.

### Why?

- **Railway subdomains** (`*.up.railway.app`) are sometimes blocked by mobile carrier DNS
- **Custom domains** (`almed.org.in`) are rarely blocked and have better DNS resolution
- Your mobile carrier's DNS will resolve `almed.org.in` properly

## Can You Have Multiple Subdomains?

**YES!** ✅ You can have multiple subdomains:

- `api.almed.org.in` → For web dashboard API (main use)
- `admin.almed.org.in` → For admin panel (if needed)
- `app.almed.org.in` → For future use
- `www.almed.org.in` → For website (if needed)

**All subdomains can point to the same Railway service or different services.**

## Quick Setup Steps

### 1. Buy Domain
- Purchase `almed.org.in` from any registrar (GoDaddy, Namecheap, etc.)
- Cost: ~$10-15/year

### 2. Configure in Railway
1. Railway Dashboard → Your Service → Settings → Domains
2. Add custom domain: `api.almed.org.in`
3. Railway will show DNS records to add

### 3. Add DNS Records
In your domain registrar (where you bought the domain):
- Add CNAME record: `api` → `[railway-domain].up.railway.app`
- Wait 15-30 minutes for DNS propagation

### 4. Update App
Change in `lib/config/app_config.dart`:
```dart
static const String baseUrl = 'https://api.almed.org.in';
```

### 5. Test
- Rebuild app
- Test on mobile data (WiFi OFF)
- Should work! 🎉

## About Railway + Mobile Data

**Railway itself works fine** - the issue is DNS resolution, not Railway's service.

- Railway service is accessible from anywhere
- Problem: Mobile carrier DNS can't resolve Railway subdomains
- Solution: Use custom domain (Railway supports this)

## About Render (For Later)

Render is another hosting option similar to Railway:
- ✅ Also supports custom domains
- ✅ Similar pricing
- ✅ Good alternative if Railway has issues

**When you're ready to try Render:**
- We can create a `RENDER_DEPLOYMENT.md` guide
- Similar setup to Railway
- Also supports custom domains

## Summary

| Question | Answer |
|----------|--------|
| Will `almed.org.in` fix DNS issue? | ✅ YES |
| Can have subdomains? | ✅ YES (api, admin, app, etc.) |
| Railway works with mobile data? | ✅ YES (with custom domain) |
| Try Render later? | ✅ Sure, we can set it up when ready |

**Next Step**: Buy `almed.org.in` and follow `CUSTOM_DOMAIN_SETUP.md` guide!

