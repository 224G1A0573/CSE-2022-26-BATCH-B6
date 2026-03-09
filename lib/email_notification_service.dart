import 'package:http/http.dart' as http;
import 'dart:convert';

class EmailNotificationService {
  static final EmailNotificationService _instance =
      EmailNotificationService._internal();
  factory EmailNotificationService() => _instance;
  EmailNotificationService._internal();

  // EmailJS configuration
  // TODO: Replace with your actual EmailJS service details
  static const String _emailjsServiceId = 'service_26jkwhf';
  static const String _emailjsTemplateId = 'template_sbjorsy';
  static const String _emailjsUserId = 'Ndbu1FAWMt_gPqkHr';
  static const String _emailjsPrivateKey =
      'eWg0Drk-Fq4JkxBbLEcH0'; // Get this from EmailJS Account > API Keys
  // If you switch to Cloud Functions again, set the URL here
  static const String _functionsEmailUrl = '';

  // Send notification to parent about emotion detection activation
  Future<bool> sendEmotionDetectionNotification({
    required String parentEmail,
    required String childName,
    required String childId,
  }) async {
    try {
      // Basic validation to avoid EmailJS 400
      if (parentEmail.isEmpty) {
        print('EmailJS skip: parentEmail empty');
        return false;
      }
      // Direct EmailJS REST call (you enabled non-browser API in EmailJS settings)
      final Map<String, dynamic> payload = {
        'service_id': _emailjsServiceId,
        'template_id': _emailjsTemplateId,
        'user_id': _emailjsUserId,
        'accessToken': _emailjsPrivateKey, // Private key for strict mode
        'template_params': {
          'to_email': parentEmail,
          'child_name': childName,
          'child_id': childId,
          'subject': 'BloomBuddy Safety Monitoring Started for Your Child',
          'message': '''
Dear Parent/Guardian,

This is to inform you that BloomBuddy's safety monitoring has started for your child ($childName).

What this means:
• The app accesses the front camera in the background at intervals to estimate overall emotional state
• Images are processed on-device and immediately discarded; no photos or videos are stored
• Only anonymized emotion summaries are logged for safety insights

If you have questions or wish to opt out, please reply to this email.

Best regards,
BloomBuddy Team
            ''',
        },
      };

      // Print sanitized payload for diagnostics
      try {
        final dbg = Map<String, dynamic>.from(payload);
        dbg['accessToken'] = '***';
        print('EmailJS payload: $dbg');
      } catch (e) {
        print('EmailJS payload debug error: $e');
      }

      final response = await http.post(
        Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      );

      if (response.statusCode == 200) {
        print('EmailJS success: ${response.body}');
        return true;
      } else {
        print('EmailJS failed: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('EmailJS error sending emotion detection notification: $e');
      return false;
    }
  }

  // Send email via Firebase Functions (alternative method)
  Future<bool> sendEmailViaFunctions({
    required String parentEmail,
    required String childName,
    required String childId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_functionsEmailUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'to': parentEmail,
          'subject': 'BloomBuddy Safety Monitoring Started',
          'body': '''
Dear Parent/Guardian,

This is to inform you that BloomBuddy's safety monitoring has started for your child ($childName).

What this means:
• The app accesses the front camera in the background at intervals to estimate overall emotional state
• Images are processed on-device and immediately discarded; no photos or videos are stored
• Only anonymized emotion summaries are logged for safety insights

If you have questions or wish to opt out, please reply to this email.

Best regards,
BloomBuddy Team
            ''',
        }),
      );

      if (response.statusCode == 200) {
        print('Email sent successfully via Firebase Functions');
        return true;
      } else {
        print(
          'Failed to send email via Firebase Functions. Status: ${response.statusCode}',
        );
        return false;
      }
    } catch (e) {
      print('Error sending email via Firebase Functions: $e');
      return false;
    }
  }
}
