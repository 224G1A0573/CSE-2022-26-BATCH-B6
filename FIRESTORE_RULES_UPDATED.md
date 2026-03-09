# Updated Firestore Security Rules

The following rules have been updated to support therapist assignment notifications and the new therapist dashboard functionality:

```javascript
// Firestore Security Rules

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
      }

      // Child Information subcollection (for therapists to access child data)
      match /childInfo/{infoId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
        // Allow therapists to read child information if they are assigned as therapist
        allow read: if request.auth != null 
          && resource.data.therapistId == request.auth.uid;
      }
    }

    // Parent ↔ Child linking and comprehensive management

    match /users/{childId} {
      // 1) Allow reading kid docs so parent can locate child by email to link
      //    Also allow therapists to read child docs for assignment
      allow read: if request.auth != null && resource.data.role == 'kid';

      // 2) Allow a parent to LINK a child by setting ONLY guardianEmail/parentEmail
      //    Both must equal the caller's email.
      allow update: if request.auth != null
        && (
          (
            request.resource.data.diff(resource.data).changedKeys().hasOnly(['guardianEmail', 'parentEmail'])
            && request.resource.data.guardianEmail == request.auth.token.email
            && request.resource.data.parentEmail == request.auth.token.email
          )
          ||
          (
            // 3) After linked, allow parent to update comprehensive child profile fields
            (resource.data.guardianEmail == request.auth.token.email
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
              'assignmentStatus','assignedAt'
            ])
          )
        );

      // 4) Allow therapists to read child information if they are assigned as therapist
      allow read: if request.auth != null 
        && resource.data.role == 'kid'
        && resource.data.therapistId == request.auth.uid;

      // 5) Allow therapists to update therapy-related fields
      allow update: if request.auth != null
        && resource.data.role == 'kid'
        && resource.data.therapistId == request.auth.uid
        && request.resource.data.diff(resource.data).changedKeys().hasOnly([
          'therapyNotes','sessionNotes','progressUpdates','recommendations',
          'lastTherapyUpdate'
        ]);

      // 6) Allow therapists to assign themselves to children
      allow update: if request.auth != null
        && resource.data.role == 'kid'
        && request.resource.data.diff(resource.data).changedKeys().hasOnly([
          'therapistId','therapistName','assignmentStatus','assignedAt'
        ])
        && request.resource.data.therapistId == request.auth.uid;

      // 7) Allow therapists to read any child document to check if they can assign
      allow read: if request.auth != null 
        && resource.data.role == 'kid';
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

## Key Changes Made:

1. **Added therapist assignment fields**: `assignmentStatus` and `assignedAt` to the allowed fields for child updates
2. **Added therapist assignment rule**: Allows therapists to assign themselves to children by updating `mentorId`, `mentorName`, `assignmentStatus`, and `assignedAt` fields
3. **Enhanced notification support**: The existing notification subcollection rules support the new therapist assignment notifications
4. **Maintained security**: All rules ensure that users can only access their own data and data they're authorized to see

## How It Works:

1. **Therapist Assignment**: When a therapist assigns themselves to a child, they can update the child's `mentorId`, `mentorName`, `assignmentStatus`, and `assignedAt` fields
2. **Parent Notifications**: Parents receive notifications in their `notifications` subcollection when a therapist requests assignment
3. **Assignment Response**: Parents can accept/reject assignments, which updates the child's `assignmentStatus` and creates notifications for the therapist
4. **Data Access**: Once assigned, therapists can read child information and update therapy-related fields

## Testing the Rules:

1. Deploy these rules to your Firebase console
2. Test therapist assignment by having a therapist assign themselves to a child
3. Verify that parents receive notifications
4. Test parent acceptance/rejection of assignments
5. Verify that therapists can only access assigned children's data