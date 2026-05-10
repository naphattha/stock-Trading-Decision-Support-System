import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config/app_config.dart';
import '../models/models.dart';

class FundamentalPanel extends StatelessWidget {
  final FundamentalData data;
  final VoidCallback onRefresh;

  const FundamentalPanel({super.key, required this.data, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final ok    = data.passesFilter;
    final stamp = data.updatedAt != null
        ? DateFormat('dd MMM yyyy  HH:mm')
            .format(DateTime.tryParse(data.updatedAt!)?.toLocal() ?? DateTime.now())
        : '—';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Quality verdict card ──────────────────────────────────────────────
        _card(
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color:        (ok ? AppConfig.buy : AppConfig.sell).withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                ok ? Icons.verified_rounded : Icons.warning_amber_rounded,
                color: ok ? AppConfig.buy : AppConfig.sell,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  ok ? 'Passes Quality Filter' : 'Quality Warnings',
                  style: TextStyle(
                      color: ok ? AppConfig.buy : AppConfig.sell,
                      fontSize: 15, fontWeight: FontWeight.w700),
                ),
                if (!ok) ...[
                  const SizedBox(height: 4),
                  ...data.filterWarnings.map((w) => Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text('• $w',
                            style: const TextStyle(
                                color: AppConfig.sell, fontSize: 11)),
                      )),
                ],
                const SizedBox(height: 4),
                Text('Updated $stamp',
                    style: const TextStyle(
                        color: AppConfig.textSecondary, fontSize: 11)),
              ]),
            ),
            IconButton(
              icon: const Icon(Icons.refresh, color: AppConfig.accent, size: 18),
              tooltip: 'Force refresh',
              onPressed: onRefresh,
            ),
          ]),
        ),

        const SizedBox(height: 16),

        // ── Valuation ─────────────────────────────────────────────────────────
        _section('Valuation', [
          _row('P/E Ratio (TTM)',   _fmt(data.peRatio,   suffix: 'x'),  _peColor(data.peRatio)),
          _row('Forward P/E',       _fmt(data.forwardPe, suffix: 'x'),  AppConfig.textPrimary),
          _row('Price / Book',      _fmt(data.priceToBook, suffix: 'x'), AppConfig.textPrimary),
          _row('EPS (TTM)',         data.epsTtm != null
              ? '\$${data.epsTtm!.toStringAsFixed(2)}' : '—',
              data.epsTtm != null && data.epsTtm! > 0
                  ? AppConfig.buy : AppConfig.sell),
        ]),

        const SizedBox(height: 16),

        // ── Growth & Profitability ─────────────────────────────────────────────
        _section('Growth & Profitability', [
          _row('Revenue Growth (YoY)',
              data.revenueGrowth != null
                  ? '${(data.revenueGrowth! * 100).toStringAsFixed(1)}%' : '—',
              data.revenueGrowth != null && data.revenueGrowth! > 0
                  ? AppConfig.buy : AppConfig.sell),
          _row('Profit Margin',
              data.profitMargin != null
                  ? '${(data.profitMargin! * 100).toStringAsFixed(1)}%' : '—',
              data.profitMargin != null && data.profitMargin! > 0
                  ? AppConfig.buy : AppConfig.sell),
          _row('Dividend Yield',
              data.dividendYield != null
                  ? '${(data.dividendYield! * 100).toStringAsFixed(2)}%' : '—',
              AppConfig.accent),
        ]),

        const SizedBox(height: 16),

        // ── Size & Leverage ───────────────────────────────────────────────────
        _section('Size & Leverage', [
          _row('Market Cap',
              data.marketCap != null ? _mcap(data.marketCap!) : '—',
              data.marketCap != null && data.marketCap! >= 1e9
                  ? AppConfig.buy : AppConfig.sell),
          _row('Debt / Equity',
              data.debtToEquity != null
                  ? '${data.debtToEquity!.toStringAsFixed(2)}x' : '—',
              data.debtToEquity != null && data.debtToEquity! <= 3
                  ? AppConfig.buy : AppConfig.sell),
        ]),
      ]),
    );
  }

  // ── helpers ──────────────────────────────────────────────────────────────────

  Widget _card({required Widget child}) => Container(
        width:      double.infinity,
        padding:    const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:        AppConfig.bgCard,
          borderRadius: BorderRadius.circular(12),
          border:       Border.all(color: AppConfig.border),
        ),
        child: child,
      );

  Widget _section(String title, List<Widget> rows) => _card(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(
                  color: AppConfig.textSecondary, fontSize: 11,
                  fontWeight: FontWeight.w700, letterSpacing: 0.8)),
          const SizedBox(height: 12),
          ...rows.expand((r) => [r, const Divider(color: AppConfig.border, height: 1)]).toList()
            ..removeLast(),
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

  String _fmt(double? v, {String suffix = ''}) =>
      v != null ? '${v.toStringAsFixed(1)}$suffix' : '—';

  Color _peColor(double? pe) {
    if (pe == null) return AppConfig.textPrimary;
    if (pe < 20)   return AppConfig.buy;
    if (pe < 40)   return AppConfig.hold;
    return AppConfig.sell;
  }

  String _mcap(double v) {
    if (v >= 1e12) return '\$${(v / 1e12).toStringAsFixed(1)}T';
    if (v >= 1e9)  return '\$${(v / 1e9).toStringAsFixed(1)}B';
    return '\$${(v / 1e6).toStringAsFixed(0)}M';
  }
}
