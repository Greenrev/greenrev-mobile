import 'package:socket_io_client/socket_io_client.dart' as IO;
// import '../network/api_client.dart';
import '../config/env.dart';
import 'notification_service.dart';
import 'dart:math';

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;

  IO.Socket? socket;

  SocketService._internal();

  void connect(String token) {
    if (socket != null && socket!.connected) return;

    socket = IO.io(Env.apiBaseUrl, <String, dynamic>{
      'transports': ['websocket'],
      'auth': {'token': token},
      'autoConnect': true,
    });

    socket!.onConnect((_) {
      print('Connected to Socket.IO server');
    });

    socket!.on('notification', (data) {
      if (data != null && data is Map<String, dynamic>) {
        final title = data['title']?.toString() ?? 'New Notification';
        final message = data['message']?.toString() ?? '';

        // Trigger local notification
        NotificationService().showNotification(
          id: Random().nextInt(100000),
          title: title,
          body: message,
        );
      }
    });

    socket!.onDisconnect((_) {
      print('Disconnected from Socket.IO server');
    });
  }

  /// Reconnect with a renewed access token (the old one is rejected after it expires).
  void reconnect(String token) {
    disconnect();
    connect(token);
  }

  void disconnect() {
    if (socket != null) {
      socket!.disconnect();
      socket = null;
    }
  }
}
