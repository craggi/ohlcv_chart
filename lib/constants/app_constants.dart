import 'package:flutter/material.dart';

/// Application-wide configuration and UI constants.
abstract final class AppConstants {
  static const appTitle = 'Trad/. Chart';
  static const brandTitle = 'Trad/. ';

  static const seedColor = Color(0xFF1FC77E);
  static const chartBorderColor = Color(0xFFE2E8F0);

  static const headerPadding = EdgeInsets.fromLTRB(16, 12, 16, 8);
  static const chartPadding = EdgeInsets.fromLTRB(12, 12, 12, 12);
  static const chartBorderRadius = 16.0;
  static const brandTitleFontSize = 22.0;
  static const headerSpacing = 18.0;

  static const statusPillHorizontalPadding = 10.0;
  static const statusPillVerticalPadding = 6.0;
  static const statusDotSize = 7.0;
  static const statusDotSpacing = 8.0;
  static const statusPillBorderRadius = 999.0;
  static const statusPillBackgroundAlpha = 0.14;
  static const statusPillBorderAlpha = 0.7;

  static const defaultSymbol = 'BTCUSDT';
  static const defaultInterval = '1m';
}

/// Trading symbols and intervals exposed in the UI.
abstract final class MarketConstants {
  static const symbols = ['BTCUSDT', 'ETHUSDT', 'BNBUSDT'];
  static const intervals = ['1m', '5m', '15m', '1h'];
}

/// Binance REST and WebSocket API configuration.
abstract final class BinanceConstants {
  static const restHost = 'api.binance.com';
  static const klinesPath = '/api/v3/klines';
  static const wsBaseUrl = 'wss://stream.binance.com:9443/ws';

  static const maxRestKlineLimit = 1000;
  static const initialHistoryLimit = 170;
  static const backfillStartDelay = Duration(milliseconds: 500);
  static const backfillPublishPageInterval = 2;
  static const defaultHistoryLimit = int.fromEnvironment(
    'BENCHMARK_CANDLE_LIMIT',
    defaultValue: 5000,
  );
  static const defaultMaxCandles = int.fromEnvironment(
    'BENCHMARK_MAX_CANDLES',
    defaultValue: defaultHistoryLimit,
  );

  static const reconnectMin = Duration(seconds: 1);
  static const reconnectMax = Duration(seconds: 20);
  static const reconnectBackoffMultiplier = 2;

  static const wsKlineEventKey = 'k';
  static const wsStreamNameTemplate = '@kline_';
}

/// Binance kline REST array indices and WebSocket field keys.
abstract final class KlineFieldConstants {
  static const restOpenTimeIndex = 0;
  static const restOpenIndex = 1;
  static const restHighIndex = 2;
  static const restLowIndex = 3;
  static const restCloseIndex = 4;
  static const restVolumeIndex = 5;
  static const restCloseTimeIndex = 6;

  static const wsOpenTime = 't';
  static const wsCloseTime = 'T';
  static const wsOpen = 'o';
  static const wsHigh = 'h';
  static const wsLow = 'l';
  static const wsClose = 'c';
  static const wsVolume = 'v';
  static const wsIsClosed = 'x';
}

/// Chart viewport, zoom, and pan behavior.
abstract final class ChartViewportConstants {
  static const defaultVisibleCount = 150.0;
  static const defaultRightOffset = 0.0;
  static const minVisibleCount = 3.0;
  static const maxVisibleCount = 1000.0;
  static const realtimeEdgeThreshold = 0.01;
  static const minScrollOffsetCandles = 10.0;

  static const wheelZoomInFactor = 1.12;
  static const wheelZoomOutFactor = 0.88;
  static const pinchZoomThreshold = 0.003;
  static const initialScale = 1.0;
  static const crosshairMoveThresholdPx = 1.0;
}

/// Chart layout, drawing, and interaction constants.
abstract final class ChartLayoutConstants {
  static const priceAxisWidth = 72.0;
  static const timeAxisHeight = 24.0;
  static const volumePaneRatio = 0.24;
  static const candleBodyWidthRatio = 0.7;
  static const minCandleBodyWidth = 1.0;

  static const gridRows = 10;
  static const verticalGridStridePx = 64.0;
  static const timeLabelStridePx = 76.0;
  static const timeLabelMaxOffset = 28.0;
  static const timeLabelXOffset = 16.0;
  static const timeLabelYOffset = 6.0;
  static const priceLabelXOffset = 8.0;
  static const priceLabelYOffset = 6.0;
  static const crosshairLabelXOffset = 18.0;
  static const crosshairLabelMaxRight = 44.0;

  static const priceRangePaddingRatio = 0.08;
  static const flatRangePadding = 1.0;

  static const priceFormatThresholdHigh = 1000.0;
  static const priceFormatThresholdLow = 1.0;
  static const priceDecimalsHigh = 0;
  static const priceDecimalsMid = 2;
  static const priceDecimalsLow = 6;

  static const realtimeButtonRight = 84.0;
  static const realtimeButtonBottom = 32.0;
  static const realtimeButtonLabel = 'Realtime';

  static const loadingMessage = 'Loading market data...';
  static const waitingMessage = 'Waiting for candles...';
}

/// Chart color palette.
abstract final class ChartColors {
  static const background = Color(0xFFFFFFFF);
  static const grid = Color(0xFFE5EAF0);
  static const bull = Color(0xFF16A34A);
  static const bear = Color(0xFFDC2626);
  static const volumeBull = Color(0x3316A34A);
  static const volumeBear = Color(0x33DC2626);
  static const crosshair = Color(0x9964758B);
  static const axisBackground = Color(0xFFF8FAFC);
  static const label = Color(0xFF64748B);
  static const priceLabel = Color(0xFF334155);
  static const dropdownBackground = Color(0xFFFFFFFF);

  static const strokeWidth = 1.0;
  static const labelFontSize = 11.0;
  static const labelLineHeight = 1.0;
}

/// Connection status labels and colors for the status pill.
abstract final class ConnectionStatusConstants {
  static const idleLabel = 'Idle';
  static const loadingLabel = 'Loading';
  static const liveLabel = 'Live';
  static const reconnectingLabel = 'Reconnecting';
  static const errorLabel = 'Error';

  static const idleColor = Colors.blueGrey;
  static const loadingColor = Colors.amber;
  static const liveColor = AppConstants.seedColor;
  static const reconnectingColor = Colors.orange;
  static const errorColor = Colors.redAccent;
}

/// Symbol selector layout.
abstract final class SymbolSelectorConstants {
  static const spacing = 12.0;
  static const runSpacing = 8.0;
}
