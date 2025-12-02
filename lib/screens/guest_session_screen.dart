import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/session_service.dart';
import '../models/session.dart';

class GuestSessionScreen extends StatelessWidget {
  const GuestSessionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sessionService = context.watch<SessionService>();
    final session = sessionService.session;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      appBar: AppBar(
        title: const Text('Join Session', style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: const Color(0xFFFFF8F0),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () {
              sessionService.stopSession();
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Status Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: session.state == SessionState.connected
                  ? Colors.green.shade50
                  : Colors.deepPurple.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: session.state == SessionState.connected
                    ? Colors.green.shade200
                    : Colors.deepPurple.shade200,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  session.state == SessionState.connected
                      ? Icons.check_circle_rounded
                      : Icons.wifi_find_rounded,
                  color: session.state == SessionState.connected
                      ? Colors.green.shade700
                      : Colors.deepPurple.shade700,
                ),
                const SizedBox(width: 12),
                Text(
                  session.state == SessionState.connected
                      ? 'Connected!'
                      : 'Looking for friends...',
                  style: TextStyle(
                    color: session.state == SessionState.connected
                        ? Colors.deepPurple.shade900
                        : Colors.deepPurple.shade900,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          
          // Discovery List (if not connected)
          if (session.state == SessionState.discovering || session.state == SessionState.connecting)
            Expanded(
              child: sessionService.discoveredDevices.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_rounded, size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text(
                            'Searching for nearby sessions...',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: sessionService.discoveredDevices.length,
                      itemBuilder: (context, index) {
                        final device = sessionService.discoveredDevices[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            leading: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.deepPurple.shade50,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.person_rounded, color: Colors.deepPurple.shade700),
                            ),
                            title: Text(
                              device.name,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              device.id,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            trailing: FilledButton(
                              onPressed: () => sessionService.joinSession(device.id),
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.deepPurple.shade600,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('Join'),
                            ),
                          ),
                        );
                      },
                    ),
            ),

          // Photo View (if connected)
          if (session.state == SessionState.connected)
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(20),
                ),
                clipBehavior: Clip.antiAlias,
                child: Center(
                  child: sessionService.receivedImageData != null
                      ? Image.memory(
                          sessionService.receivedImageData!,
                          fit: BoxFit.contain,
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(color: Colors.deepPurple.shade600),
                            const SizedBox(height: 16),
                            const Text(
                              'Waiting for photos...',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
