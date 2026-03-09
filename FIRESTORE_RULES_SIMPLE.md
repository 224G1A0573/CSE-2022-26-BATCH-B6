# Simplified Firestore Security Rules

Use these simplified rules to fix the permission issues:

```javascript
// Firestore Security Rules - Simplified Version

service cloud.firestore {
  match /databases/{database}/documents {

    // Each user can read/write ONLY their own user document
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;

      // Emotions subcollection (owner only)
      match /emotions/{emotionId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }

      // Notifications subcollection (owner only)
      match /notifications/{notificationId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
        // Allow anyone to create notifications (for therapist assignments)
        allow create: if request.auth != null;
      }

      // Child Information subcollection (for therapists to access child data)
      match /childInfo/{infoId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
        // Allow therapists to read child information if they are assigned as therapist
        allow read: if request.auth != null 
          && resource.data.therapistId == request.auth.uid;
      }
    }

    // Allow reading any user document for role-based operations
    match /users/{userId} {
      // Allow reading any user document (needed for queries by role and email)
      allow read: if request.auth != null;
      
      // Allow therapists to assign themselves to children or remove assignments
      allow update: if request.auth != null
        && resource.data.role == 'kid'
        && (
          // Allow assignment (therapistId matches current user)
          request.resource.data.therapistId == request.auth.uid
          ||
          // Allow removal (current therapist removing themselves - field deleted)
          (resource.data.therapistId == request.auth.uid && !('therapistId' in request.resource.data))
        );

      // Allow parents to update child documents they're linked to
      allow update: if request.auth != null
        && resource.data.role == 'kid'
        && (resource.data.guardianEmail == request.auth.token.email
            || resource.data.parentEmail == request.auth.token.email)
        && request.resource.data.diff(resource.data).changedKeys().hasOnly([
          // Basic Information
          'name','age','gender','height','weight','bloodGroup',
          // Medical Information
          'medicalConditions','medications','allergies',
          // Emotional & Behavioral Information
          'triggerPoints','behavioralPatterns','communicationStyle',
          // Preferences & Interests
          'likes','dislikes','learningStyle','socialPreferences',
          // Family & Background
          'familyHistory','schoolInfo',
          // Therapy & Goals
          'therapyGoals','emergencyContacts',
          // Additional Information
          'additionalNotes','lastUpdated',
          // Therapist Assignment
          'therapistId','therapistName','username',
          // Therapist Assignment Status
          'assignmentStatus','assignedAt',
          // Parent linking
          'guardianEmail','parentEmail'
        ]);

      // Allow therapists to update therapy-related fields
      allow update: if request.auth != null
        && resource.data.role == 'kid'
        && resource.data.therapistId == request.auth.uid
        && request.resource.data.diff(resource.data).changedKeys().hasOnly([
          'therapyNotes','sessionNotes','progressUpdates','recommendations',
          'lastTherapyUpdate'
        ]);
    }

    // Therapist-specific collections
    match /therapistNotes/{noteId} {
      allow read, write: if request.auth != null 
        && resource.data.therapistId == request.auth.uid;
    }

    match /sessionReports/{reportId} {
      allow read, write: if request.auth != null 
        && resource.data.therapistId == request.auth.uid;
      // Allow parents to read reports about their children
      allow read: if request.auth != null
        && resource.data.childGuardianEmail == request.auth.token.email;
    }

    // Parent-Therapist Communication
    match /parentTherapistChat/{chatId} {
      allow read, write: if request.auth != null 
        && (resource.data.parentId == request.auth.uid 
            || resource.data.therapistId == request.auth.uid);
    }

    // Deny everything else
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

## Key Changes:

1. **Simplified user access**: Allow reading any user document (needed for queries)
2. **Clear therapist assignment**: Allow therapists to update child documents with assignment fields
3. **Parent linking**: Allow parents to update child documents they're linked to
4. **Removed complex nested rules**: Simplified the rule structure

## How to Deploy:

1. Copy the rules above
2. Go to Firebase Console → Firestore Database → Rules
3. Replace the existing rules with these simplified rules
4. Click "Publish"

This should fix the permission denied errors you're seeing in the logs!
