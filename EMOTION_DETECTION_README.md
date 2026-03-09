# Emotion Detection Feature for BloomBuddy

## Overview

The emotion detection feature in BloomBuddy uses Google ML Kit's face detection capabilities combined with a rule-based emotion classification system to detect and track emotions in real-time. This feature is specifically designed for children (ages 5-12) to help them understand and track their emotional states.

## Features

- **Real-time Emotion Detection**: Detects emotions every 5 seconds when activated
- **Camera Integration**: Uses the front camera for selfie-style emotion detection
- **Firebase Integration**: Logs all detected emotions to Firestore for tracking
- **User-friendly Interface**: Beautiful UI with emojis and color-coded emotions
- **Statistics Tracking**: Shows emotion history and statistics
- **Privacy-Focused**: Only stores emotion data, no images are saved

## Supported Emotions

The system can detect the following emotions:
- 😊 **Happy** - High smiling probability
- 😢 **Sad** - Low smiling with partially closed eyes
- 😠 **Angry** - Low smiling with head tilt and narrowed eyes
- 😨 **Fear** - Very low smiling with wide or closed eyes
- 😲 **Surprise** - Head tilted back with wide-open eyes
- 🤢 **Disgust** - Low smiling with head movement
- 😐 **Neutral** - Default state when other emotions don't match

## Technical Implementation

### Dependencies Used

- `google_ml_kit`: For face detection and facial feature extraction
- `camera`: For camera access and image capture
- `cloud_firestore`: For storing emotion data
- `permission_handler`: For camera permission management
- `tflite_flutter`: For potential future ML model integration

### Architecture

1. **EmotionDetectionService**: Singleton service that manages camera, face detection, and emotion classification
2. **EmotionDetectionWidget**: UI component that displays camera preview and emotion results
3. **ChildDashboard**: Main dashboard that includes the emotion detection feature

### Data Storage

Emotions are stored in Firestore with the following structure:
```
users/{userId}/emotions/{emotionId}
{
  emotion: "happy",
  timestamp: Timestamp,
  confidence: 0.8
}
```

## Setup Instructions

### 1. Dependencies

The required dependencies are already added to `pubspec.yaml`:
```yaml
camera: ^0.11.0+1
google_ml_kit: ^0.18.0
permission_handler: ^11.3.1
tflite_flutter: ^0.10.4
```

### 2. Android Permissions

Camera permissions are already configured in `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-feature android:name="android.hardware.camera" android:required="true" />
<uses-feature android:name="android.hardware.camera.front" android:required="false" />
```

### 3. Firebase Rules

The Firestore security rules are already configured to allow emotion data storage:
```javascript
match /users/{userId}/emotions/{emotionId} {
  allow read, write: if request.auth != null && request.auth.uid == userId;
}
```

## Usage

### For Children

1. Log in to the child dashboard
2. Tap on the "Emotion Detection" card
3. Grant camera permission when prompted
4. Tap "Start Detection" to begin emotion tracking
5. The app will detect emotions every 5 seconds
6. View recent emotions and statistics
7. Tap "Stop Detection" when finished

### For Parents/Mentors

Parents and mentors can view the emotion data through the Firestore console or by implementing additional dashboard features.

## Privacy and Security

- **No Image Storage**: Only emotion classification results are stored, not actual images
- **User-Specific Data**: Each user can only access their own emotion data
- **Secure Storage**: All data is stored securely in Firebase with proper authentication
- **Camera Permissions**: Camera access is only requested when needed

## Future Enhancements

1. **ML Model Integration**: Replace rule-based classification with a trained TensorFlow Lite model
2. **Emotion Trends**: Add analytics to show emotion patterns over time
3. **Parent Notifications**: Alert parents when concerning emotion patterns are detected
4. **Emotion Coaching**: Provide suggestions based on detected emotions
5. **Offline Support**: Cache emotion data for offline viewing

## Troubleshooting

### Common Issues

1. **Camera Permission Denied**
   - Solution: Go to device settings and manually grant camera permission

2. **No Face Detected**
   - Ensure good lighting
   - Position face clearly in camera view
   - Check if camera is working properly

3. **App Crashes on Emotion Detection**
   - Check if all dependencies are properly installed
   - Verify Firebase configuration
   - Ensure device has sufficient memory

### Debug Information

Enable debug logging by checking the console output for:
- Camera initialization status
- Face detection results
- Emotion classification results
- Firestore storage status

## Performance Considerations

- **Battery Usage**: Camera usage and frequent detection can impact battery life
- **Memory Usage**: The app uses moderate memory for camera preview and ML processing
- **Network Usage**: Minimal network usage for storing emotion data
- **Processing**: Face detection runs on-device for privacy and performance

## Contributing

To improve the emotion detection feature:

1. **Improve Classification**: Enhance the rule-based classification algorithm
2. **Add ML Model**: Train and integrate a custom TensorFlow Lite model
3. **UI Enhancements**: Improve the user interface and experience
4. **Testing**: Add comprehensive tests for different scenarios
5. **Documentation**: Update documentation as features evolve
