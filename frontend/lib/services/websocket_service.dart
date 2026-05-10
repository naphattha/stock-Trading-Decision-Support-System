import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config/app_config.dart';

class WsEvent {
  final String event;
  final Map<String, dynamic> data;
  const WsEvent({required this.event, required this.data});
}

class WebSocketService {
  WebSocketService._();
  static final WebSocketService instance = WebSocketService._();

  WebSocketChannel? _channel;
  bool _connected = false;

  final _controller = StreamController<WsEvent>.broadcast();
  Stream<WsEvent> get stream => _controller.stream;
  bool get connected => _connected;

  // ── Connect ──────────────────────────────────────────────────────────────────
  void connect() {
    if (_connected) return;
    try {
      _channel = WebSocketChannel.connect(Uri.parse(AppConfig.wsUrl));
      _connected = true;
      _channel!.stream.listen(
        _onMessage,
        onError: (_) => _reconnect(),
        onDone:  ()  => _reconnect(),
      );
      print('[ws] Connected to ${AppConfig.wsUrl}');
    } catch (e) {
      print('[ws] Connect error: $e');
      _reconnect();
    }
  }

  void _onMessage(dynamic raw) {
    try {
      final j = jsonDecode(raw as String) as Map<String, dynamic>;
      _controller.add(WsEvent(
        event: j['event'] as String? ?? '',
        data:  j['data']  as Map<String, dynamic>? ?? {},
      ));
    } catch (_) {}
  }

  void _reconnect() {
    _connected = false;
    _channel = null;
    print('[ws] Reconnecting in 5 s…');
    Future.delayed(const Duration(seconds: 5), connect);
  }

  // Keep-alive ping every 30 s
  void startPing() {
    Timer.periodic(const Duration(seconds: 30), (_) {
      if (_connected) _channel?.sink.add('ping');
    });
  }

  void disconnect() {
    _channel?.sink.close();
    _connected = false;
  }
}
