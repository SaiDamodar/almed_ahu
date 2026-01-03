# Testing User Permissions - Complete Guide

This guide explains how to test setting permissions (access levels) for users in the web dashboard.

## Understanding User Permissions

The system has **two access levels**:

1. **👁️ Viewer (viewer)** - Read-only access
   - Can view dashboard data
   - Cannot control AHU units (buttons disabled)
   - Cannot change settings

2. **🔧 Operator (operator)** - Full control access
   - Can view dashboard data
   - Can control AHU units (Start, Stop, Auto, Manual, etc.)
   - Can change settings (if allowed)

---

## Testing Scenarios

### Scenario 1: Set Permission When Approving a New User

**Step 1: Create a test user registration**

1. Open your web dashboard (as a regular user, not admin)
2. Navigate to registration page (or use the API directly)
3. Register a new user with:
   - Email: `testuser@example.com`
   - Username: `Test User`
   - Password: `testpass123`
   - Hospital: `Test Hospital`
   - Phone: `1234567890`

**Step 2: Login as Admin**

1. Go to: `https://your-domain.com` (or `http://your-ec2-ip:5000`)
2. Login with admin credentials (default: username `admin`, passcode `1234`)
3. Navigate to **Users** page (in the sidebar)

**Step 3: Approve user with permission**

1. You'll see the new user in the **"Pending Registrations"** section
2. Notice the **Access Level dropdown** below the user info:
   - Options: `🔧 Operating Access` or `👁️ View Only`
3. **Select the desired permission** (try `🔧 Operating Access` first)
4. Click the **"Approve"** button
5. Confirm the approval
6. The user should move to the **"Registered Users"** section
7. Verify the badge shows the correct access level (🔧 Operating or 👁️ View Only)

**Step 4: Test the permission**

1. **Logout** from admin account
2. **Login** with the test user credentials (`testuser@example.com` / `testpass123`)
3. Navigate to the **AHU Control** page
4. **If permission is "Operator":**
   - Operating buttons (Start, Stop, Auto, Manual) should be **enabled**
   - You should be able to click and use them
5. **If permission is "Viewer":**
   - Operating buttons should be **disabled** (grayed out)
   - You should see a message indicating view-only access

---

### Scenario 2: Change Permission for an Existing User

**Step 1: Login as Admin**

1. Login to the dashboard as admin
2. Navigate to **Users** page

**Step 2: Find an existing user**

1. Look in the **"Registered Users"** section
2. Find a user you want to test with
3. Note their current access level badge (🔧 Operating or 👁️ View Only)

**Step 3: Change the permission**

1. Find the **Access Level dropdown** in the user card (bottom right)
2. **Change the dropdown** from:
   - `🔧 Operator` → `👁️ Viewer` (to downgrade)
   - OR `👁️ Viewer` → `🔧 Operator` (to upgrade)
3. The change should happen **immediately** (no page reload needed)
4. The badge should update automatically

**Step 4: Verify the change**

1. Check the user's badge - it should show the new access level
2. **Test with the user account:**
   - Logout from admin
   - Login as that user
   - Check if buttons are enabled/disabled based on the new permission

---

## Testing via API (Advanced)

You can also test permissions directly via API calls:

### Test 1: Approve User with Permission

```bash
# Replace USER_ID and your-domain.com with actual values
curl -X POST https://your-domain.com/api/admin/users/USER_ID/approve \
  -H "Content-Type: application/json" \
  -H "Cookie: session=YOUR_SESSION_COOKIE" \
  -d '{"access_level": "operator"}'
```

**Expected Response:**
```json
{
  "success": true,
  "message": "User approved with Operating Access"
}
```

### Test 2: Update User Permission

```bash
# Change existing user's permission
curl -X POST https://your-domain.com/api/admin/users/USER_ID/access-level \
  -H "Content-Type: application/json" \
  -H "Cookie: session=YOUR_SESSION_COOKIE" \
  -d '{"access_level": "viewer"}'
```

**Expected Response:**
```json
{
  "success": true,
  "message": "Access level updated to View Only"
}
```

### Test 3: Check User's Current Permission

```bash
# Get all registered users and check their access levels
curl https://your-domain.com/api/admin/users/registered \
  -H "Cookie: session=YOUR_SESSION_COOKIE"
```

**Expected Response:**
```json
{
  "success": true,
  "users": [
    {
      "_id": "user_id_here",
      "email": "testuser@example.com",
      "username": "Test User",
      "access_level": "operator",
      "status": "approved",
      ...
    }
  ]
}
```

---

## Complete Test Checklist

### ✅ Basic Functionality Tests

- [ ] Can see pending users in "Pending Registrations" section
- [ ] Can see registered users in "Registered Users" section
- [ ] Access level dropdown appears when approving users
- [ ] Access level dropdown appears for registered users
- [ ] Badge shows correct access level (🔧 or 👁️)
- [ ] Permission change updates immediately (no page reload)

### ✅ Permission Setting Tests

- [ ] Can approve user with "Operator" permission
- [ ] Can approve user with "Viewer" permission
- [ ] Can change existing user from "Operator" to "Viewer"
- [ ] Can change existing user from "Viewer" to "Operator"
- [ ] Permission changes persist after page refresh

### ✅ Permission Enforcement Tests

- [ ] **Operator user:**
  - [ ] Can see AHU control page
  - [ ] Operating buttons are enabled
  - [ ] Can click Start/Stop/Auto/Manual buttons
  - [ ] Commands are sent successfully

- [ ] **Viewer user:**
  - [ ] Can see AHU control page
  - [ ] Operating buttons are disabled/grayed out
  - [ ] Cannot click control buttons
  - [ ] Sees appropriate message about view-only access

### ✅ Error Handling Tests

- [ ] Cannot approve user without selecting permission (defaults to viewer)
- [ ] Cannot change permission if not logged in as admin
- [ ] Error message shows if API call fails
- [ ] Page reloads if permission update fails

---

## Troubleshooting

### Issue: Permissions not changing

**Solution:**
1. Check browser console (F12) for JavaScript errors
2. Verify you're logged in as admin
3. Check server logs for API errors
4. Try refreshing the page and checking if change persisted

### Issue: Buttons still enabled for Viewer users

**Solution:**
1. Verify the user's `access_level` in the database is actually `viewer`
2. Check if the frontend is checking `access_level` correctly
3. Clear browser cache and cookies
4. Login again with the user account

### Issue: Permission dropdown not appearing

**Solution:**
1. Check if you're logged in as admin (required for Users page)
2. Verify the page loaded correctly (check browser console)
3. Try hard refresh (Ctrl+F5 or Cmd+Shift+R)
4. Check if JavaScript is enabled

### Issue: API returns 403 (Forbidden)

**Solution:**
1. Make sure you're logged in as admin
2. Check your session cookie is valid
3. Verify admin authentication in session
4. Try logging out and logging back in

---

## Quick Test Commands (On EC2)

If you want to test via command line on your EC2 instance:

```bash
# 1. Get your EC2 public IP
curl http://169.254.169.254/latest/meta-data/public-ipv4

# 2. Test if server is running
curl http://localhost:5000/users

# 3. Check server logs (if running with nohup)
tail -f ~/Almed_ahu_webapp/web_dashboard/webapp.log

# 4. Check MongoDB for user permissions (if you have mongo client)
# mongo your-connection-string
# use almed_ahu
# db.users.find({email: "testuser@example.com"}, {access_level: 1, status: 1})
```

---

## Expected Behavior Summary

| Action | Expected Result |
|--------|----------------|
| Approve user with "Operator" | User moves to Registered Users, badge shows 🔧 Operating |
| Approve user with "Viewer" | User moves to Registered Users, badge shows 👁️ View Only |
| Change Operator → Viewer | Badge updates immediately, user loses control access |
| Change Viewer → Operator | Badge updates immediately, user gains control access |
| Operator user logs in | Control buttons enabled, can operate AHUs |
| Viewer user logs in | Control buttons disabled, view-only access |

---

## Notes

- **Default permission:** When approving users, if no permission is selected, it defaults to `viewer` (View Only)
- **Admin users:** Admin users always have full access regardless of permission settings
- **Permission validation:** Only `operator` and `viewer` are valid values
- **Real-time updates:** Permission changes in the UI update immediately without page reload
- **Database:** Permissions are stored in MongoDB in the `users` collection, field `access_level`

