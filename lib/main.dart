import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'chart/ohlcv_chart.dart';
import 'chart/symbol_selector.dart';
import 'constants/app_constants.dart';
import 'data/binance_client.dart';
import 'data/candle_repository.dart';

void main() {
  debugProfileBuildsEnabled = kDebugMode || kProfileMode;
  runApp(const OhlcvChartApp());
}

class OhlcvChartApp extends StatelessWidget {
  const OhlcvChartApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      showPerformanceOverlay: !kIsWeb,
      title: AppConstants.appTitle,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppConstants.seedColor,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const ChartScreen(),
    );
  }
}

class ChartScreen extends StatefulWidget {
  const ChartScreen({super.key});

  @override
  State<ChartScreen> createState() => _ChartScreenState();
}

class _ChartScreenState extends State<ChartScreen> {
  late final CandleRepository _repository;
  String _symbol = AppConstants.defaultSymbol;
  String _interval = AppConstants.defaultInterval;

  @override
  void initState() {
    super.initState();
    _repository = CandleRepository(client: BinanceClient());
    _repository.start(symbol: _symbol, interval: _interval);
  }

  @override
  void dispose() {
    _repository.dispose();
    super.dispose();
  }

  Future<void> _changeMarket(SymbolSelection selection) async {
    if (selection.symbol == _symbol && selection.interval == _interval) {
      return;
    }

    setState(() {
      _symbol = selection.symbol;
      _interval = selection.interval;
    });
    await _repository.start(symbol: _symbol, interval: _interval);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: AppConstants.headerPadding,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    AppConstants.brandTitle,
                    style: TextStyle(
                      fontSize: AppConstants.brandTitleFontSize,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: AppConstants.headerSpacing),
                  SymbolSelector(
                    symbol: _symbol,
                    interval: _interval,
                    onChanged: _changeMarket,
                  ),
                  const Spacer(),
                  _StatusPill(repository: _repository),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: AppConstants.chartPadding,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(
                    AppConstants.chartBorderRadius,
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(color: AppConstants.chartBorderColor),
                      borderRadius: BorderRadius.circular(
                        AppConstants.chartBorderRadius,
                      ),
                    ),
                    child: OhlcvChart(candles: _repository.candles),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.repository});

  final CandleRepository repository;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ConnectionStateStatus>(
      valueListenable: repository.status,
      builder: (context, status, _) {
        final (label, color) = switch (status) {
          ConnectionStateStatus.idle => (
            ConnectionStatusConstants.idleLabel,
            ConnectionStatusConstants.idleColor,
          ),
          ConnectionStateStatus.loading => (
            ConnectionStatusConstants.loadingLabel,
            ConnectionStatusConstants.loadingColor,
          ),
          ConnectionStateStatus.live => (
            ConnectionStatusConstants.liveLabel,
            ConnectionStatusConstants.liveColor,
          ),
          ConnectionStateStatus.reconnecting => (
            ConnectionStatusConstants.reconnectingLabel,
            ConnectionStatusConstants.reconnectingColor,
          ),
          ConnectionStateStatus.error => (
            ConnectionStatusConstants.errorLabel,
            ConnectionStatusConstants.errorColor,
          ),
        };

        return Tooltip(
          message: repository.errorMessage.value ?? label,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: color.withValues(
                alpha: AppConstants.statusPillBackgroundAlpha,
              ),
              border: Border.all(
                color: color.withValues(
                  alpha: AppConstants.statusPillBorderAlpha,
                ),
              ),
              borderRadius: BorderRadius.circular(
                AppConstants.statusPillBorderRadius,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.statusPillHorizontalPadding,
                vertical: AppConstants.statusPillVerticalPadding,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: AppConstants.statusDotSize,
                    height: AppConstants.statusDotSize,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: AppConstants.statusDotSpacing),
                  Text(label),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
