# Emotion Detection Testing Guide

## Overview

This guide will help you test and calibrate the improved emotion detection system. The system now includes better thresholds, confidence scoring, and debug information to help identify and fix detection issues.

## What's Improved

1. **Better Thresholds**: Adjusted emotion detection thresholds for more accurate classification
2. **Confidence Scoring**: Each emotion detection now includes a confidence score (0.0-1.0)
3. **Debug Information**: Console logs show facial feature values for troubleshooting
4. **Manual Testing**: Added a manual detection button for immediate testing
5. **Quality Filter**: Only logs emotions with confidence > 0.6

## How to Test

### 1. Basic Testing
1. Open the emotion detection screen
2. Use the **blue camera button** for manual testing
3. Try different facial expressions
4. Check the console for debug information
5. View the detected emotion and confidence score

### 2. Testing Each Emotion

#### 😊 Happy
- **Action**: Smile naturally
- **Expected**: High confidence (>0.7) when smiling
- **Debug Values**: Smiling probability should be >0.5

#### 😲 Surprise
- **Action**: Raise eyebrows, open eyes wide, tilt head back slightly
- **Expected**: Eyes very open (>0.85), head tilted back (>6 degrees)
- **Debug Values**: 
  - Left/Right Eye: >0.85
  - Head Z: >6

#### 😨 Fear
- **Action**: Open eyes very wide OR close them tightly, no smile
- **Expected**: Very low smiling (<0.25), eyes either very open (>0.9) or very closed (<0.4)
- **Debug Values**:
  - Smiling: <0.25
  - Eyes: >0.9 OR <0.4

#### 😠 Angry
- **Action**: Frown, narrow eyes, tilt head to side OR just frown with narrowed eyes
- **Expected**: Low smiling (<0.4), narrowed eyes (<0.7), head tilted (>5 degrees) OR very low smiling (<0.3) with very narrowed eyes (<0.6)
- **Debug Values**:
  - Method 1: Smiling: <0.4, Eyes: <0.7, Head Y: >5
  - Method 2: Smiling: <0.3, Eyes: <0.6 (no head tilt needed)

#### 😢 Sad
- **Action**: Slight frown, partially close eyes, minimal head movement
- **Expected**: Low smiling (<0.4), partially closed eyes (<0.7), little head movement (<5)
- **Debug Values**:
  - Smiling: <0.4
  - Eyes: <0.7
  - Head movement: <5

#### 🤢 Disgust
- **Action**: Slight frown, move head side to side or up/down
- **Expected**: Low smiling (<0.35), moderate head movement (4-15)
- **Debug Values**:
  - Smiling: <0.35
  - Head movement: 4-15

#### 😐 Neutral
- **Action**: Relaxed face, natural expression
- **Expected**: Default when other emotions don't match

## Debug Information

When you use the manual detection button, check the console for:
```
Debug - Smiling: 0.75, Left Eye: 0.80, Right Eye: 0.85, Head Y: 2.50, Head Z: 1.20
Detected emotion: happy (confidence: 0.90)
```

## Troubleshooting

### If emotions are not detected correctly:

1. **Check lighting**: Ensure good, even lighting on your face
2. **Position**: Face the camera directly, about 1-2 feet away
3. **Expression intensity**: Make expressions more pronounced
4. **Head movement**: Minimize head movement for more stable detection
5. **Eye contact**: Look directly at the camera

### If confidence is low:

1. **Adjust thresholds**: The system only logs emotions with confidence >0.6
2. **Check debug values**: Compare your facial features with expected ranges
3. **Try different expressions**: Some expressions may be more reliable than others

## Expected Debug Values by Emotion

| Emotion | Smiling | Eyes | Head Y | Head Z | Confidence |
|---------|---------|------|--------|--------|------------|
| Happy | >0.5 | Any | Any | Any | >0.7 |
| Surprise | Any | >0.85 | Any | >6 | >0.6 |
| Fear | <0.25 | >0.9 OR <0.4 | Any | Any | >0.6 |
| Angry | <0.4/<0.3 | <0.7/<0.6 | >5/Any | Any | >0.6 |
| Sad | <0.4 | <0.7 | <5 | <5 | >0.6 |
| Disgust | <0.35 | Any | 4-15 | 4-15 | >0.6 |
| Neutral | Any | Any | Any | Any | 0.5 |

## Tips for Better Detection

1. **Start with Happy**: This is the most reliable emotion to test
2. **Use Manual Button**: Test each expression individually
3. **Check Console**: Monitor debug values to understand detection
4. **Adjust Expression**: Make expressions more or less intense based on results
5. **Good Lighting**: Natural, even lighting works best
6. **Stable Position**: Minimize movement during detection

## Next Steps

If you're still having issues with specific emotions:

1. **Note the debug values** when the emotion is detected incorrectly
2. **Try adjusting the thresholds** in the `_classifyEmotionWithConfidence` method
3. **Test with different expressions** to find the most reliable ones
4. **Consider the lighting and positioning** of your face

The system is designed to be easily adjustable - you can modify the thresholds in the code to better match your specific use case and testing environment.
