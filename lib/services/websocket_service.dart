import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketService {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  final _connectionStateController = StreamController<bool>.broadcast();
  bool _isConnected = false;

  Stream<Map<String, dynamic>> get messages => _messageController.stream;

  Stream<bool> get connectionState => _connectionStateController.stream;
  bool get isConnected => _isConnected;

  Future<void> connect(String serverUrl) async {
    if (_isConnected) disconnect();

    try {
      _channel = WebSocketChannel.connect(Uri.parse(serverUrl));
      await _channel!.ready;
      _setConnected(true);

      _subscription = _channel!.stream.listen(
        _onData,
        onError: _onError,
        onDone: _onDone,
      );
    } catch (e) {
      _setConnected(false);
      _messageController.addError(e);
      rethrow;
    }
  }

  void disconnect() {
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _channel = null;
    _setConnected(false);
  }

  void sendMessage(Map<String, dynamic> msg) {
    if (!_isConnected) return;
    _channel!.sink.add(jsonEncode(msg));
  }

  void _onData(dynamic rawMessage) {
    try {
      final text = rawMessage is String ? rawMessage : utf8.decode(rawMessage as List<int>);
      final decoded = jsonDecode(text);
      if (decoded is Map<String, dynamic>) {
        _messageController.add(decoded);
      }
    } catch (e) {
      _messageController.addError(e);
    }
  }

  void _onError(dynamic error) {
    _messageController.addError(error);
    _setConnected(false);
  }

  void _onDone() {
    _setConnected(false);
  }

  void _setConnected(bool connected) {
    _isConnected = connected;
    _connectionStateController.add(connected);
  }

  void dispose() {
    disconnect();
    _messageController.close();
    _connectionStateController.close();
  }
}
