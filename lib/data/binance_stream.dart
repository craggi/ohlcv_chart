import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../constants/app_constants.dart';
import '../models/candle.dart';

class BinanceStream {
  BinanceStream({
    required this.symbol,
    required this.interval,
    this.reconnectMin = BinanceConstants.reconnectMin,
    this.reconnectMax = BinanceConstants.reconnectMax,
  });

  final String symbol;
  final String interval;
  final Duration reconnectMin;
  final Duration reconnectMax;

  final _controller = StreamController<Candle>.broadcast();
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _reconnectTimer;
  bool _closed = false;
  bool _reconnectScheduled = false;
  int _connectionId = 0;
  Duration _nextDelay = BinanceConstants.reconnectMin;

  Stream<Candle> get candles {
    if (_channel == null && !_closed) {
      _connect();
    }
    return _controller.stream;
  }

  void _connect() {
    if (_closed) {
      return;
    }

    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectScheduled = false;
    final connectionId = ++_connectionId;
    final streamName =
        '${symbol.toLowerCase()}${BinanceConstants.wsStreamNameTemplate}$interval';
    final uri = Uri.parse('${BinanceConstants.wsBaseUrl}/$streamName');

    final channel = WebSocketChannel.connect(uri);
    _channel = channel;
    _subscription = channel.stream.listen(
      _handleMessage,
      onError:
          (Object error, StackTrace stackTrace) => _handleDisconnect(
            error: error,
            stackTrace: stackTrace,
            connectionId: connectionId,
          ),
      onDone: () => _handleDisconnect(connectionId: connectionId),
      cancelOnError: true,
    );

    channel.ready
        .then((_) {
          if (_closed || connectionId != _connectionId) {
            return;
          }
          _nextDelay = reconnectMin;
        })
        .catchError((Object error, StackTrace stackTrace) {
          _handleDisconnect(
            error: error,
            stackTrace: stackTrace,
            connectionId: connectionId,
          );
        });
  }

  void _handleMessage(dynamic message) {
    final decoded = jsonDecode(message as String) as Map<String, dynamic>;
    final kline =
        decoded[BinanceConstants.wsKlineEventKey] as Map<String, dynamic>?;
    if (kline == null) {
      return;
    }
    _controller.add(Candle.fromWsKline(kline));
  }

  void _handleDisconnect({
    Object? error,
    StackTrace? stackTrace,
    int? connectionId,
  }) {
    if (connectionId != null && connectionId != _connectionId) {
      return;
    }

    _subscription?.cancel();
    _subscription = null;
    _channel = null;

    if (_closed) {
      return;
    }

    if (error != null && !_controller.isClosed && _controller.hasListener) {
      _controller.addError(error, stackTrace);
    }

    if (_reconnectScheduled) {
      return;
    }

    _reconnectScheduled = true;
    final delay = _nextDelay;
    final doubledMs =
        _nextDelay.inMilliseconds * BinanceConstants.reconnectBackoffMultiplier;
    _nextDelay = Duration(
      milliseconds:
          doubledMs > reconnectMax.inMilliseconds
              ? reconnectMax.inMilliseconds
              : doubledMs,
    );

    _reconnectTimer = Timer(delay, () {
      _reconnectScheduled = false;
      if (!_closed) {
        _connect();
      }
    });
  }

  Future<void> close() async {
    _closed = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _subscription?.cancel();
    await _channel?.sink.close();
    await _controller.close();
  }
}
