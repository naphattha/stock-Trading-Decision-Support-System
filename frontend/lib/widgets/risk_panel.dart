import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../models/models.dart';

class RiskPanel extends StatefulWidget {
  final RiskData? data;
  final bool loading;
  final double portfolioValue;
  final ValueChanged<double> onPortfolioChanged;

  const RiskPanel({
    super.key,
    required this.data,
    required this.loading,
    required this.portfolioValue,
    required this.onPortfolioChanged,
  });

  @override
  State<RiskPanel> createState() => _RiskPanelState();
}

class _RiskPanelState extends State<RiskPanel> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
        text: widget.portfolioValue.toStringAsFixed(0));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Portfolio value input ─────────────────────────────────────────────
        _card(child: Row(children: [
          const Icon(Icons.account_balance_wallet_outlined,
              color: AppConfig.accent, size: 20),
          const SizedBox(width: 12),
          const Text('Portfolio Value (USD)',
              style: TextStyle(color: AppConfig.textSecondary, fontSize: 13)),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _ctrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: AppConfig.textPrimary,
                  fontSize: 15, fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                prefixText: '\$',
                prefixStyle: const TextStyle(color: AppConfig.accent),
                filled: true, fillColor: AppConfig.bgDeep,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppConfig.border)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppConfig.border)),
              ),
              onSubmitted: (v) {
                final pv = double.tryParse(v.replaceAll(',', ''));
                if (pv != null && pv > 0) widget.onPortfolioChanged(pv);
              },
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppConfig.accent,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
            onPressed: () {
              final pv = double.tryParse(_ctrl.text.replaceAll(',', ''));
              if (pv != null && pv > 0) widget.onPortfolioChanged(pv);
            },
            child: const Text('Calc', style: TextStyle(color: Colors.black,
                fontWeight: FontWeight.w700)),
          ),
        ])),

        const SizedBox(height: 16),

        if (widget.loading)
          const Center(child: Padding(
            padding: EdgeInsets.all(32),
            child: CircularProgressIndicator(color: AppConfig.accent),
          ))
        else if (d == null)
          _empty()
        else
          ..._buildRiskContent(d),
      ]),
    );
  }

  List<Widget> _buildRiskContent(RiskData d) => [
    // ── ATR & Price levels ────────────────────────────────────────────────────
    _section('Price Levels (ATR-based)', [
      _row('Entry Price',      '\$${d.entryPrice.toStringAsFixed(2)}', AppConfig.textPrimary),
      _row('ATR (14)',         d.atr.toStringAsFixed(4),               AppConfig.textSecondary),
      _row('Stop-Loss  (−2×ATR)', '\$${d.suggestedStopLoss.toStringAsFixed(2)}', AppConfig.sell),
      _row('Take-Profit (+3×ATR)','\$${d.suggestedTakeProfit.toStringAsFixed(2)}', AppConfig.buy),
      _row('Risk/Reward Ratio', '1 : ${d.rrRatio.toStringAsFixed(2)}',
          d.rrRatio >= 2 ? AppConfig.buy : AppConfig.hold),
    ]),

    const SizedBox(height: 16),

    // ── Position sizing ───────────────────────────────────────────────────────
    _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Position Sizing',
          style: TextStyle(color: AppConfig.textSecondary, fontSize: 11,
              fontWeight: FontWeight.w700, letterSpacing: 0.8)),
      const SizedBox(height: 12),
      // Table header
      _tableHeader(),
      const Divider(color: AppConfig.border),
      _tableRow('Fixed 1 % Risk', d.fixed1PctShares, d.fixed1PctValue,
          '1% of portfolio'),
      const Divider(color: AppConfig.border, height: 1),
      _tableRow('Fixed 2 % Risk', d.fixed2PctShares, d.fixed2PctValue,
          '2% of portfolio'),
      if (d.kellyShares != null) ...[
        const Divider(color: AppConfig.border, height: 1),
        _tableRow(
          'Half-Kelly  (${((d.kellyFraction ?? 0) * 100).toStringAsFixed(1)}%)',
          d.kellyShares!,
          d.kellyValue ?? 0,
          d.historicalWinRate != null
              ? 'Win rate ${(d.historicalWinRate! * 100).toStringAsFixed(0)}%'
              : '',
        ),
      ],
    ])),

    const SizedBox(height: 16),

    // ── Kelly note ────────────────────────────────────────────────────────────
    _card(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Icon(Icons.info_outline, color: AppConfig.accent, size: 16),
      const SizedBox(width: 8),
      Expanded(
        child: Text(d.kellyNote,
            style: const TextStyle(
                color: AppConfig.textSecondary, fontSize: 12, height: 1.5)),
      ),
    ])),
  ];

  Widget _empty() => _card(
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('Enter portfolio value and tap Calc.',
                style: TextStyle(color: AppConfig.textSecondary)),
          ),
        ),
      );

  Widget _card({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppConfig.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppConfig.border),
        ),
        child: child,
      );

  Widget _section(String title, List<Widget> rows) => _card(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(color: AppConfig.textSecondary,
              fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
          const SizedBox(height: 12),
          ...rows.expand((r) => [r, const Divider(color: AppConfig.border, height: 1)])
              .toList()..removeLast(),
        ]),
      );

  Widget _row(String label, String value, Color color) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(children: [
          Expanded(child: Text(label,
              style: const TextStyle(color: AppConfig.textSecondary, fontSize: 13))),
          Text(value, style: TextStyle(color: color, fontSize: 13,
              fontWeight: FontWeight.w600)),
        ]),
      );

  Widget _tableHeader() => Row(children: [
        const Expanded(flex: 3, child: Text('Method',
            style: TextStyle(color: AppConfig.textSecondary, fontSize: 11))),
        const Expanded(flex: 2, child: Text('Shares',
            style: TextStyle(color: AppConfig.textSecondary, fontSize: 11),
            textAlign: TextAlign.right)),
        const Expanded(flex: 2, child: Text('Value',
            style: TextStyle(color: AppConfig.textSecondary, fontSize: 11),
            textAlign: TextAlign.right)),
        const Expanded(flex: 2, child: Text('Note',
            style: TextStyle(color: AppConfig.textSecondary, fontSize: 11),
            textAlign: TextAlign.right)),
      ]);

  Widget _tableRow(String method, int shares, double value, String note) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          Expanded(flex: 3, child: Text(method,
              style: const TextStyle(color: AppConfig.textPrimary, fontSize: 12))),
          Expanded(flex: 2, child: Text('$shares',
              style: const TextStyle(color: AppConfig.accent, fontSize: 12,
                  fontWeight: FontWeight.w700),
              textAlign: TextAlign.right)),
          Expanded(flex: 2, child: Text('\$${value.toStringAsFixed(0)}',
              style: const TextStyle(color: AppConfig.textPrimary, fontSize: 12),
              textAlign: TextAlign.right)),
          Expanded(flex: 2, child: Text(note,
              style: const TextStyle(color: AppConfig.textSecondary, fontSize: 10),
              textAlign: TextAlign.right)),
        ]),
      );
}
