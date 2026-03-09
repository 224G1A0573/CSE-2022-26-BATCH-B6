# 🎨 CANVAS SETUP - 2 MINUTE GUIDE

## 🚨 WHY IT'S NOT WORKING:

**Firebase Realtime Database is not enabled!**

The collaborative canvas needs Realtime Database to sync drawings between devices.

---

## ✅ SETUP IN 5 STEPS (2 MINUTES):

### Step 1: Open Firebase Console
Go to: https://console.firebase.google.com

### Step 2: Select Your Project
Click on **"bloombuddy"** project

### Step 3: Create Realtime Database
1. Click **"Realtime Database"** in left menu
2. Click **"Create Database"** button
3. Choose location: **United States (us-central1)** (or nearest to you)
4. Click **"Next"**

### Step 4: Start in Test Mode
1. Select **"Start in test mode"**
2. Click **"Enable"**

⚠️ Test mode allows anyone to read/write (we'll secure it later)

### Step 5: Publish Rules (Optional but Recommended)
Click on **"Rules"** tab and replace with:

```json
{
  "rules": {
    "canvasSessions": {
      "$sessionId": {
        ".read": "auth != null",
        ".write": "auth != null"
      }
    }
  }
}
```

Click **"Publish"**

---

## 🎉 DONE! NOW TEST:

### Hot Reload App:
```bash
r
```

### Test Flow:

**As Child:**
1. Login as child
2. Click "Draw Together 🎨"
3. Select your therapist
4. Canvas should open! ✅

**As Therapist:**
1. Login as therapist
2. Go to Children tab
3. Click child's "Draw" button
4. Canvas should open! ✅

---

## 🔍 TROUBLESHOOTING:

### Error: "Cannot find therapist"
**Solution:** Make sure child has therapist assigned in Firestore:
```
users/{childId}/therapistId = {therapistId}
```

### Error: "Permission denied"
**Solution:** Realtime Database rules not published. Repeat Step 5 above.

### Error: Still nothing happens
**Solution:** Check console logs for specific error message, then contact support.

---

## 📱 TESTING WITH ONE DEVICE:

Since you're testing on same device by logging in/out:

1. **Login as Child** → Click "Draw Together"
2. **Logout**
3. **Login as Therapist** → Go to same child's "Draw" button
4. Both will see same canvas!

⚠️ **NOTE:** Real-time sync works best with 2 separate devices, but single device testing works too!

---

## ✅ WHAT SHOULD HAPPEN:

When canvas opens:
- ✅ White canvas appears
- ✅ Drawing tools at top (colors, brush size, eraser)
- ✅ Emotion indicator shows your current emotion
- ✅ You can draw immediately
- ✅ Other person sees your strokes (if logged in on another device)

---

## 🎨 CANVAS FEATURES:

- **8 Colors** to choose from
- **Brush Size** slider (2-20 pixels)
- **Eraser** tool
- **Clear Canvas** button (clears for both)
- **Save Artwork** button (saves as PNG)
- **Emotion Colors** - Brush color changes with your emotion!

---

## 🚀 READY?

**Setup time:** 2 minutes  
**Difficulty:** Easy  
**Result:** Real-time collaborative drawing! 🎉

---

**Any issues? The app will now show you a helpful error message!** 🔧

