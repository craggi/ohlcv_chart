import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import '../constants/app_constants.dart';
import '../models/candle.dart';

class BinanceClient {
  BinanceClient({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  Future<List<Candle>> fetchHistory({
    required String symbol,
    required String interval,
    int limit = BinanceConstants.defaultHistoryLimit,
    int? endTime,
  }) async {
    if (limit <= BinanceConstants.maxRestKlineLimit) {
      return fetchHistoryPage(
        symbol: symbol,
        interval: interval,
        limit: limit,
        endTime: endTime,
      );
    }

    final candlesByOpenTime = <int, Candle>{};
    var remaining = limit;
    var pageEndTime = endTime;

    while (remaining > 0) {
      final pageLimit = math.min(remaining, BinanceConstants.maxRestKlineLimit);
      final page = await fetchHistoryPage(
        symbol: symbol,
        interval: interval,
        limit: pageLimit,
        endTime: pageEndTime,
      );

      if (page.isEmpty) {
        break;
      }

      for (final candle in page) {
        candlesByOpenTime[candle.openTime] = candle;
      }

      remaining -= page.length;
      pageEndTime = page.first.openTime - 1;

      if (page.length < pageLimit) {
        break;
      }
    }

    final candles =
        candlesByOpenTime.values.toList()
          ..sort((a, b) => a.openTime.compareTo(b.openTime));
    if (candles.length <= limit) {
      return candles;
    }

    return candles.sublist(candles.length - limit);
  }

  Future<List<Candle>> fetchHistoryPage({
    required String symbol,
    required String interval,
    required int limit,
    int? endTime,
  }) async {
    final query = {
      'symbol': symbol.toUpperCase(),
      'interval': interval,
      'limit': limit.toString(),
      if (endTime != null) 'endTime': endTime.toString(),
    };
    final uri = Uri.https(
      BinanceConstants.restHost,
      BinanceConstants.klinesPath,
      query,
    );

    final response = await _httpClient.get(uri);
    if (response.statusCode != 200) {
      throw BinanceException(
        'History request failed (${response.statusCode}): ${response.body}',
      );
    }

    final json = jsonDecode(response.body) as List<dynamic>;
    return json
        .cast<List<dynamic>>()
        .map(Candle.fromRestKline)
        .toList(growable: true);
  }

  void close() {
    _httpClient.close();
  }
}

class BinanceException implements Exception {
  BinanceException(this.message);

  final String message;

  @override
  String toString() => message;
}
