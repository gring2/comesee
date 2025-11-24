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
      appBar: AppBar(
        title: const Text('Guest Session'),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
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
            padding: const EdgeInsets.all(8),
            color: Colors.grey[200],
            child: Row(
              children: [
                Icon(
                  session.state == SessionState.connected
                      ? Icons.link
                      : Icons.link_off,
                  color: session.state == SessionState.connected
                      ? Colors.green
                      : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text('Status: ${session.state.name}'),
              ],
            ),
          ),
          
          // Discovery List (if not connected)
          if (session.state == SessionState.discovering || session.state == SessionState.connecting)
            Expanded(
              child: ListView.builder(
                itemCount: sessionService.discoveredDevices.length,
                itemBuilder: (context, index) {
                  final device = sessionService.discoveredDevices[index];
                  return ListTile(
                    title: Text(device.name),
                    subtitle: Text(device.id),
                    trailing: ElevatedButton(
                      onPressed: () => sessionService.joinSession(device.id),
                      child: const Text('Join'),
                    ),
                  );
                },
              ),
            ),

          // Photo View (if connected)
          if (session.state == SessionState.connected)
            Expanded(
              child: Center(
                child: sessionService.receivedImageData != null
                    ? Image.memory(
                        sessionService.receivedImageData!,
                        fit: BoxFit.contain,
                      )
                    : const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Waiting for photos...'),
                        ],
                      ),
              ),
            ),
        ],
      ),
    );
  }
}
