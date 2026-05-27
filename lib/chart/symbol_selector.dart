import 'package:flutter/material.dart';

import '../constants/app_constants.dart';

class SymbolSelection {
  const SymbolSelection({required this.symbol, required this.interval});

  final String symbol;
  final String interval;
}

class SymbolSelector extends StatelessWidget {
  const SymbolSelector({
    super.key,
    required this.symbol,
    required this.interval,
    required this.onChanged,
  });

  static const symbols = MarketConstants.symbols;
  static const intervals = MarketConstants.intervals;

  final String symbol;
  final String interval;
  final ValueChanged<SymbolSelection> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: SymbolSelectorConstants.spacing,
      runSpacing: SymbolSelectorConstants.runSpacing,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        DropdownButton<String>(
          value: symbol,
          dropdownColor: ChartColors.dropdownBackground,
          items:
              symbols
                  .map(
                    (value) =>
                        DropdownMenuItem(value: value, child: Text(value)),
                  )
                  .toList(),
          onChanged: (value) {
            if (value != null) {
              onChanged(SymbolSelection(symbol: value, interval: interval));
            }
          },
        ),
        DropdownButton<String>(
          value: interval,
          dropdownColor: ChartColors.dropdownBackground,
          items:
              intervals
                  .map(
                    (value) =>
                        DropdownMenuItem(value: value, child: Text(value)),
                  )
                  .toList(),
          onChanged: (value) {
            if (value != null) {
              onChanged(SymbolSelection(symbol: symbol, interval: value));
            }
          },
        ),
      ],
    );
  }
}
