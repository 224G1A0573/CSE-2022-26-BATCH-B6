import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ParentChatbotService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get personalized child data for context
  Future<Map<String, dynamic>> _getChildContext(String? childId) async {
    if (childId == null) return {};
    
    try {
      final childDoc = await _firestore.collection('users').doc(childId).get();
      if (childDoc.exists) {
        return childDoc.data() ?? {};
      }
    } catch (e) {
      print('Error fetching child context: $e');
    }
    return {};
  }

  // Get parent's linked children
  Future<List<Map<String, dynamic>>> _getLinkedChildren() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    try {
      // Get parent email
      final parentDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!parentDoc.exists) return [];
      
      final parentData = parentDoc.data() ?? {};
      final parentEmail = parentData['email'] ?? user.email;
      if (parentEmail == null) return [];

      // Query children by guardianEmail (matching parent dashboard logic)
      final childrenQuery = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'kid')
          .where('guardianEmail', isEqualTo: parentEmail)
          .get();

      print('🔍 Chatbot: Found ${childrenQuery.docs.length} linked children for parent ${user.uid}');
      
      return childrenQuery.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'uid': doc.id, // Add uid for compatibility
          ...data,
        };
      }).toList();
    } catch (e) {
      print('❌ Error fetching linked children: $e');
      return [];
    }
  }

  // Get child's recent progress/activity
  Future<Map<String, dynamic>> _getChildProgress(String? childId) async {
    if (childId == null) return {};
    
    try {
      // Get recent game reports
      final reportsQuery = await _firestore
          .collection('users')
          .doc(childId)
          .collection('gameReports')
          .orderBy('timestamp', descending: true)
          .limit(5)
          .get();

      final recentReports = reportsQuery.docs.map((doc) => doc.data()).toList();

      // Get AAC analytics
      final aacQuery = await _firestore
          .collection('users')
          .doc(childId)
          .collection('aac_analytics')
          .orderBy('timestamp', descending: true)
          .limit(10)
          .get();

      final aacData = aacQuery.docs.map((doc) => doc.data()).toList();

      return {
        'recentReports': recentReports,
        'aacData': aacData,
      };
    } catch (e) {
      print('Error fetching child progress: $e');
      return {};
    }
  }

  // Process user message and generate response
  Future<String> getResponse(String userMessage, String? selectedChildId) async {
    final user = _auth.currentUser;
    if (user == null) return "I'm sorry, I need you to be logged in to help you.";

    // Normalize the message
    final message = userMessage.toLowerCase().trim();

    // Get context
    final children = await _getLinkedChildren();
    print('🔍 Chatbot: Processing message with ${children.length} children found');
    
    // Determine which child to use
    String? childIdToUse = selectedChildId;
    if (childIdToUse == null && children.isNotEmpty) {
      childIdToUse = children[0]['id'] ?? children[0]['uid'];
    }
    
    print('🔍 Chatbot: Using child ID: $childIdToUse');
    
    final childContext = childIdToUse != null 
        ? await _getChildContext(childIdToUse)
        : {};
    final childProgress = childIdToUse != null
        ? await _getChildProgress(childIdToUse)
        : {};
    
    print('🔍 Chatbot: Child context loaded - Name: ${childContext['name'] ?? childContext['displayName']}, Age: ${childContext['age']}');
    print('🔍 Chatbot: Processing message: "$message"');

    // Greetings - check first, but be very specific
    // Only match if message starts with greeting or is just a greeting
    final trimmedMessage = message.trim();
    final isGreeting = trimmedMessage == 'hi' ||
                      trimmedMessage == 'hello' ||
                      trimmedMessage == 'hey' ||
                      trimmedMessage.startsWith('hi ') ||
                      trimmedMessage.startsWith('hello ') ||
                      trimmedMessage.startsWith('hey ') ||
                      trimmedMessage.contains('good morning') ||
                      trimmedMessage.contains('good afternoon') ||
                      trimmedMessage.contains('good evening');
    
    if (isGreeting) {
      print('✅ Matched: Greeting');
      final childName = childContext['name'] ?? childContext['displayName'] ?? 'your child';
      return "Hello! 👋 I'm here to help you with questions about the app and ${childName}'s progress. What would you like to know?";
    }

    // Child progress questions - check before app features
    if (_matchesAny(message, ['progress', 'how is', 'how are', 'performance', 'doing', 'improving', 'recent activity', 'been doing', 'what is my child', 'show me', 'child doing', 'child performing', 'child progress', 'child improving', 'my child doing', 'my child performing', 'my child progress', 'my child improving'])) {
      print('✅ Matched: Child Progress');
      if (childContext.isEmpty) {
        return "I'd love to tell you about your child's progress, but I need to know which child you're asking about. "
            "You can select a child from your dashboard first!";
      }

      final childName = childContext['name'] ?? childContext['displayName'] ?? 'your child';
      final recentReports = childProgress['recentReports'] as List? ?? [];
      final aacData = childProgress['aacData'] as List? ?? [];

      print('🔍 Progress data - Reports: ${recentReports.length}, AAC: ${aacData.length}');

      if (recentReports.isEmpty && aacData.isEmpty) {
        return "I don't have recent activity data for ${childName} yet. "
            "Once they start using the games and features, I'll be able to share their progress with you! "
            "Encourage them to try the Social Skills game or Talk Builder! 🎮";
      }

      String response = "Here's what I know about ${childName}'s recent activity:\n\n";
      
      if (recentReports.isNotEmpty) {
        response += "🎮 Recent Game Activity:\n";
        response += "• ${recentReports.length} recent game sessions\n";
        response += "• Keep encouraging them to play and learn!\n\n";
      }

      if (aacData.isNotEmpty) {
        response += "💬 Communication Activity:\n";
        response += "• ${aacData.length} communication sessions tracked\n";
        response += "• They're actively using the Talk Builder!\n\n";
      }

      response += "For detailed reports, check the Progress tab in your dashboard! 📊";
      return response;
    }

    // Child information questions - check for specific child info queries
    if (_matchesAny(message, ['tell me about my child', 'tell me about', 'know about my child', 'what do you know about my child', 'what do you know', 'information about my child', 'information about', 'child age', 'my child age', 'what is my child age', 'what is my child', 'child therapist', 'my child therapist', 'who is my child therapist', 'who is my child'])) {
      print('✅ Matched: Child Information');
      if (childContext.isEmpty) {
        return "I'd love to help you with information about your child, but I need to know which child you're asking about. "
            "You can select a child from your dashboard first!";
      }

      final childName = childContext['name'] ?? childContext['displayName'] ?? 'your child';
      final age = childContext['age']?.toString() ?? 'unknown';
      final therapistName = childContext['therapistName'] ?? 'not assigned yet';

      print('🔍 Child info - Name: $childName, Age: $age, Therapist: $therapistName');

      return "Here's what I know about ${childName}:\n\n"
          "👤 Name: ${childName}\n"
          "🎂 Age: ${age}\n"
          "👨‍⚕️ Therapist: ${therapistName}\n\n"
          "Is there something specific you'd like to know about ${childName}?";
    }

    // Therapist questions
    if (_matchesAny(message, ['therapist', 'doctor', 'therapy', 'session', 'contact', 'schedule', 'who is', 'who is my child therapist', 'who is my therapist', 'how do i contact', 'how to contact', 'how do i schedule', 'how to schedule', 'what are therapy sessions', 'therapy sessions'])) {
      print('✅ Matched: Therapist Question');
      if (childContext.isEmpty) {
        return "I'd love to help you with therapist information, but I need to know which child you're asking about. "
            "You can select a child from your dashboard first!";
      }

      final therapistName = childContext['therapistName'] ?? 'not assigned yet';
      final therapistId = childContext['therapistId'];

      if (therapistId == null) {
        return "Your child doesn't have a therapist assigned yet. "
            "You can request a therapist assignment through the app, or contact support for help!";
      }

      if (_matchesAny(message, ['contact', 'how do i contact', 'reach', 'how to contact'])) {
        return "You can contact ${therapistName} by:\n\n"
            "💬 Using the Chat tab in your dashboard\n"
            "📅 Scheduling a session through the Calendar\n"
            "📊 Viewing shared progress reports\n\n"
            "The Chat tab is the easiest way to communicate directly!";
      }

      if (_matchesAny(message, ['schedule', 'book', 'appointment', 'how do i schedule'])) {
        return "To schedule a therapy session:\n\n"
            "📅 Go to the Calendar tab in your dashboard\n"
            "➕ Click to add a new session\n"
            "📝 Fill in the details and coordinate with ${therapistName}\n\n"
            "You can also chat with ${therapistName} to discuss scheduling!";
      }

      return "Your child's therapist is: ${therapistName}\n\n"
          "You can:\n"
          "💬 Chat with them directly from the Chat tab\n"
          "📅 Schedule sessions using the Calendar\n"
          "📊 View shared progress reports\n\n"
          "Is there something specific you'd like to know about therapy sessions?";
    }

    // Help questions
    if (_matchesAny(message, ['help', 'support', 'assistance', 'stuck', 'problem', 'how do i use', 'i need', 'help me', 'i need support', 'what can you help', 'what can you help me with', 'how do i use this app', 'how to use', 'how do i use the app', 'what can you do'])) {
      print('✅ Matched: Help Question');
      return "I'm here to help! Here are some things I can assist with:\n\n"
          "❓ Questions about app features\n"
          "📊 Your child's progress and activity\n"
          "👤 Information about your child\n"
          "👨‍⚕️ Therapist and therapy questions\n"
          "🎮 Game and activity guidance\n\n"
          "Just ask me anything, and I'll do my best to help! 😊";
    }

    // Emergency/Safety questions
    if (_matchesAny(message, ['emergency', 'safety', 'alert', 'distress', 'worried', 'monitoring', 'what should i do', 'what should i do in an emergency', 'how does the safety monitoring work', 'safety monitoring', 'what if my child is in distress', 'child in distress'])) {
      print('✅ Matched: Emergency/Safety Question');
      return "If you have an emergency, please:\n\n"
          "🚨 Call emergency services immediately:\n"
          "   • Police: 100\n"
          "   • Ambulance: 102\n"
          "   • Fire: 101\n"
          "📞 Contact your child's therapist\n"
          "💬 Use the emergency alert feature in the app\n\n"
          "The app also monitors your child's emotions during activities and can send alerts if signs of distress are detected. "
          "For non-emergency concerns, feel free to chat with your therapist through the app!";
    }

    // App features questions - check last, and only if it's clearly about features
    // Don't match generic "what is" unless combined with feature keywords
    final hasFeatureKeyword = _matchesAny(message, ['social skills', 'social', 'aac', 'talk builder', 'communication', 'games', 'game', 'calendar', 'therapy calendar', 'report', 'progress report', 'features', 'feature', 'what games are available', 'what features does the app have', 'how do i view progress reports', 'what is the therapy calendar for', 'how does the aac feature help']);
    final hasWhatIs = message.contains('what is') || message.contains('what does') || message.contains('how does');
    final hasAppContext = _matchesAny(message, ['app', 'feature', 'game', 'social', 'aac', 'calendar', 'report', 'available', 'view progress', 'therapy calendar']);
    
    if (hasFeatureKeyword || (hasWhatIs && hasAppContext)) {
      print('✅ Matched: App Features Question');
      if (_matchesAny(message, ['social skills', 'social'])) {
        return "The Social Skills game helps your child practice:\n\n"
            "🤝 Conversations with virtual peers\n"
            "👁️ Eye contact practice\n"
            "😊 Emotion recognition and mirroring\n"
            "🔄 Turn-taking skills\n\n"
            "It's designed to be fun and engaging while building important social abilities!";
      }
      if (_matchesAny(message, ['aac', 'talk builder', 'communication', 'how does the aac feature help', 'aac feature help', 'how does talk builder work'])) {
        return "The Talk Builder (AAC) is a communication tool that helps your child:\n\n"
            "💬 Build sentences using symbols\n"
            "🗣️ Speak their thoughts with voice output\n"
            "📊 Track communication patterns\n"
            "📈 Show progress over time\n\n"
            "It's especially helpful for non-verbal or limited-verbal children!";
      }
      if (_matchesAny(message, ['games', 'game', 'what games are available', 'games are available', 'available games'])) {
        return "The app includes several fun games:\n\n"
            "👁️ Eyes Game - Meditation and focus exercises\n"
            "🧠 Repeat Game - Memory challenges\n"
            "🎮 Tetris - Classic puzzle fun\n"
            "😊 Emotion Friend - Learn about feelings\n\n"
            "All games are designed to be both fun and educational!";
      }
      if (_matchesAny(message, ['progress', 'report', 'reports', 'view progress', 'how do i view progress'])) {
        return "You can view detailed progress reports showing:\n\n"
            "📊 Game performance and scores\n"
            "💬 AAC communication usage\n"
            "📈 Trends over time\n"
            "🎯 Areas of improvement\n\n"
            "Check the Progress tab in your dashboard for detailed insights!";
      }
      if (_matchesAny(message, ['calendar', 'therapy calendar', 'therapy', 'session', 'what is the therapy calendar for', 'therapy calendar for'])) {
        return "The Therapy Calendar helps you:\n\n"
            "📅 Schedule therapy sessions\n"
            "👨‍⚕️ Coordinate with your therapist\n"
            "📝 Track session history\n"
            "🔔 Get reminders\n\n"
            "Access it from the Calendar tab in your dashboard!";
      }
      return "The app offers many features:\n\n"
          "🎮 Games for learning and fun\n"
          "🤝 Social Skills practice\n"
          "💬 Talk Builder (AAC) for communication\n"
          "📊 Progress tracking and reports\n"
          "📅 Therapy calendar\n"
          "💬 Chat with your therapist\n\n"
          "What specific feature would you like to know more about?";
    }

    // Default response
    print('❌ No match found for message: "$message"');
    return "I understand you're asking about \"${userMessage}\". "
        "I can help you with:\n\n"
        "• Questions about app features\n"
        "• Your child's progress and activity\n"
        "• Information about your child\n"
        "• Therapist and therapy questions\n"
        "• General app guidance\n\n"
        "Could you rephrase your question, or ask about something specific? I'm here to help! 😊";
  }

  // Helper function to check if message matches any keywords
  bool _matchesAny(String message, List<String> keywords) {
    // Clean the message: lowercase, remove punctuation, normalize spaces
    final cleanMessage = message.toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    
    // Split into words
    final messageWords = cleanMessage.split(' ').where((w) => w.isNotEmpty).toSet();
    
    for (final keyword in keywords) {
      final cleanKeyword = keyword.toLowerCase().trim();
      
      // Check if keyword is a phrase (contains space)
      if (cleanKeyword.contains(' ')) {
        // For phrases, check if the message contains the exact phrase
        if (cleanMessage.contains(cleanKeyword)) {
          print('  ✓ Matched phrase: "$keyword" in message: "$message"');
          return true;
        }
      } else {
        // For single words, ONLY check if it's in the word set (exact word match)
        // This prevents substring matches like "hi" matching in "child"
        if (messageWords.contains(cleanKeyword)) {
          print('  ✓ Matched word: "$keyword" in message: "$message"');
          return true;
        }
      }
    }
    return false;
  }
}

