import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/session_notes.dart';
import '../services/session_service.dart';

class MonthlyTherapyCalendar extends StatefulWidget {
  final String childId;
  final String childName;
  final String userRole; // 'therapist' or 'parent'
  final String? therapistId;
  final String? therapistName;

  const MonthlyTherapyCalendar({
    super.key,
    required this.childId,
    required this.childName,
    required this.userRole,
    this.therapistId,
    this.therapistName,
  });

  @override
  State<MonthlyTherapyCalendar> createState() => _MonthlyTherapyCalendarState();
}

class _MonthlyTherapyCalendarState extends State<MonthlyTherapyCalendar> {
  DateTime _currentMonth = DateTime.now();
  Map<DateTime, SessionNotes?> _monthlySchedule = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMonthlySchedule();
    _debugCurrentUser();
  }

  void _debugCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    print('DEBUG: Current user: ${user?.uid}');
    print('DEBUG: Current user email: ${user?.email}');

    // Also check if this user matches any session notes
    if (widget.userRole == 'parent') {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('sessionNotes')
          .where('parentId', isEqualTo: user?.uid)
          .get();
      print(
        'DEBUG: Found ${querySnapshot.docs.length} session notes for current parent user',
      );
    }
  }

  Future<void> _loadMonthlySchedule() async {
    setState(() => _isLoading = true);
    try {
      final schedule = <DateTime, SessionNotes?>{};

      // Get first day of month
      final firstDay = DateTime(_currentMonth.year, _currentMonth.month, 1);
      // Get last day of month
      final lastDay = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);

      // Get all session notes for this month in one query
      final startOfMonth = DateTime(_currentMonth.year, _currentMonth.month, 1);
      final endOfMonth = DateTime(
        _currentMonth.year,
        _currentMonth.month + 1,
        0,
        23,
        59,
        59,
      );

      try {
        print('DEBUG: Loading monthly schedule for child ${widget.childId}');
        print('DEBUG: User role: ${widget.userRole}');
        print('DEBUG: Therapist ID: ${widget.therapistId}');
        print('DEBUG: Month range: $startOfMonth to $endOfMonth');

        final querySnapshot = await FirebaseFirestore.instance
            .collection('sessionNotes')
            .where('childId', isEqualTo: widget.childId)
            .where(
              'sessionDate',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth),
            )
            .where(
              'sessionDate',
              isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth),
            )
            .get();

        print(
          'DEBUG: Found ${querySnapshot.docs.length} session notes for the month',
        );

        // Create a map of date to session note
        final sessionNotesMap = <DateTime, SessionNotes>{};
        for (final doc in querySnapshot.docs) {
          final sessionNote = SessionNotes.fromMap(doc.data());
          final date = DateTime(
            sessionNote.sessionDate.year,
            sessionNote.sessionDate.month,
            sessionNote.sessionDate.day,
          );
          sessionNotesMap[date] = sessionNote;
          print('DEBUG: Session note for date $date: ${sessionNote.id}');
          print('DEBUG: - isUploaded: ${sessionNote.isUploaded}');
          print('DEBUG: - therapistId: ${sessionNote.therapistId}');
          print('DEBUG: - parentId: ${sessionNote.parentId}');
        }

        // Fill the schedule for all days of the month
        for (int i = 0; i < lastDay.day; i++) {
          final date = firstDay.add(Duration(days: i));
          schedule[date] = sessionNotesMap[date];
        }

        print('DEBUG: Schedule loaded with ${schedule.length} days');
      } catch (e) {
        // If query fails, try individual date queries
        for (int i = 0; i < lastDay.day; i++) {
          final date = firstDay.add(Duration(days: i));
          try {
            final sessionNote = await SessionService.getSessionNoteForDate(
              widget.childId,
              date,
            );
            schedule[date] = sessionNote;
          } catch (e) {
            // If permission denied, just skip this date
            schedule[date] = null;
          }
        }
      }

      setState(() {
        _monthlySchedule = schedule;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading schedule: $e')));
    }
  }

  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
    });
    _loadMonthlySchedule();
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
    });
    _loadMonthlySchedule();
  }

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDay = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    final firstWeekday = firstDay.weekday;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.childName}\'s Therapy Calendar'),
        backgroundColor: const Color(0xFF6B73FF),
        foregroundColor: Colors.white,
        actions: [
          if (widget.userRole == 'therapist')
            IconButton(
              icon: const Icon(Icons.upload),
              onPressed: _showUploadDialog,
              tooltip: 'Upload Session Notes',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMonthlySchedule,
          ),
          IconButton(
            icon: const Icon(Icons.bug_report),
            onPressed: () {
              SessionService.debugSessionNotes(widget.childId);
              _debugCurrentUser();
              if (widget.userRole == 'parent') {
                SessionService.debugParentSessionNotes();
                SessionService.debugAllSessionNotes();
              }
            },
            tooltip: 'Debug Session Notes',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Month navigation
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: _previousMonth,
                      ),
                      Text(
                        '${_getMonthName(_currentMonth.month)} ${_currentMonth.year}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: _nextMonth,
                      ),
                    ],
                  ),
                ),

                // Calendar grid
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        // Day headers (Sun, Mon, Tue, Wed, Thu, Fri, Sat)
                        Row(
                          children:
                              ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
                                  .map(
                                    (day) => Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(
                                            0xFF6B73FF,
                                          ).withOpacity(0.1),
                                          border: Border.all(
                                            color: const Color(
                                              0xFF6B73FF,
                                            ).withOpacity(0.3),
                                          ),
                                        ),
                                        child: Text(
                                          day,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF6B73FF),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                        ),

                        // Calendar days
                        Expanded(
                          child: GridView.builder(
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 7,
                                  childAspectRatio: 1.0,
                                ),
                            itemCount: 42, // 6 weeks * 7 days
                            itemBuilder: (context, index) {
                              final dayNumber = index - firstWeekday + 1;
                              final date = DateTime(
                                _currentMonth.year,
                                _currentMonth.month,
                                dayNumber,
                              );
                              final sessionNote = _monthlySchedule[date];

                              // Check if this date is in the current month
                              final isCurrentMonth =
                                  dayNumber >= 1 && dayNumber <= lastDay.day;

                              return GestureDetector(
                                onTap: () {
                                  if (isCurrentMonth) {
                                    _onDateTap(date, sessionNote);
                                  }
                                },
                                child: Container(
                                  margin: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: _getDateColor(
                                      date,
                                      sessionNote,
                                      isCurrentMonth,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: _getDateBorderColor(
                                        date,
                                        sessionNote,
                                        isCurrentMonth,
                                      ),
                                      width: 1,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        isCurrentMonth ? '$dayNumber' : '',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: _getDateTextColor(
                                            date,
                                            sessionNote,
                                            isCurrentMonth,
                                          ),
                                        ),
                                      ),
                                      if (isCurrentMonth &&
                                          sessionNote != null) ...[
                                        const SizedBox(height: 2),
                                        Icon(
                                          widget.userRole == 'therapist'
                                              ? Icons.edit
                                              : Icons.visibility,
                                          size: 12,
                                          color: _getDateTextColor(
                                            date,
                                            sessionNote,
                                            isCurrentMonth,
                                          ),
                                        ),
                                        Text(
                                          sessionNote.sessionTime,
                                          style: TextStyle(
                                            fontSize: 8,
                                            color: _getDateTextColor(
                                              date,
                                              sessionNote,
                                              isCurrentMonth,
                                            ),
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ] else if (isCurrentMonth &&
                                          _isToday(date)) ...[
                                        const SizedBox(height: 2),
                                        Icon(
                                          Icons.add,
                                          size: 12,
                                          color: _getDateTextColor(
                                            date,
                                            sessionNote,
                                            isCurrentMonth,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Legend
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildLegendItem('Today', Colors.orange),
                      _buildLegendItem('Session', Colors.green),
                      _buildLegendItem('No Session', Colors.grey),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color.withOpacity(0.3),
            border: Border.all(color: color),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Color _getDateColor(
    DateTime date,
    SessionNotes? sessionNote,
    bool isCurrentMonth,
  ) {
    if (!isCurrentMonth) {
      return Colors.grey.withOpacity(0.1);
    }
    if (_isToday(date)) {
      return Colors.orange.withOpacity(0.2);
    } else if (sessionNote != null) {
      return Colors.green.withOpacity(0.2);
    } else {
      return Colors.grey.withOpacity(0.1);
    }
  }

  Color _getDateBorderColor(
    DateTime date,
    SessionNotes? sessionNote,
    bool isCurrentMonth,
  ) {
    if (!isCurrentMonth) {
      return Colors.grey.withOpacity(0.1);
    }
    if (_isToday(date)) {
      return Colors.orange;
    } else if (sessionNote != null) {
      return Colors.green;
    } else {
      return Colors.grey.withOpacity(0.3);
    }
  }

  Color _getDateTextColor(
    DateTime date,
    SessionNotes? sessionNote,
    bool isCurrentMonth,
  ) {
    if (!isCurrentMonth) {
      return Colors.grey.withOpacity(0.3);
    }
    if (_isToday(date)) {
      return Colors.orange.shade800;
    } else if (sessionNote != null) {
      return Colors.green.shade800;
    } else {
      return Colors.grey.shade600;
    }
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  String _getMonthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month - 1];
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Unknown date';
    return '${date.day}/${date.month}/${date.year}';
  }

  void _onDateTap(DateTime date, SessionNotes? sessionNote) {
    if (widget.userRole == 'therapist') {
      _showTherapistSessionDialog(date, sessionNote);
    } else {
      _showParentSessionDialog(date, sessionNote);
    }
  }

  void _showUploadDialog() {
    // Get all session notes for this month that are not uploaded
    final unuploadedNotes = _monthlySchedule.values
        .where((note) => note != null && !note!.isUploaded)
        .cast<SessionNotes>()
        .toList();

    print(
      'DEBUG: Upload dialog - Found ${unuploadedNotes.length} unuploaded notes',
    );
    for (final note in unuploadedNotes) {
      print('DEBUG: Unuploaded note: ${note.id} for date ${note.sessionDate}');
    }

    if (unuploadedNotes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No session notes to upload'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Upload Session Notes'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Upload ${unuploadedNotes.length} session note(s) to parent?'),
            const SizedBox(height: 16),
            ...unuploadedNotes.map(
              (note) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${_formatDate(note?.sessionDate)} - ${note?.sessionTime}',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _uploadSessionNotes(unuploadedNotes);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6B73FF),
              foregroundColor: Colors.white,
            ),
            child: const Text('Upload'),
          ),
        ],
      ),
    );
  }

  Future<void> _uploadSessionNotes(List<SessionNotes> notes) async {
    try {
      for (final note in notes) {
        await SessionService.uploadSessionNote(note.id);
      }

      _loadMonthlySchedule();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Successfully uploaded ${notes.length} session note(s)',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error uploading session notes: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showTherapistSessionDialog(DateTime date, SessionNotes? sessionNote) {
    showDialog(
      context: context,
      builder: (context) => SessionNotesDialog(
        childId: widget.childId,
        childName: widget.childName,
        therapistId: widget.therapistId!,
        therapistName: widget.therapistName!,
        sessionDate: date,
        existingNote: sessionNote,
        onSave: () {
          Navigator.pop(context);
          _loadMonthlySchedule();
        },
      ),
    );
  }

  void _showParentSessionDialog(DateTime date, SessionNotes? sessionNote) {
    if (sessionNote == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No session notes available for this date'),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => SessionNotesViewDialog(sessionNote: sessionNote),
    );
  }
}

// Import the existing dialog classes
class SessionNotesDialog extends StatefulWidget {
  final String childId;
  final String childName;
  final String therapistId;
  final String therapistName;
  final DateTime sessionDate;
  final SessionNotes? existingNote;
  final VoidCallback onSave;

  const SessionNotesDialog({
    super.key,
    required this.childId,
    required this.childName,
    required this.therapistId,
    required this.therapistName,
    required this.sessionDate,
    this.existingNote,
    required this.onSave,
  });

  @override
  State<SessionNotesDialog> createState() => _SessionNotesDialogState();
}

class _SessionNotesDialogState extends State<SessionNotesDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _startTimeController;
  late TextEditingController _endTimeController;
  late TextEditingController _behaviorObservationsController;
  late TextEditingController _improvementsController;
  late TextEditingController _challengesController;
  late TextEditingController _activitiesPerformedController;
  late TextEditingController _childEngagementController;
  late TextEditingController _emotionalStateController;
  late TextEditingController _recommendationsController;
  late TextEditingController _nextSessionGoalsController;
  late TextEditingController _additionalNotesController;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    // Initialize controllers with existing data or defaults
    final existing = widget.existingNote;
    _startTimeController = TextEditingController(
      text: existing?.sessionTime.split('-')[0] ?? '09:00',
    );
    _endTimeController = TextEditingController(
      text: existing?.sessionTime.split('-')[1] ?? '11:00',
    );
    _behaviorObservationsController = TextEditingController(
      text: existing?.behaviorObservations ?? '',
    );
    _improvementsController = TextEditingController(
      text: existing?.improvements ?? '',
    );
    _challengesController = TextEditingController(
      text: existing?.challenges ?? '',
    );
    _activitiesPerformedController = TextEditingController(
      text: existing?.activitiesPerformed ?? '',
    );
    _childEngagementController = TextEditingController(
      text: existing?.childEngagement ?? '',
    );
    _emotionalStateController = TextEditingController(
      text: existing?.emotionalState ?? '',
    );
    _recommendationsController = TextEditingController(
      text: existing?.recommendations ?? '',
    );
    _nextSessionGoalsController = TextEditingController(
      text: existing?.nextSessionGoals ?? '',
    );
    _additionalNotesController = TextEditingController(
      text: existing?.additionalNotes ?? '',
    );
  }

  @override
  void dispose() {
    _startTimeController.dispose();
    _endTimeController.dispose();
    _behaviorObservationsController.dispose();
    _improvementsController.dispose();
    _challengesController.dispose();
    _activitiesPerformedController.dispose();
    _childEngagementController.dispose();
    _emotionalStateController.dispose();
    _recommendationsController.dispose();
    _nextSessionGoalsController.dispose();
    _additionalNotesController.dispose();
    super.dispose();
  }

  Future<void> _saveSessionNote() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Get parent information
      final childInfo = await SessionService.getChildInfo(widget.childId);
      if (childInfo == null) {
        throw Exception('Child information not found');
      }

      final parentEmail =
          childInfo['guardianEmail'] ?? childInfo['parentEmail'];
      if (parentEmail == null) {
        throw Exception('Parent email not found for child');
      }

      print('DEBUG: Parent email from child info: $parentEmail');

      // Find parent ID
      final parentQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'parent')
          .where('email', isEqualTo: parentEmail)
          .get();

      print(
        'DEBUG: Found ${parentQuery.docs.length} parents with email $parentEmail',
      );

      if (parentQuery.docs.isEmpty) {
        throw Exception('Parent not found');
      }

      final parentId = parentQuery.docs.first.id;
      print('DEBUG: Parent ID: $parentId');

      // Create session times
      final startTime = DateTime(
        widget.sessionDate.year,
        widget.sessionDate.month,
        widget.sessionDate.day,
        int.parse(_startTimeController.text.split(':')[0]),
        int.parse(_startTimeController.text.split(':')[1]),
      );

      final endTime = DateTime(
        widget.sessionDate.year,
        widget.sessionDate.month,
        widget.sessionDate.day,
        int.parse(_endTimeController.text.split(':')[0]),
        int.parse(_endTimeController.text.split(':')[1]),
      );

      final sessionNote = SessionNotes(
        id: widget.existingNote?.id ?? '',
        childId: widget.childId,
        childName: widget.childName,
        therapistId: widget.therapistId,
        therapistName: widget.therapistName,
        sessionDate: widget.sessionDate,
        sessionTime: '${_startTimeController.text}-${_endTimeController.text}',
        startTime: startTime,
        endTime: endTime,
        behaviorObservations: _behaviorObservationsController.text,
        improvements: _improvementsController.text,
        challenges: _challengesController.text,
        activitiesPerformed: _activitiesPerformedController.text,
        childEngagement: _childEngagementController.text,
        emotionalState: _emotionalStateController.text,
        recommendations: _recommendationsController.text,
        nextSessionGoals: _nextSessionGoalsController.text,
        additionalNotes: _additionalNotesController.text,
        createdAt: widget.existingNote?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        isUploaded: false,
        parentId: parentId,
        parentEmail: parentEmail,
      );

      if (widget.existingNote != null) {
        await SessionService.updateSessionNote(
          widget.existingNote!.id,
          sessionNote,
        );
      } else {
        await SessionService.createSessionNote(sessionNote);
      }

      widget.onSave();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session notes saved successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error saving session notes: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Session Notes - ${_formatDate(widget.sessionDate)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Session time
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _startTimeController,
                              decoration: const InputDecoration(
                                labelText: 'Start Time',
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter start time';
                                }
                                if (!RegExp(
                                  r'^([0-1]?[0-9]|2[0-3]):[0-5][0-9]$',
                                ).hasMatch(value)) {
                                  return 'Please enter time in HH:MM format';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _endTimeController,
                              decoration: const InputDecoration(
                                labelText: 'End Time',
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter end time';
                                }
                                if (!RegExp(
                                  r'^([0-1]?[0-9]|2[0-3]):[0-5][0-9]$',
                                ).hasMatch(value)) {
                                  return 'Please enter time in HH:MM format';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Behavior observations
                      TextFormField(
                        controller: _behaviorObservationsController,
                        decoration: const InputDecoration(
                          labelText: 'Behavior Observations *',
                          hintText:
                              'Describe the child\'s behavior during the session',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter behavior observations';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Improvements
                      TextFormField(
                        controller: _improvementsController,
                        decoration: const InputDecoration(
                          labelText: 'Improvements *',
                          hintText: 'Note any improvements observed',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter improvements';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Challenges
                      TextFormField(
                        controller: _challengesController,
                        decoration: const InputDecoration(
                          labelText: 'Challenges *',
                          hintText: 'Describe any challenges faced',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter challenges';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Activities performed
                      TextFormField(
                        controller: _activitiesPerformedController,
                        decoration: const InputDecoration(
                          labelText: 'Activities Performed *',
                          hintText: 'List the activities and exercises done',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter activities performed';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Child engagement
                      TextFormField(
                        controller: _childEngagementController,
                        decoration: const InputDecoration(
                          labelText: 'Child Engagement *',
                          hintText:
                              'Rate and describe child\'s engagement level',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 2,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter child engagement';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Emotional state
                      TextFormField(
                        controller: _emotionalStateController,
                        decoration: const InputDecoration(
                          labelText: 'Emotional State *',
                          hintText: 'Describe the child\'s emotional state',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 2,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter emotional state';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Recommendations
                      TextFormField(
                        controller: _recommendationsController,
                        decoration: const InputDecoration(
                          labelText: 'Recommendations *',
                          hintText: 'Provide recommendations for parents',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter recommendations';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Next session goals
                      TextFormField(
                        controller: _nextSessionGoalsController,
                        decoration: const InputDecoration(
                          labelText: 'Next Session Goals *',
                          hintText: 'Set goals for the next session',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 2,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter next session goals';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Additional notes
                      TextFormField(
                        controller: _additionalNotesController,
                        decoration: const InputDecoration(
                          labelText: 'Additional Notes',
                          hintText: 'Any additional observations or notes',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: _isLoading
                          ? null
                          : () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _saveSessionNote,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6B73FF),
                        foregroundColor: Colors.white,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Text('Save Notes'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Unknown date';
    return '${date.day}/${date.month}/${date.year}';
  }
}

// Dialog for parents to view session notes
class SessionNotesViewDialog extends StatelessWidget {
  final SessionNotes sessionNote;

  const SessionNotesViewDialog({super.key, required this.sessionNote});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Session Notes - ${_formatDate(sessionNote.sessionDate)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow('Session Time', sessionNote.sessionTime),
                    _buildInfoRow('Therapist', sessionNote.therapistName),
                    const SizedBox(height: 16),
                    _buildSection(
                      'Behavior Observations',
                      sessionNote.behaviorObservations,
                    ),
                    _buildSection('Improvements', sessionNote.improvements),
                    _buildSection('Challenges', sessionNote.challenges),
                    _buildSection(
                      'Activities Performed',
                      sessionNote.activitiesPerformed,
                    ),
                    _buildSection(
                      'Child Engagement',
                      sessionNote.childEngagement,
                    ),
                    _buildSection(
                      'Emotional State',
                      sessionNote.emotionalState,
                    ),
                    _buildSection(
                      'Recommendations',
                      sessionNote.recommendations,
                    ),
                    _buildSection(
                      'Next Session Goals',
                      sessionNote.nextSessionGoals,
                    ),
                    if (sessionNote.additionalNotes.isNotEmpty)
                      _buildSection(
                        'Additional Notes',
                        sessionNote.additionalNotes,
                      ),
                    const SizedBox(height: 16),
                    _buildInfoRow(
                      'Last Updated',
                      _formatDateTime(sessionNote.updatedAt),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.black87)),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF6B73FF),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Text(content, style: const TextStyle(color: Colors.black87)),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Unknown date';
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return 'Unknown time';
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
