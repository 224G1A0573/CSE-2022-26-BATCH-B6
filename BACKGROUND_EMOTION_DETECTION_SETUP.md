# Background Emotion Detection Setup Guide

## Overview

This guide explains how to set up automatic background emotion detection that starts immediately when a child logs in, with email notifications to parents.

## Features

✅ **Automatic Background Detection**: Starts immediately when child logs in
✅ **Parent Email Notifications**: Sends emails about emotion detection activation
✅ **Concerning Emotion Alerts**: Notifies parents of concerning emotions (angry, fear, sad)
✅ **No Child Control**: Children have no options to disable or control the detection
✅ **Privacy Respectful**: Uses low-resolution images and deletes them immediately
✅ **Firestore Logging**: All emotions and alerts are logged to Firestore

## System Architecture

```
Child Login → Background Service Initializes → Camera Permission → Start Detection
     ↓
Every 10 seconds: Take Photo → Detect Emotion → Log to Firestore
     ↓
If Concerning Emotion: Send Email Alert to Parent
```

## Setup Instructions

### 1. Dependencies

The following dependencies are already added to `pubspec.yaml`:
- `camera: ^0.11.0+1`
- `google_ml_kit: ^0.18.0`
- `permission_handler: ^11.3.1`
- `http: ^1.1.0`

### 2. Email Service Configuration

We're using **EmailJS** for email notifications. Follow the complete setup guide:

#### EmailJS Setup (Recommended for Play Store)
1. **Follow the detailed guide**: `EMAILJS_SETUP_GUIDE.md`
2. **Create EmailJS account** and get your credentials
3. **Update the service configuration** in `email_notification_service.dart`
4. **Test email delivery** with real parent emails

#### Alternative Options
- **SendGrid**: More complex setup, higher costs
- **Firebase Functions**: Advanced, requires server setup
- **Mailgun**: Similar to SendGrid

**For Play Store deployment, EmailJS is the best choice due to simplicity and reliability.**

### 3. Firestore Security Rules

Ensure your Firestore rules allow the new collections:

```javascript
service cloud.firestore {
  match /databases/{database}/documents {
    // Allow users to read/write their own user document
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
      
      // Allow emotion detection updates
      allow update: if request.auth != null && request.auth.uid == userId;
      
      // Allow emotions subcollection
      match /emotions/{emotionId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
      
      // Allow notifications subcollection
      match /notifications/{notificationId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
      
      // Allow alerts subcollection
      match /alerts/{alertId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
    }
    
    // Deny all other access by default
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

### 4. User Data Structure

Ensure child users have the following fields in Firestore:
```json
{
  "role": "kid",
  "name": "Child Name",
  "parentEmail": "parent@example.com",
  "emotionDetectionActive": false,
  "emotionDetectionStartedAt": null,
  "emotionDetectionStoppedAt": null
}
```

## How It Works

### 1. Child Login Process
1. Child logs in with role "kid"
2. `ChildDashboard` initializes
3. `BackgroundEmotionService` starts automatically
4. Camera permission is requested
5. Background detection begins

### 2. Background Detection Process
1. **Every 10 seconds**: Takes a low-resolution photo
2. **Face Detection**: Uses Google ML Kit to detect faces
3. **Emotion Classification**: Applies rule-based emotion detection
4. **Logging**: Saves emotion data to Firestore
5. **Cleanup**: Deletes the temporary photo immediately

### 3. Parent Notification Process
1. **Initial Notification**: Sent when emotion detection starts
2. **Concerning Emotion Alerts**: Sent for angry, fear, or sad emotions with >70% confidence
3. **Email Content**: Professional, informative, and reassuring

### 4. Data Storage
- **Emotions**: Stored in `users/{userId}/emotions/`
- **Notifications**: Stored in `users/{userId}/notifications/`
- **Alerts**: Stored in `users/{userId}/alerts/`
- **User Status**: Updated in `users/{userId}` document

## Privacy and Security

### Privacy Features
- **Low Resolution**: Uses `ResolutionPreset.low` for minimal data
- **Immediate Deletion**: Photos are deleted after processing
- **No Storage**: No images are stored permanently
- **Local Processing**: Emotion detection happens on device

### Security Features
- **Firestore Rules**: Restrict access to user's own data
- **Authentication Required**: Only authenticated users can access
- **No Child Control**: Children cannot disable or modify detection
- **Parent Consent**: Parents are notified of monitoring

## Testing the System

### 1. Test Child Login
1. Log in as a child user
2. Check console for initialization messages
3. Verify background detection starts
4. Check Firestore for emotion logs

### 2. Test Parent Notifications
1. Ensure child has `parentEmail` field in Firestore
2. Trigger concerning emotions (angry, fear, sad)
3. Check email service logs
4. Verify Firestore notification/alert records

### 3. Test Emotion Detection
1. Make different facial expressions
2. Check console for detection logs
3. Verify Firestore emotion records
4. Test concerning emotion alerts

## Troubleshooting

### Common Issues

#### 1. Camera Permission Denied
- **Solution**: Check app permissions in device settings
- **Debug**: Look for "Camera permission denied" in console

#### 2. Email Notifications Not Sending
- **Solution**: Check email service configuration
- **Debug**: Verify webhook URL or Firebase Function URL

#### 3. Background Detection Not Starting
- **Solution**: Check child user data in Firestore
- **Debug**: Look for initialization error messages

#### 4. No Emotions Being Detected
- **Solution**: Check lighting and camera positioning
- **Debug**: Look for face detection error messages

### Debug Information

The system provides extensive debug information:
```
Background emotion detection started for child: [userId]
Parent notification sent successfully to: [email]
Background emotion detected: happy (confidence: 0.85)
Concerning emotion alert sent successfully to: [email]
```

## Customization Options

### 1. Detection Frequency
Change the detection interval in `background_emotion_service.dart`:
```dart
_detectionTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
  // Change from 10 to desired seconds
});
```

### 2. Concerning Emotion Threshold
Modify the confidence threshold in `_isConcerningEmotion()`:
```dart
bool _isConcerningEmotion(String emotion, double confidence) {
  const concerningEmotions = ['angry', 'fear', 'sad'];
  return concerningEmotions.contains(emotion) && confidence > 0.7; // Change threshold
}
```

### 3. Email Templates
Customize email content in `email_notification_service.dart`

### 4. Emotion Classification
Modify thresholds in `_classifyEmotionWithConfidence()` method

## Production Considerations

### 1. Email Service
- Use a reliable email service (SendGrid, Mailgun, AWS SES)
- Set up proper authentication and rate limiting
- Monitor email delivery rates

### 2. Performance
- Monitor device battery usage
- Consider detection frequency based on usage patterns
- Optimize image processing for different devices

### 3. Privacy Compliance
- Ensure compliance with local privacy laws
- Consider parental consent requirements
- Implement data retention policies

### 4. Monitoring
- Set up alerts for system failures
- Monitor emotion detection accuracy
- Track parent notification delivery rates

## Support

For issues or questions:
1. Check console logs for error messages
2. Verify Firestore data structure
3. Test email service configuration
4. Review privacy and security settings

The system is designed to be robust and privacy-respecting while providing valuable insights for child safety and well-being monitoring.
