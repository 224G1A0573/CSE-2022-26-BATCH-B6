# 🧪 Eye Tracking Testing Guide

## 🚀 **Quick Start Testing**

Follow these steps to test your new eye tracking feature:

---

## ✅ **Step 1: Deploy Firestore Rules**

First, deploy the updated Firestore rules that include eye tracking permissions:

```bash
cd bloombuddy
firebase deploy --only firestore:rules
```

**Expected Output:**
```
✔  firestore: released rules for database (default)
✔  Deploy complete!
```

---

## ✅ **Step 2: Run the Flutter App**

```bash
flutter run
```

**Or** if you have an emulator/device connected:
```bash
flutter run -d <device-id>
```

---

## ✅ **Step 3: Log In as Child**

1. Open the app
2. Sign in with a child account
3. Watch the console logs

**Expected Console Output:**
```
User migration completed
Background emotion detection started for child: [userId]
Background eye tracking initialized for child: [Child Name]
Background eye tracking started for child: [userId]
Emergency monitoring started for child: [userId]
```

---

## ✅ **Step 4: Verify Eye Tracking**

### **Check Console Logs:**
Look for eye tracking messages every 500ms:
```
Gaze tracked: center (960, 540)
Gaze tracked: right (1200, 600)
Gaze tracked: left (600, 500)
Gaze tracked: up (900, 200)
Gaze tracked: down (950, 900)
```

### **Check Firestore:**
1. Open **Firebase Console**
2. Go to **Firestore Database**
3. Navigate to: `users/{childUserId}/eyeTracking`
4. You should see new documents appearing every 500ms

**Expected Data Structure:**
```javascript
{
  childName: "Child Name",
  gazeDirection: "center",
  gazeX: 0.52,
  gazeY: 0.45,
  headRotationY: 2.3,
  headRotationZ: -1.1,
  leftEyeOpenProbability: 0.94,
  rightEyeOpenProbability: 0.96,
  screenX: 998.4,
  screenY: 486.0,
  timestamp: October 21, 2025 at 11:30:15 AM UTC
}
```

---

## ✅ **Step 5: Test Eye Movements**

While the app is running, try these movements:

### **Test 1: Look Up**
- Look up towards the ceiling
- Console should show: `Gaze tracked: up (x, y)`

### **Test 2: Look Down**
- Look down towards your lap
- Console should show: `Gaze tracked: down (x, y)`

### **Test 3: Look Left**
- Turn your eyes/head left
- Console should show: `Gaze tracked: left (x, y)`

### **Test 4: Look Right**
- Turn your eyes/head right
- Console should show: `Gaze tracked: right (x, y)`

### **Test 5: Look Center**
- Look straight at the camera
- Console should show: `Gaze tracked: center (x, y)`

---

## ✅ **Step 6: Verify User Document**

Check the user's main document for latest gaze info:

**Path**: `users/{childUserId}`

**Expected Fields:**
```javascript
{
  ...existing fields...,
  
  // NEW Eye Tracking Fields
  eyeTrackingActive: true,
  eyeTrackingLastUpdate: Timestamp,
  latestGazeDirection: "center",
  latestGazeUpdate: Timestamp
}
```

---

## 🐛 **Troubleshooting**

### **Issue 1: No Console Logs**
**Problem**: Eye tracking not initializing

**Solutions:**
1. Check camera permission:
   ```
   Go to Device Settings → Apps → BloomBuddy → Permissions → Camera → Allow
   ```
2. Check for error messages in console
3. Restart the app

---

### **Issue 2: No Firestore Data**
**Problem**: Data not being logged to Firestore

**Solutions:**
1. Verify Firestore rules are deployed:
   ```bash
   firebase deploy --only firestore:rules
   ```
2. Check network connection
3. Check Firebase Console for errors
4. Verify child is authenticated

---

### **Issue 3: Inaccurate Tracking**
**Problem**: Gaze direction doesn't match actual eye movement

**Solutions:**
1. **Improve Lighting**: Ensure good lighting on your face
2. **Position Camera**: Face the camera directly
3. **Adjust Thresholds**: Modify direction detection thresholds in code
4. **Increase Smoothing**: Increase smoothing window from 5 to 10

---

### **Issue 4: App Crashes**
**Problem**: App crashes when child logs in

**Solutions:**
1. Check Google ML Kit is properly installed:
   ```bash
   flutter pub get
   ```
2. Check device has sufficient memory
3. Try on a different device
4. Check error stack trace in console

---

## 📊 **Performance Testing**

### **Monitor Battery Usage:**
```
Device Settings → Battery → App Battery Usage
```
- Eye tracking uses camera every 500ms
- Monitor for excessive battery drain
- Adjust frequency if needed

### **Monitor Data Usage:**
```
Device Settings → Data Usage → App Data Usage
```
- Each gaze point: ~200 bytes
- 120 points/minute = ~14 KB/minute
- Should be minimal impact

### **Monitor Storage:**
```
Firebase Console → Firestore → Usage
```
- 7,200 data points/hour
- Monitor Firestore document count
- Set up data retention policies if needed

---

## 🔍 **Debug Commands**

### **Check Eye Tracking Status:**
```dart
// In child_dashboard.dart, you can add a debug button:
print('Eye tracking active: ${_eyeTrackingService.isTracking}');
print('Eye tracking initialized: ${_eyeTrackingService.isInitialized}');
```

### **Manual Test:**
```dart
// Test eye tracking manually:
await _eyeTrackingService.initializeForChild(userId);
await _eyeTrackingService.startBackgroundTracking();
```

---

## ✅ **Success Checklist**

- [ ] Firestore rules deployed successfully
- [ ] App builds and runs without errors
- [ ] Child logs in successfully
- [ ] Console shows eye tracking initialization
- [ ] Console shows gaze tracking every 500ms
- [ ] Firestore shows eye tracking data
- [ ] User document updated with latest gaze
- [ ] Eye movements tracked correctly (up/down/left/right)
- [ ] No camera permission errors
- [ ] No performance issues

---

## 🎉 **If All Tests Pass:**

**Congratulations!** Your eye tracking is working perfectly!

### **What's Happening:**
✅ Child logs in → Eye tracking starts automatically
✅ Camera captures frames every 500ms
✅ Google ML Kit detects face and eye landmarks
✅ Gaze position calculated and smoothed
✅ Direction detected (up/down/left/right/center)
✅ Data logged to Firestore with timestamps
✅ Parents/therapists can view gaze patterns

### **Next Steps:**
1. **Monitor Performance**: Check battery and data usage
2. **Analyze Data**: Review gaze patterns in Firestore
3. **Build Dashboard**: Create parent/therapist view
4. **Add Visualizations**: Heat maps, attention graphs
5. **Optimize**: Adjust frequency and thresholds as needed

---

## 📞 **Need Help?**

If you encounter any issues:

1. **Check console logs** for error messages
2. **Verify Firestore rules** are deployed
3. **Test camera permissions** manually
4. **Try on different device** to isolate issue
5. **Review implementation guide**: `EYE_TRACKING_IMPLEMENTATION.md`

---

**Happy Testing! 👁️ 🎯**

