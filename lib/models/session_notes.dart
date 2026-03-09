import 'package:cloud_firestore/cloud_firestore.dart';

class SessionNotes {
  final String id;
  final String childId;
  final String childName;
  final String therapistId;
  final String therapistName;
  final DateTime sessionDate;
  final String sessionTime; // e.g., "09:00-11:00"
  final DateTime startTime;
  final DateTime endTime;
  final String behaviorObservations;
  final String improvements;
  final String challenges;
  final String activitiesPerformed;
  final String childEngagement;
  final String emotionalState;
  final String recommendations;
  final String nextSessionGoals;
  final String additionalNotes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isUploaded;
  final String parentId;
  final String parentEmail;

  SessionNotes({
    required this.id,
    required this.childId,
    required this.childName,
    required this.therapistId,
    required this.therapistName,
    required this.sessionDate,
    required this.sessionTime,
    required this.startTime,
    required this.endTime,
    required this.behaviorObservations,
    required this.improvements,
    required this.challenges,
    required this.activitiesPerformed,
    required this.childEngagement,
    required this.emotionalState,
    required this.recommendations,
    required this.nextSessionGoals,
    required this.additionalNotes,
    required this.createdAt,
    required this.updatedAt,
    required this.isUploaded,
    required this.parentId,
    required this.parentEmail,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'childId': childId,
      'childName': childName,
      'therapistId': therapistId,
      'therapistName': therapistName,
      'sessionDate': sessionDate,
      'sessionTime': sessionTime,
      'startTime': startTime,
      'endTime': endTime,
      'behaviorObservations': behaviorObservations,
      'improvements': improvements,
      'challenges': challenges,
      'activitiesPerformed': activitiesPerformed,
      'childEngagement': childEngagement,
      'emotionalState': emotionalState,
      'recommendations': recommendations,
      'nextSessionGoals': nextSessionGoals,
      'additionalNotes': additionalNotes,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'isUploaded': isUploaded,
      'parentId': parentId,
      'parentEmail': parentEmail,
    };
  }

  factory SessionNotes.fromMap(Map<String, dynamic> map) {
    return SessionNotes(
      id: map['id'] ?? '',
      childId: map['childId'] ?? '',
      childName: map['childName'] ?? '',
      therapistId: map['therapistId'] ?? '',
      therapistName: map['therapistName'] ?? '',
      sessionDate: (map['sessionDate'] as Timestamp).toDate(),
      sessionTime: map['sessionTime'] ?? '',
      startTime: (map['startTime'] as Timestamp).toDate(),
      endTime: (map['endTime'] as Timestamp).toDate(),
      behaviorObservations: map['behaviorObservations'] ?? '',
      improvements: map['improvements'] ?? '',
      challenges: map['challenges'] ?? '',
      activitiesPerformed: map['activitiesPerformed'] ?? '',
      childEngagement: map['childEngagement'] ?? '',
      emotionalState: map['emotionalState'] ?? '',
      recommendations: map['recommendations'] ?? '',
      nextSessionGoals: map['nextSessionGoals'] ?? '',
      additionalNotes: map['additionalNotes'] ?? '',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
      isUploaded: map['isUploaded'] ?? false,
      parentId: map['parentId'] ?? '',
      parentEmail: map['parentEmail'] ?? '',
    );
  }

  SessionNotes copyWith({
    String? id,
    String? childId,
    String? childName,
    String? therapistId,
    String? therapistName,
    DateTime? sessionDate,
    String? sessionTime,
    DateTime? startTime,
    DateTime? endTime,
    String? behaviorObservations,
    String? improvements,
    String? challenges,
    String? activitiesPerformed,
    String? childEngagement,
    String? emotionalState,
    String? recommendations,
    String? nextSessionGoals,
    String? additionalNotes,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isUploaded,
    String? parentId,
    String? parentEmail,
  }) {
    return SessionNotes(
      id: id ?? this.id,
      childId: childId ?? this.childId,
      childName: childName ?? this.childName,
      therapistId: therapistId ?? this.therapistId,
      therapistName: therapistName ?? this.therapistName,
      sessionDate: sessionDate ?? this.sessionDate,
      sessionTime: sessionTime ?? this.sessionTime,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      behaviorObservations: behaviorObservations ?? this.behaviorObservations,
      improvements: improvements ?? this.improvements,
      challenges: challenges ?? this.challenges,
      activitiesPerformed: activitiesPerformed ?? this.activitiesPerformed,
      childEngagement: childEngagement ?? this.childEngagement,
      emotionalState: emotionalState ?? this.emotionalState,
      recommendations: recommendations ?? this.recommendations,
      nextSessionGoals: nextSessionGoals ?? this.nextSessionGoals,
      additionalNotes: additionalNotes ?? this.additionalNotes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isUploaded: isUploaded ?? this.isUploaded,
      parentId: parentId ?? this.parentId,
      parentEmail: parentEmail ?? this.parentEmail,
    );
  }
}
