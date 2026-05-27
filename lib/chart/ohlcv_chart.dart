import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../constants/app_constants.dart';
import '../models/candle.dart';
import 'chart_viewport.dart';
import 'ohlcv_painter.dart';

class OhlcvChart extends StatefulWidget {
  const OhlcvChart({super.key, required this.candles});

  final ValueNotifier<List<Candle>> candles;

  @override
  State<OhlcvChart> createState() => _OhlcvChartState();
}

class _OhlcvChartState extends State<OhlcvChart> {
  final _viewport = ChartViewport();
  final _crosshair = ValueNotifier<Offset?>(null);
  Offset? _lastCrosshairPosition;
  Offset? _pendingCrosshairPosition;
  double _lastScale = ChartViewportConstants.initialScale;
  double _lastTrackpadScale = ChartViewportConstants.initialScale;
  bool _crosshairUpdateScheduled = false;

  @override
  void initState() {
    super.initState();
    widget.candles.addListener(_syncDataLength);
    _syncDataLength();
  }

  @override
  void didUpdateWidget(covariant OhlcvChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.candles != widget.candles) {
      oldWidget.candles.removeListener(_syncDataLength);
      widget.candles.addListener(_syncDataLength);
      _syncDataLength();
    }
  }

  @override
  void dispose() {
    widget.candles.removeListener(_syncDataLength);
    _viewport.dispose();
    _crosshair.dispose();
    super.dispose();
  }

  void _syncDataLength() {
    _viewport.setDataLength(widget.candles.value.length);
  }

  bool _isInsidePlot(Offset localPosition, double plotWidth) {
    return localPosition.dx >= 0 && localPosition.dx <= plotWidth;
  }

  double _focalFraction(Offset localPosition, double plotWidth) {
    return (localPosition.dx / plotWidth).clamp(0.0, 1.0);
  }

  void _queueCrosshairUpdate(Offset? position) {
    if (position != null && _lastCrosshairPosition != null) {
      final delta = position - _lastCrosshairPosition!;
      final threshold = ChartViewportConstants.crosshairMoveThresholdPx;
      if (delta.distanceSquared < threshold * threshold) {
        return;
      }
    }

    _pendingCrosshairPosition = position;
    if (_crosshairUpdateScheduled) {
      return;
    }

    _crosshairUpdateScheduled = true;
    SchedulerBinding.instance.scheduleFrameCallback((_) {
      _crosshairUpdateScheduled = false;
      if (!mounted) {
        return;
      }

      final next = _pendingCrosshairPosition;
      _pendingCrosshairPosition = null;
      if (next == _lastCrosshairPosition && next == _crosshair.value) {
        return;
      }

      _lastCrosshairPosition = next;
      _crosshair.value = next;
    });
  }

  void _handleTrackpadPanZoomUpdate(
    PointerPanZoomUpdateEvent event,
    double plotWidth,
  ) {
    if (!_isInsidePlot(event.localPosition, plotWidth)) {
      return;
    }

    _queueCrosshairUpdate(event.localPosition);
    final scaleDelta = (event.scale - _lastTrackpadScale).abs();
    final isZooming = scaleDelta > ChartViewportConstants.pinchZoomThreshold;

    if (isZooming) {
      final factor = event.scale / _lastTrackpadScale;
      _lastTrackpadScale = event.scale;
      _viewport.zoom(
        factor: factor,
        focalFraction: _focalFraction(event.localPosition, plotWidth),
      );
      return;
    }

    if (event.panDelta.dx != 0) {
      _viewport.panByPixels(event.panDelta.dx, plotWidth);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chartRepaint = Listenable.merge([widget.candles, _viewport]);
    final crosshairRepaint = Listenable.merge([
      widget.candles,
      _viewport,
      _crosshair,
    ]);

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final plotWidth = (size.width - ChartLayoutConstants.priceAxisWidth)
            .clamp(1.0, double.infinity);
        return Stack(
          children: [
            Positioned.fill(
              child: RepaintBoundary(
                child: Listener(
                  onPointerPanZoomStart: (event) {
                    if (!_isInsidePlot(event.localPosition, plotWidth)) {
                      return;
                    }
                    _lastTrackpadScale = ChartViewportConstants.initialScale;
                    _queueCrosshairUpdate(event.localPosition);
                  },
                  onPointerPanZoomUpdate:
                      (event) => _handleTrackpadPanZoomUpdate(event, plotWidth),
                  onPointerPanZoomEnd: (_) {
                    _lastTrackpadScale = ChartViewportConstants.initialScale;
                  },
                  onPointerSignal: (event) {
                    if (event is PointerScaleEvent) {
                      if (!_isInsidePlot(event.localPosition, plotWidth)) {
                        return;
                      }
                      _queueCrosshairUpdate(event.localPosition);
                      _viewport.zoom(
                        factor: event.scale,
                        focalFraction: _focalFraction(
                          event.localPosition,
                          plotWidth,
                        ),
                      );
                    } else if (event is PointerScrollEvent) {
                      if (!_isInsidePlot(event.localPosition, plotWidth)) {
                        return;
                      }
                      final factor =
                          event.scrollDelta.dy < 0
                              ? ChartViewportConstants.wheelZoomInFactor
                              : ChartViewportConstants.wheelZoomOutFactor;
                      _viewport.zoom(
                        factor: factor,
                        focalFraction: _focalFraction(
                          event.localPosition,
                          plotWidth,
                        ),
                      );
                    }
                  },
                  child: MouseRegion(
                    onHover:
                        (event) => _queueCrosshairUpdate(event.localPosition),
                    onExit: (_) => _queueCrosshairUpdate(null),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onScaleStart: (details) {
                        _lastScale = ChartViewportConstants.initialScale;
                        _queueCrosshairUpdate(details.localFocalPoint);
                      },
                      onScaleUpdate: (details) {
                        _queueCrosshairUpdate(details.localFocalPoint);
                        final isZooming =
                            (details.scale - _lastScale).abs() >
                            ChartViewportConstants.pinchZoomThreshold;
                        if (!isZooming) {
                          _viewport.panByPixels(
                            details.focalPointDelta.dx,
                            plotWidth,
                          );
                        }
                        if (details.scale != 1) {
                          final factor = details.scale / _lastScale;
                          _lastScale = details.scale;
                          _viewport.zoom(
                            factor: factor,
                            focalFraction: _focalFraction(
                              details.localFocalPoint,
                              plotWidth,
                            ),
                          );
                        }
                      },
                      onScaleEnd: (_) {
                        _lastScale = ChartViewportConstants.initialScale;
                      },
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          RepaintBoundary(
                            child: CustomPaint(
                              painter: OhlcvPainter(
                                candleListenable: widget.candles,
                                viewport: _viewport,
                                repaint: chartRepaint,
                              ),
                              size: Size.infinite,
                            ),
                          ),
                          RepaintBoundary(
                            child: IgnorePointer(
                              child: CustomPaint(
                                painter: OhlcvCrosshairPainter(
                                  candleListenable: widget.candles,
                                  viewport: _viewport,
                                  crosshairListenable: _crosshair,
                                  repaint: crosshairRepaint,
                                ),
                                size: Size.infinite,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: ChartLayoutConstants.realtimeButtonRight,
              bottom: ChartLayoutConstants.realtimeButtonBottom,
              child: AnimatedBuilder(
                animation: _viewport,
                builder: (context, _) {
                  if (_viewport.isAtRealtimeEdge) {
                    return const SizedBox.shrink();
                  }
                  return FilledButton.tonal(
                    onPressed: _viewport.scrollToRealtime,
                    child: const Text(ChartLayoutConstants.realtimeButtonLabel),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
