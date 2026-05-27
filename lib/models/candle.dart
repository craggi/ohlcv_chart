import '../constants/app_constants.dart';

class Candle {
  Candle({
    required this.openTime,
    required this.closeTime,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
    required this.isClosed,
  });

  final int openTime;
  final int closeTime;
  double open;
  double high;
  double low;
  double close;
  double volume;
  bool isClosed;

  bool get isBullish => close >= open;
  DateTime get openDateTime => DateTime.fromMillisecondsSinceEpoch(openTime);

  factory Candle.fromRestKline(List<dynamic> kline) {
    final closeTime = kline[KlineFieldConstants.restCloseTimeIndex] as int;
    return Candle(
      openTime: kline[KlineFieldConstants.restOpenTimeIndex] as int,
      open: _asDouble(kline[KlineFieldConstants.restOpenIndex]),
      high: _asDouble(kline[KlineFieldConstants.restHighIndex]),
      low: _asDouble(kline[KlineFieldConstants.restLowIndex]),
      close: _asDouble(kline[KlineFieldConstants.restCloseIndex]),
      volume: _asDouble(kline[KlineFieldConstants.restVolumeIndex]),
      closeTime: closeTime,
      isClosed: closeTime < DateTime.now().millisecondsSinceEpoch,
    );
  }

  factory Candle.fromWsKline(Map<String, dynamic> kline) {
    return Candle(
      openTime: kline[KlineFieldConstants.wsOpenTime] as int,
      closeTime: kline[KlineFieldConstants.wsCloseTime] as int,
      open: _asDouble(kline[KlineFieldConstants.wsOpen]),
      high: _asDouble(kline[KlineFieldConstants.wsHigh]),
      low: _asDouble(kline[KlineFieldConstants.wsLow]),
      close: _asDouble(kline[KlineFieldConstants.wsClose]),
      volume: _asDouble(kline[KlineFieldConstants.wsVolume]),
      isClosed: kline[KlineFieldConstants.wsIsClosed] as bool? ?? false,
    );
  }

  void updateFrom(Candle other) {
    open = other.open;
    high = other.high;
    low = other.low;
    close = other.close;
    volume = other.volume;
    isClosed = other.isClosed;
  }

  Candle copy() {
    return Candle(
      openTime: openTime,
      closeTime: closeTime,
      open: open,
      high: high,
      low: low,
      close: close,
      volume: volume,
      isClosed: isClosed,
    );
  }

  static double _asDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.parse(value as String);
  }
}
