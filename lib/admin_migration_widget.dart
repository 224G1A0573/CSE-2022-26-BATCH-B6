import 'package:flutter/material.dart';
import 'user_data_migration.dart';

class AdminMigrationWidget extends StatefulWidget {
  const AdminMigrationWidget({super.key});

  @override
  State<AdminMigrationWidget> createState() => _AdminMigrationWidgetState();
}

class _AdminMigrationWidgetState extends State<AdminMigrationWidget> {
  final UserDataMigration _migration = UserDataMigration();
  bool _isMigrating = false;
  String _status = 'Ready to migrate';

  Future<void> _runMigration() async {
    setState(() {
      _isMigrating = true;
      _status = 'Starting migration...';
    });

    try {
      await _migration.migrateAllChildUsers();
      setState(() {
        _status = 'Migration completed successfully!';
      });
    } catch (e) {
      setState(() {
        _status = 'Migration failed: $e';
      });
    } finally {
      setState(() {
        _isMigrating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Migration Tool'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'User Data Migration',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'This tool will automatically add required fields to all child users:',
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '• parentEmail\n• emotionDetectionActive\n• emotionDetectionStartedAt\n• emotionDetectionStoppedAt',
                      style: TextStyle(fontSize: 12, fontFamily: 'monospace'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Status',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _status,
                      style: TextStyle(
                        fontSize: 14,
                        color: _status.contains('failed')
                            ? Colors.red
                            : Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isMigrating ? null : _runMigration,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isMigrating
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        SizedBox(width: 8),
                        Text('Migrating...'),
                      ],
                    )
                  : const Text(
                      'Run Migration for All Child Users',
                      style: TextStyle(fontSize: 16),
                    ),
            ),
            const SizedBox(height: 16),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'How it works:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '1. Finds all users with role "kid"\n'
                      '2. Checks for missing required fields\n'
                      '3. Automatically finds parent email\n'
                      '4. Adds missing fields to each user\n'
                      '5. Logs all changes to console',
                      style: TextStyle(fontSize: 14),
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
}
