import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../constants/app_constants.dart';

class ChartViewport extends ChangeNotifier {
  ChartViewport({
    double visibleCount = ChartViewportConstants.defaultVisibleCount,
    double rightOffset = ChartViewportConstants.defaultRightOffset,
    this.minVisibleCount = ChartViewportConstants.minVisibleCount,
    this.maxVisibleCount = ChartViewportConstants.maxVisibleCount,
  }) : _visibleCount = visibleCount,
       _rightOffset = rightOffset;

  final double minVisibleCount;
  final double maxVisibleCount;

  double _visibleCount;
  double _rightOffset;
  int _dataLength = 0;

  double get visibleCount => _visibleCount;
  double get rightOffset => _rightOffset;
  int get dataLength => _dataLength;

  int get startIndex {
    final start = _dataLength - _rightOffset - _visibleCount;
    return start.floor().clamp(0, math.max(0, _dataLength - 1));
  }

  int get endIndex {
    final end = _dataLength - _rightOffset;
    return end.ceil().clamp(0, _dataLength);
  }

  bool get isAtRealtimeEdge =>
      _rightOffset <= ChartViewportConstants.realtimeEdgeThreshold;

  void setDataLength(int value) {
    if (_dataLength == value) {
      return;
    }
    _dataLength = value;
    _clamp();
    notifyListeners();
  }

  void panByPixels(double deltaDx, double width) {
    if (width <= 0) {
      return;
    }
    final candlesDelta = deltaDx / (width / _visibleCount);
    _rightOffset += candlesDelta;
    _clamp();
    notifyListeners();
  }

  void zoom({required double factor, required double focalFraction}) {
    if (factor == 0) {
      return;
    }

    final clampedFocal = focalFraction.clamp(0.0, 1.0);
    final oldVisible = _visibleCount;
    final newVisible = (_visibleCount / factor).clamp(
      minVisibleCount,
      maxVisibleCount,
    );
    if (newVisible == oldVisible) {
      return;
    }

    final focalFromRight = (1 - clampedFocal) * oldVisible + _rightOffset;
    _visibleCount = newVisible;
    _rightOffset = focalFromRight - (1 - clampedFocal) * newVisible;
    _clamp();
    notifyListeners();
  }

  void scrollToRealtime() {
    if (_rightOffset == 0) {
      return;
    }
    _rightOffset = 0;
    notifyListeners();
  }

  void _clamp() {
    _visibleCount = _visibleCount.clamp(minVisibleCount, maxVisibleCount);
    final maxOffset = math.max(
      0.0,
      _dataLength - ChartViewportConstants.minScrollOffsetCandles,
    );
    _rightOffset = _rightOffset.clamp(0.0, maxOffset);
  }
}
