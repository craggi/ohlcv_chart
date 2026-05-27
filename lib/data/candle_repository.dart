import 'dart:async';

import 'package:flutter/foundation.dart';

import '../constants/app_constants.dart';
import '../models/candle.dart';
import 'binance_client.dart';
import 'binance_stream.dart';

enum ConnectionStateStatus { idle, loading, live, reconnecting, error }

class CandleRepository {
  CandleRepository({
    required BinanceClient client,
    int maxCandles = BinanceConstants.defaultMaxCandles,
  }) : _client = client,
       _maxCandles = maxCandles;

  final BinanceClient _client;
  final int _maxCandles;

  final candles = ValueNotifier<List<Candle>>(<Candle>[]);
  final status = ValueNotifier<ConnectionStateStatus>(
    ConnectionStateStatus.idle,
  );
  final errorMessage = ValueNotifier<String?>(null);

  BinanceStream? _stream;
  StreamSubscription<Candle>? _subscription;
  String _symbol = AppConstants.defaultSymbol;
  String _interval = AppConstants.defaultInterval;
  int _loadGeneration = 0;

  String get symbol => _symbol;
  String get interval => _interval;

  Future<void> start({required String symbol, required String interval}) async {
    final generation = ++_loadGeneration;
    _symbol = symbol;
    _interval = interval;
    status.value = ConnectionStateStatus.loading;
    errorMessage.value = null;

    await _subscription?.cancel();
    await _stream?.close();
    candles.value = <Candle>[];

    _stream = BinanceStream(symbol: symbol, interval: interval);
    _subscription = _stream!.candles.listen(
      _mergeLiveCandle,
      onError: (Object error, StackTrace stackTrace) {
        errorMessage.value = error.toString();
        status.value = ConnectionStateStatus.reconnecting;
      },
    );

    try {
      final initialLimit = _initialHistoryLimit;
      final initialStopwatch = Stopwatch()..start();
      final history = await _client.fetchHistoryPage(
        symbol: symbol,
        interval: interval,
        limit: initialLimit,
      );
      initialStopwatch.stop();
      if (generation != _loadGeneration) {
        return;
      }

      _mergeLiveCandlesIntoHistory(history, candles.value);
      _trim(history);
      candles.value = history;
      status.value = ConnectionStateStatus.live;
      unawaited(_backfillHistory(symbol, interval, generation));
    } catch (error) {
      if (generation != _loadGeneration) {
        return;
      }
      errorMessage.value = error.toString();
      status.value = ConnectionStateStatus.error;
    }
  }

  int get _initialHistoryLimit {
    final maxCandles = _maxCandles;
    if (maxCandles <= 0) {
      return BinanceConstants.initialHistoryLimit;
    }
    return maxCandles < BinanceConstants.initialHistoryLimit
        ? maxCandles
        : BinanceConstants.initialHistoryLimit;
  }

  Future<void> _backfillHistory(
    String symbol,
    String interval,
    int generation,
  ) async {
    await Future<void>.delayed(BinanceConstants.backfillStartDelay);
    if (generation != _loadGeneration) {
      return;
    }

    final totalStopwatch = Stopwatch()..start();
    var pageNumber = 0;
    var lastPublishedPage = 0;
    final pendingOlder = <Candle>[];

    while (generation == _loadGeneration &&
        candles.value.length < _maxCandles) {
      final current = _mergeCandles(pendingOlder, candles.value);
      if (current.isEmpty) {
        return;
      }

      final remaining = _maxCandles - current.length;
      final pageLimit =
          remaining < BinanceConstants.maxRestKlineLimit
              ? remaining
              : BinanceConstants.maxRestKlineLimit;
      final endTime = current.first.openTime - 1;

      try {
        pageNumber++;
        final pageStopwatch = Stopwatch()..start();
        final older = await _client.fetchHistoryPage(
          symbol: symbol,
          interval: interval,
          limit: pageLimit,
          endTime: endTime,
        );
        pageStopwatch.stop();
        if (generation != _loadGeneration || older.isEmpty) {
          return;
        }

        final merged = _mergeCandles(older, current);
        pendingOlder.addAll(older);
        final shouldPublish =
            pageNumber - lastPublishedPage >=
                BinanceConstants.backfillPublishPageInterval ||
            merged.length >= _maxCandles ||
            older.length < pageLimit;
        if (shouldPublish) {
          _trim(merged);
          candles.value = merged;
          pendingOlder.clear();
          lastPublishedPage = pageNumber;
        }

        if (older.length < pageLimit) {
          return;
        }
      } catch (error) {
        if (generation != _loadGeneration) {
          return;
        }
        errorMessage.value = error.toString();
        _logBenchmark(
          'History backfill failed '
          'page=$pageNumber current=${candles.value.length} '
          'totalLatency=${totalStopwatch.elapsedMilliseconds}ms '
          'error=$error',
        );
        return;
      }
    }

    _logBenchmark(
      'History backfill completed '
      'pages=$pageNumber total=${candles.value.length} '
      'totalLatency=${totalStopwatch.elapsedMilliseconds}ms',
    );
  }

  void _mergeLiveCandlesIntoHistory(List<Candle> history, List<Candle> live) {
    for (final candle in live) {
      _mergeCandle(history, candle);
    }
    history.sort((a, b) => a.openTime.compareTo(b.openTime));
  }

  List<Candle> _mergeCandles(List<Candle> older, List<Candle> current) {
    final candlesByOpenTime = <int, Candle>{};
    for (final candle in older) {
      candlesByOpenTime[candle.openTime] = candle.copy();
    }
    for (final candle in current) {
      candlesByOpenTime[candle.openTime] = candle.copy();
    }
    return candlesByOpenTime.values.toList()
      ..sort((a, b) => a.openTime.compareTo(b.openTime));
  }

  void _mergeLiveCandle(Candle incoming) {
    final current = List<Candle>.of(candles.value, growable: true);
    _mergeCandle(current, incoming);

    _trim(current);
    candles.value = current;
    if (status.value != ConnectionStateStatus.live) {
      status.value = ConnectionStateStatus.live;
    }
  }

  void _mergeCandle(List<Candle> current, Candle incoming) {
    if (current.isEmpty) {
      current.add(incoming.copy());
      return;
    }

    final last = current.last;
    if (last.openTime == incoming.openTime) {
      last.updateFrom(incoming);
      return;
    }

    if (incoming.openTime > last.openTime) {
      current.add(incoming.copy());
      return;
    }

    final index = current.indexWhere(
      (candle) => candle.openTime == incoming.openTime,
    );
    if (index != -1) {
      current[index].updateFrom(incoming);
    }
  }

  void _trim(List<Candle> current) {
    final extra = current.length - _maxCandles;
    if (extra > 0) {
      current.removeRange(0, extra);
    }
  }

  void _logBenchmark(String message) {
    if (kDebugMode || kProfileMode) {
      debugPrint('[CandleRepository] $message');
    }
  }

  Future<void> dispose() async {
    _loadGeneration++;
    await _subscription?.cancel();
    await _stream?.close();
    _client.close();
    candles.dispose();
    status.dispose();
    errorMessage.dispose();
  }
}
