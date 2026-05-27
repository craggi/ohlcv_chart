import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../constants/app_constants.dart';
import '../models/candle.dart';
import 'chart_viewport.dart';

class OhlcvPainter extends CustomPainter {
  OhlcvPainter({
    required this.candleListenable,
    required this.viewport,
    super.repaint,
  });

  static final _timeFormat = DateFormat.Hm();

  static final _backgroundPaint = Paint()..color = ChartColors.background;
  static final _gridPaint =
      Paint()
        ..color = ChartColors.grid
        ..strokeWidth = ChartColors.strokeWidth;
  static final _bullPaint = Paint()..color = ChartColors.bull;
  static final _bearPaint = Paint()..color = ChartColors.bear;
  static final _wickBullPaint =
      Paint()
        ..color = ChartColors.bull
        ..strokeWidth = ChartColors.strokeWidth
        ..style = PaintingStyle.stroke;
  static final _wickBearPaint =
      Paint()
        ..color = ChartColors.bear
        ..strokeWidth = ChartColors.strokeWidth
        ..style = PaintingStyle.stroke;
  static final _volumeBullPaint = Paint()..color = ChartColors.volumeBull;
  static final _volumeBearPaint = Paint()..color = ChartColors.volumeBear;
  static final _axisBackgroundPaint =
      Paint()..color = ChartColors.axisBackground;
  static final _currentPriceBullBackgroundPaint =
      Paint()..color = ChartColors.bull;
  static final _currentPriceBearBackgroundPaint =
      Paint()..color = ChartColors.bear;
  static final _currentPriceBullLinePaint =
      Paint()
        ..color = ChartColors.bull.withValues(alpha: 0.55)
        ..strokeWidth = ChartColors.strokeWidth;
  static final _currentPriceBearLinePaint =
      Paint()
        ..color = ChartColors.bear.withValues(alpha: 0.55)
        ..strokeWidth = ChartColors.strokeWidth;

  static const _labelStyle = TextStyle(
    color: ChartColors.label,
    fontSize: ChartColors.labelFontSize,
    height: ChartColors.labelLineHeight,
  );
  static const _priceLabelStyle = TextStyle(
    color: ChartColors.priceLabel,
    fontSize: ChartColors.labelFontSize,
    height: ChartColors.labelLineHeight,
  );
  static const _currentPriceLabelStyle = TextStyle(
    color: Colors.white,
    fontSize: ChartColors.labelFontSize,
    fontWeight: FontWeight.w700,
    height: ChartColors.labelLineHeight,
  );
  static const _labelBoxHorizontalPadding = 6.0;
  static const _labelBoxVerticalPadding = 4.0;
  static const _labelBoxBorderRadius = 4.0;
  static const _rightAxisCandleGap = 8.0;
  static const _axisLabelVerticalMargin = 6.0;

  final ValueListenable<List<Candle>> candleListenable;
  final ChartViewport viewport;

  @override
  void paint(Canvas canvas, Size size) {
    final candles = candleListenable.value;

    canvas.drawRect(Offset.zero & size, _backgroundPaint);
    if (size.width <= 0 || size.height <= 0) {
      return;
    }

    const priceAxisWidth = ChartLayoutConstants.priceAxisWidth;
    const timeAxisHeight = ChartLayoutConstants.timeAxisHeight;
    const volumeRatio = ChartLayoutConstants.volumePaneRatio;
    final chartWidth = math.max(0.0, size.width - priceAxisWidth);
    final chartHeight = math.max(0.0, size.height - timeAxisHeight);
    final volumeHeight = chartHeight * volumeRatio;
    final priceHeight = chartHeight - volumeHeight;
    final priceRect = Rect.fromLTWH(0, 0, chartWidth, priceHeight);
    final volumeRect = Rect.fromLTWH(0, priceHeight, chartWidth, volumeHeight);
    final axisRect = Rect.fromLTWH(chartWidth, 0, priceAxisWidth, size.height);

    canvas.drawRect(axisRect, _axisBackgroundPaint);
    if (candles.isEmpty) {
      _drawEmptyChartGrid(canvas, priceRect, volumeRect);
      return;
    }

    final start = viewport.startIndex;
    final end = viewport.endIndex;
    if (start >= end) {
      _drawEmptyChartGrid(canvas, priceRect, volumeRect);
      return;
    }

    final range = _PriceRange.fromRange(candles, start, end);
    var maxVolume = 0.0;
    for (var i = start; i < end; i++) {
      maxVolume = math.max(maxVolume, candles[i].volume);
    }
    final candleStep = chartWidth / viewport.visibleCount;
    final bodyWidth = math.max(
      ChartLayoutConstants.minCandleBodyWidth,
      candleStep * ChartLayoutConstants.candleBodyWidthRatio,
    );
    final firstX =
        chartWidth -
        (candles.length - start - viewport.rightOffset) * candleStep +
        candleStep / 2;

    _drawGrid(canvas, priceRect, volumeRect, range, candleStep, firstX);
    _drawCandles(
      canvas,
      candles,
      start,
      end,
      range,
      maxVolume,
      priceRect,
      volumeRect,
      candleStep,
      bodyWidth,
      firstX,
    );
    _drawPriceAxis(canvas, priceRect, chartWidth, range);
    _drawTimeAxis(
      canvas,
      candles,
      start,
      end,
      chartWidth,
      priceHeight,
      candleStep,
      firstX,
    );
    _drawCurrentPriceMarker(canvas, candles.last, range, priceRect, chartWidth);
  }

  void _drawEmptyChartGrid(Canvas canvas, Rect priceRect, Rect volumeRect) {
    const rows = ChartLayoutConstants.gridRows;
    for (var i = 0; i <= rows; i++) {
      final y = priceRect.top + priceRect.height * i / rows;
      canvas.drawLine(
        Offset(priceRect.left, y),
        Offset(priceRect.right, y),
        _gridPaint,
      );
    }

    canvas.drawLine(
      Offset(volumeRect.left, volumeRect.top),
      Offset(volumeRect.right, volumeRect.top),
      _gridPaint,
    );

    for (
      var x = priceRect.left;
      x <= priceRect.right;
      x += ChartLayoutConstants.verticalGridStridePx
    ) {
      canvas.drawLine(
        Offset(x, priceRect.top),
        Offset(x, volumeRect.bottom),
        _gridPaint,
      );
    }
  }

  void _drawGrid(
    Canvas canvas,
    Rect priceRect,
    Rect volumeRect,
    _PriceRange range,
    double candleStep,
    double firstX,
  ) {
    const rows = ChartLayoutConstants.gridRows;
    for (var i = 0; i <= rows; i++) {
      final y = priceRect.top + priceRect.height * i / rows;
      canvas.drawLine(
        Offset(priceRect.left, y),
        Offset(priceRect.right, y),
        _gridPaint,
      );
    }

    canvas.drawLine(
      Offset(volumeRect.left, volumeRect.top),
      Offset(volumeRect.right, volumeRect.top),
      _gridPaint,
    );

    final verticalStride = math.max(
      1,
      (ChartLayoutConstants.verticalGridStridePx / candleStep).round(),
    );
    for (var i = 0; i < viewport.visibleCount.ceil() + verticalStride; i++) {
      if (i % verticalStride != 0) {
        continue;
      }
      final x = firstX + i * candleStep;
      if (x < priceRect.left || x > priceRect.right) {
        continue;
      }
      canvas.drawLine(
        Offset(x, priceRect.top),
        Offset(x, volumeRect.bottom),
        _gridPaint,
      );
    }
  }

  void _drawCandles(
    Canvas canvas,
    List<Candle> candles,
    int start,
    int end,
    _PriceRange range,
    double maxVolume,
    Rect priceRect,
    Rect volumeRect,
    double candleStep,
    double bodyWidth,
    double firstX,
  ) {
    final bullBodies = Path();
    final bearBodies = Path();
    final bullVolumes = Path();
    final bearVolumes = Path();
    final bullWicks = Path();
    final bearWicks = Path();
    var hasBull = false;
    var hasBear = false;
    var hasBullVolume = false;
    var hasBearVolume = false;
    final priceScale = priceRect.height / range.span;
    final volumeScale = maxVolume > 0 ? volumeRect.height / maxVolume : 0.0;

    for (var candleIndex = start; candleIndex < end; candleIndex++) {
      final candle = candles[candleIndex];
      final x = firstX + (candleIndex - start) * candleStep;
      if (x + bodyWidth < priceRect.left || x - bodyWidth > priceRect.right) {
        continue;
      }

      final bullish = candle.isBullish;
      final wickPath = bullish ? bullWicks : bearWicks;
      final highY = priceRect.bottom - (candle.high - range.min) * priceScale;
      final lowY = priceRect.bottom - (candle.low - range.min) * priceScale;
      final openY = priceRect.bottom - (candle.open - range.min) * priceScale;
      final closeY = priceRect.bottom - (candle.close - range.min) * priceScale;
      wickPath
        ..moveTo(x, highY)
        ..lineTo(x, lowY);

      final bodyTop = math.min(openY, closeY);
      final bodyBottom = math.max(openY, closeY);
      final left = x - bodyWidth / 2;
      final right = x + bodyWidth / 2;
      final bottom = math.max(bodyTop + 1, bodyBottom);
      final bodyPath = bullish ? bullBodies : bearBodies;
      bodyPath
        ..moveTo(left, bodyTop)
        ..lineTo(right, bodyTop)
        ..lineTo(right, bottom)
        ..lineTo(left, bottom)
        ..close();

      if (maxVolume > 0) {
        final volumeTop = volumeRect.bottom - candle.volume * volumeScale;
        final volumePath = bullish ? bullVolumes : bearVolumes;
        volumePath
          ..moveTo(left, volumeTop)
          ..lineTo(right, volumeTop)
          ..lineTo(right, volumeRect.bottom)
          ..lineTo(left, volumeRect.bottom)
          ..close();
        if (bullish) {
          hasBullVolume = true;
        } else {
          hasBearVolume = true;
        }
      }

      if (bullish) {
        hasBull = true;
      } else {
        hasBear = true;
      }
    }

    final clipRight = math.max(
      priceRect.left,
      priceRect.right - _rightAxisCandleGap,
    );
    canvas
      ..save()
      ..clipRect(
        Rect.fromLTRB(
          priceRect.left,
          priceRect.top,
          clipRight,
          volumeRect.bottom,
        ),
      );
    if (hasBull) {
      canvas
        ..drawPath(bullWicks, _wickBullPaint)
        ..drawPath(bullBodies, _bullPaint);
    }
    if (hasBear) {
      canvas
        ..drawPath(bearWicks, _wickBearPaint)
        ..drawPath(bearBodies, _bearPaint);
    }
    if (hasBullVolume) {
      canvas.drawPath(bullVolumes, _volumeBullPaint);
    }
    if (hasBearVolume) {
      canvas.drawPath(bearVolumes, _volumeBearPaint);
    }
    canvas.restore();
  }

  void _drawPriceAxis(
    Canvas canvas,
    Rect priceRect,
    double chartWidth,
    _PriceRange range,
  ) {
    const rows = ChartLayoutConstants.gridRows;
    for (var i = 0; i <= rows; i++) {
      final value = range.max - range.span * i / rows;
      final y = priceRect.top + priceRect.height * i / rows;
      _drawPriceAxisText(
        canvas: canvas,
        text: _formatPrice(value),
        x: chartWidth + ChartLayoutConstants.priceLabelXOffset,
        centerY: y,
        priceRect: priceRect,
      );
    }
  }

  void _drawPriceAxisText({
    required Canvas canvas,
    required String text,
    required double x,
    required double centerY,
    required Rect priceRect,
  }) {
    final painter = _layoutText(text, _priceLabelStyle);
    final top = (centerY - painter.height / 2).clamp(
      priceRect.top + _axisLabelVerticalMargin,
      priceRect.bottom - painter.height - _axisLabelVerticalMargin,
    );
    painter.paint(canvas, Offset(x, top));
  }

  void _drawTimeAxis(
    Canvas canvas,
    List<Candle> candles,
    int start,
    int end,
    double chartWidth,
    double priceHeight,
    double candleStep,
    double firstX,
  ) {
    final stride = math.max(
      1,
      (ChartLayoutConstants.timeLabelStridePx / candleStep).round(),
    );
    for (var candleIndex = start; candleIndex < end; candleIndex += stride) {
      final x = firstX + (candleIndex - start) * candleStep;
      if (x < 0 || x > chartWidth - ChartLayoutConstants.timeLabelMaxOffset) {
        continue;
      }
      final label = _timeFormat.format(
        candles[candleIndex].openDateTime.toLocal(),
      );
      _drawText(
        canvas,
        label,
        Offset(
          x - ChartLayoutConstants.timeLabelXOffset,
          priceHeight + ChartLayoutConstants.timeLabelYOffset,
        ),
        _labelStyle,
      );
    }
  }

  void _drawCurrentPriceMarker(
    Canvas canvas,
    Candle candle,
    _PriceRange range,
    Rect priceRect,
    double chartWidth,
  ) {
    final price = candle.close;
    final backgroundPaint =
        candle.isBullish
            ? _currentPriceBullBackgroundPaint
            : _currentPriceBearBackgroundPaint;
    final linePaint =
        candle.isBullish
            ? _currentPriceBullLinePaint
            : _currentPriceBearLinePaint;
    final y = range.priceToY(price, priceRect);
    if (y < priceRect.top || y > priceRect.bottom) {
      return;
    }

    canvas.drawLine(
      Offset(priceRect.left, y),
      Offset(priceRect.right, y),
      linePaint,
    );

    _drawAxisLabelBox(
      canvas,
      text: _formatPrice(price),
      x: chartWidth,
      y: y,
      maxWidth: ChartLayoutConstants.priceAxisWidth,
      minY: priceRect.top,
      maxY: priceRect.bottom,
      backgroundPaint: backgroundPaint,
      style: _currentPriceLabelStyle,
    );
  }

  void _drawAxisLabelBox(
    Canvas canvas, {
    required String text,
    required double x,
    required double y,
    required double maxWidth,
    required double minY,
    required double maxY,
    required Paint backgroundPaint,
    required TextStyle style,
  }) {
    final painter = _layoutText(text, style);
    final width = math.min(
      maxWidth,
      painter.width + _labelBoxHorizontalPadding * 2,
    );
    final height = painter.height + _labelBoxVerticalPadding * 2;
    final minTop = minY + _axisLabelVerticalMargin;
    final maxTop = math.max(minTop, maxY - height - _axisLabelVerticalMargin);
    final top = (y - height / 2).clamp(minTop, maxTop);
    final rect = Rect.fromLTWH(x, top, width, height);
    _drawLabelBackground(canvas, rect, backgroundPaint);
    painter.paint(
      canvas,
      Offset(
        rect.left + (rect.width - painter.width) / 2,
        rect.top + (rect.height - painter.height) / 2,
      ),
    );
  }

  void _drawLabelBackground(Canvas canvas, Rect rect, Paint paint) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect,
        const Radius.circular(_labelBoxBorderRadius),
      ),
      paint,
    );
  }

  void _drawText(Canvas canvas, String text, Offset offset, TextStyle style) {
    final painter = _layoutText(text, style);
    painter.paint(canvas, offset);
  }

  TextPainter _layoutText(String text, TextStyle style) {
    return TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: ui.TextDirection.ltr,
    )..layout();
  }

  String _formatPrice(double price) {
    if (price >= ChartLayoutConstants.priceFormatThresholdHigh) {
      return price.toStringAsFixed(ChartLayoutConstants.priceDecimalsHigh);
    }
    if (price >= ChartLayoutConstants.priceFormatThresholdLow) {
      return price.toStringAsFixed(ChartLayoutConstants.priceDecimalsMid);
    }
    return price.toStringAsFixed(ChartLayoutConstants.priceDecimalsLow);
  }

  @override
  bool shouldRepaint(covariant OhlcvPainter oldDelegate) {
    return oldDelegate.candleListenable != candleListenable ||
        oldDelegate.viewport != viewport;
  }
}

class OhlcvCrosshairPainter extends CustomPainter {
  OhlcvCrosshairPainter({
    required this.candleListenable,
    required this.viewport,
    required this.crosshairListenable,
    super.repaint,
  });

  static final _timeFormat = DateFormat('dd MMM HH:mm');
  static final _crosshairPaint =
      Paint()
        ..color = ChartColors.crosshair
        ..strokeWidth = ChartColors.strokeWidth;
  static final _labelBackgroundPaint = Paint()..color = ChartColors.priceLabel;

  static const _labelStyle = TextStyle(
    color: Colors.white,
    fontSize: ChartColors.labelFontSize,
    fontWeight: FontWeight.w600,
    height: ChartColors.labelLineHeight,
  );
  static const _labelBoxHorizontalPadding = 6.0;
  static const _labelBoxVerticalPadding = 4.0;
  static const _labelBoxBorderRadius = 4.0;
  static const _axisLabelVerticalMargin = 6.0;

  final ValueListenable<List<Candle>> candleListenable;
  final ChartViewport viewport;
  final ValueListenable<Offset?> crosshairListenable;
  final _textPainterCache = <String, TextPainter>{};

  @override
  void paint(Canvas canvas, Size size) {
    final point = crosshairListenable.value;
    final candles = candleListenable.value;
    if (point == null ||
        candles.isEmpty ||
        size.width <= 0 ||
        size.height <= 0) {
      return;
    }

    const priceAxisWidth = ChartLayoutConstants.priceAxisWidth;
    const timeAxisHeight = ChartLayoutConstants.timeAxisHeight;
    const volumeRatio = ChartLayoutConstants.volumePaneRatio;
    final chartWidth = math.max(0.0, size.width - priceAxisWidth);
    final chartHeight = math.max(0.0, size.height - timeAxisHeight);
    final volumeHeight = chartHeight * volumeRatio;
    final priceHeight = chartHeight - volumeHeight;
    final priceRect = Rect.fromLTWH(0, 0, chartWidth, priceHeight);
    final volumeRect = Rect.fromLTWH(0, priceHeight, chartWidth, volumeHeight);

    if (point.dx < priceRect.left ||
        point.dx > priceRect.right ||
        point.dy < priceRect.top ||
        point.dy > volumeRect.bottom) {
      return;
    }

    final start = viewport.startIndex;
    final end = viewport.endIndex;
    if (start >= end) {
      return;
    }

    final range = _PriceRange.fromRange(candles, start, end);
    final candleStep = chartWidth / viewport.visibleCount;
    final firstX =
        chartWidth -
        (candles.length - start - viewport.rightOffset) * candleStep +
        candleStep / 2;

    canvas.drawLine(
      Offset(point.dx, priceRect.top),
      Offset(point.dx, volumeRect.bottom),
      _crosshairPaint,
    );
    canvas.drawLine(
      Offset(priceRect.left, point.dy),
      Offset(priceRect.right, point.dy),
      _crosshairPaint,
    );

    if (point.dy <= priceRect.bottom) {
      final price = range.yToPrice(point.dy, priceRect);
      _drawAxisLabelBox(
        canvas,
        text: _formatPrice(price),
        x: priceRect.right,
        y: point.dy,
        maxWidth: ChartLayoutConstants.priceAxisWidth,
        minY: priceRect.top,
        maxY: priceRect.bottom,
      );
    }

    final candleIndex = start + ((point.dx - firstX) / candleStep).round();
    if (candleIndex >= 0 && candleIndex < candles.length) {
      final candle = candles[candleIndex];
      _drawTimeLabelBox(
        canvas,
        text: _timeFormat.format(candle.openDateTime.toLocal()),
        centerX: point.dx,
        y: volumeRect.bottom,
        minX: priceRect.left,
        maxX: priceRect.right,
      );
    }
  }

  void _drawAxisLabelBox(
    Canvas canvas, {
    required String text,
    required double x,
    required double y,
    required double maxWidth,
    required double minY,
    required double maxY,
  }) {
    final painter = _layoutText(text);
    final width = math.min(
      maxWidth,
      painter.width + _labelBoxHorizontalPadding * 2,
    );
    final height = painter.height + _labelBoxVerticalPadding * 2;
    final minTop = minY + _axisLabelVerticalMargin;
    final maxTop = math.max(minTop, maxY - height - _axisLabelVerticalMargin);
    final top = (y - height / 2).clamp(minTop, maxTop);
    final rect = Rect.fromLTWH(x, top, width, height);
    _drawLabelBackground(canvas, rect);
    painter.paint(
      canvas,
      Offset(
        rect.left + (rect.width - painter.width) / 2,
        rect.top + (rect.height - painter.height) / 2,
      ),
    );
  }

  void _drawTimeLabelBox(
    Canvas canvas, {
    required String text,
    required double centerX,
    required double y,
    required double minX,
    required double maxX,
  }) {
    final painter = _layoutText(text);
    final width = painter.width + _labelBoxHorizontalPadding * 2;
    final height = painter.height + _labelBoxVerticalPadding * 2;
    final left = (centerX - width / 2).clamp(minX, maxX - width);
    final rect = Rect.fromLTWH(left, y, width, height);
    _drawLabelBackground(canvas, rect);
    painter.paint(
      canvas,
      Offset(
        rect.left + _labelBoxHorizontalPadding,
        rect.top + _labelBoxVerticalPadding,
      ),
    );
  }

  void _drawLabelBackground(Canvas canvas, Rect rect) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect,
        const Radius.circular(_labelBoxBorderRadius),
      ),
      _labelBackgroundPaint,
    );
  }

  TextPainter _layoutText(String text) {
    final cached = _textPainterCache[text];
    if (cached != null) {
      return cached;
    }

    final painter = TextPainter(
      text: TextSpan(text: text, style: _labelStyle),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    if (_textPainterCache.length >= 64) {
      _textPainterCache.remove(_textPainterCache.keys.first);
    }
    _textPainterCache[text] = painter;
    return painter;
  }

  String _formatPrice(double price) {
    if (price >= ChartLayoutConstants.priceFormatThresholdHigh) {
      return price.toStringAsFixed(ChartLayoutConstants.priceDecimalsHigh);
    }
    if (price >= ChartLayoutConstants.priceFormatThresholdLow) {
      return price.toStringAsFixed(ChartLayoutConstants.priceDecimalsMid);
    }
    return price.toStringAsFixed(ChartLayoutConstants.priceDecimalsLow);
  }

  @override
  bool shouldRepaint(covariant OhlcvCrosshairPainter oldDelegate) {
    return oldDelegate.candleListenable != candleListenable ||
        oldDelegate.viewport != viewport ||
        oldDelegate.crosshairListenable != crosshairListenable;
  }
}

class _PriceRange {
  _PriceRange(this.min, this.max);

  factory _PriceRange.fromRange(List<Candle> candles, int start, int end) {
    var min = candles[start].low;
    var max = candles[start].high;
    for (var i = start + 1; i < end; i++) {
      final candle = candles[i];
      min = math.min(min, candle.low);
      max = math.max(max, candle.high);
    }
    final span = max - min;
    if (span <= 0) {
      return _PriceRange(
        min - ChartLayoutConstants.flatRangePadding,
        max + ChartLayoutConstants.flatRangePadding,
      );
    }
    final padding = span * ChartLayoutConstants.priceRangePaddingRatio;
    return _PriceRange(min - padding, max + padding * 1.5);
  }

  final double min;
  final double max;

  double get span => max - min;

  double priceToY(double price, Rect rect) {
    return rect.bottom - ((price - min) / span) * rect.height;
  }

  double yToPrice(double y, Rect rect) {
    final fraction = (rect.bottom - y) / rect.height;
    return min + fraction * span;
  }
}
