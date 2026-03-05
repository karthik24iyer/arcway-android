import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketService {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  final _connectionStateController = StreamController<bool>.broadcast();
  final _replayBuffer = <Map<String, dynamic>>[];
  String? _serverUrl;
  bool _isConnected = false;

  Stream<Map<String, dynamic>> get messages => _messageController.stream;

  Stream<Map<String, dynamic>> get messagesWithReplay {
    final controller = StreamController<Map<String, dynamic>>();
    for (final msg in List.of(_replayBuffer)) {
      controller.add(msg);
    }
    final sub = _messageController.stream.listen(
      controller.add,
      onError: controller.addError,
      onDone: controller.close,
    );
    controller.onCancel = () => sub.cancel();
    return controller.stream;
  }

  Stream<bool> get connectionState => _connectionStateController.stream;
  bool get isConnected => _isConnected;
  String? get serverUrl => _serverUrl;

  Future<void> connect(String serverUrl) async {
    if (_isConnected) disconnect();

    _serverUrl = serverUrl;
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
    _replayBuffer.clear();
    _setConnected(false);
  }

  void sendMessage(Map<String, dynamic> msg) {
    if (!_isConnected || _channel == null) return;
    _channel!.sink.add(jsonEncode(msg));
  }

  void _onData(dynamic rawMessage) {
    try {
      final text = rawMessage is String ? rawMessage : utf8.decode(rawMessage as List<int>);
      final decoded = jsonDecode(text);
      if (decoded is Map<String, dynamic>) {
        if (_replayBuffer.length >= 500) _replayBuffer.removeAt(0);
        _replayBuffer.add(decoded);
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
