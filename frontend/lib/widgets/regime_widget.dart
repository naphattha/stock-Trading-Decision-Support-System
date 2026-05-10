import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../models/models.dart';

class RegimeBadge extends StatelessWidget {
  final String regime;
  final String? strength;
  final double fontSize;

  const RegimeBadge(this.regime, {super.key, this.strength, this.fontSize = 11});

  @override
  Widget build(BuildContext context) {
    final color = _color(regime);
    final icon  = _icon(regime);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color:        color.withOpacity(0.12),
        border:       Border.all(color: color.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: fontSize + 2),
        const SizedBox(width: 4),
        Text(
          strength != null ? '$regime · $strength' : regime,
          style: TextStyle(color: color, fontSize: fontSize,
              fontWeight: FontWeight.w700, letterSpacing: 0.5),
        ),
      ]),
    );
  }

  static Color _color(String r) {
    switch (r) {
      case 'TRENDING':   return const Color(0xFF00D4FF);
      case 'RANGING':    return AppConfig.hold;
      default:           return AppConfig.textSecondary;
    }
  }

  static IconData _icon(String r) {
    switch (r) {
      case 'TRENDING':   return Icons.trending_up;
      case 'RANGING':    return Icons.swap_horiz;
      default:           return Icons.horizontal_rule;
    }
  }
}

// ── Full regime card for detail screen ───────────────────────────────────────

class RegimeCard extends StatelessWidget {
  final RegimeData data;
  const RegimeCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final regimeColor = RegimeBadge._color(data.regime);
    final mtfColor    = data.mtfConfluence ? AppConfig.buy : AppConfig.sell;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // ── Regime overview ─────────────────────────────────────────────────────
      _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          RegimeBadge(data.regime, strength: data.regimeStrength, fontSize: 12),
          const SizedBox(width: 8),
          _volBadge(),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          _stat('ADX',     data.adx.toStringAsFixed(1),     regimeColor),
          _stat('+DI',     data.plusDi.toStringAsFixed(1),  AppConfig.buy),
          _stat('−DI',     data.minusDi.toStringAsFixed(1), AppConfig.sell),
          _stat('BB Width','${data.bbWidth.toStringAsFixed(1)}%', AppConfig.accent),
        ]),
      ])),

      const SizedBox(height: 14),

      // ── Multi-timeframe ──────────────────────────────────────────────────────
      _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Multi-Timeframe Analysis',
            style: TextStyle(color: AppConfig.textSecondary, fontSize: 11,
                fontWeight: FontWeight.w700, letterSpacing: 0.8)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _tfBox('Daily',  data.dailySignal)),
          const SizedBox(width: 12),
          Expanded(child: _tfBox('Weekly', data.weeklySignal)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Icon(
            data.mtfConfluence ? Icons.check_circle : Icons.cancel,
            color: mtfColor, size: 18,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'MTF ${data.mtfStrength}: '
              '${data.mtfConfluence ? "Timeframes aligned" : "Timeframes disagree"}',
              style: TextStyle(color: mtfColor, fontSize: 12,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ]),
      ])),

      const SizedBox(height: 14),

      // ── Strategy recommendation ──────────────────────────────────────────────
      _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Strategy Recommendation',
            style: TextStyle(color: AppConfig.textSecondary, fontSize: 11,
                fontWeight: FontWeight.w700, letterSpacing: 0.8)),
        const SizedBox(height: 10),
        Text(data.recommendedStrategy,
            style: const TextStyle(color: AppConfig.accent, fontSize: 13,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(data.strategyNote,
            style: const TextStyle(color: AppConfig.textSecondary,
                fontSize: 12, height: 1.6)),
      ])),
    ]);
  }

  Widget _volBadge() {
    final color = data.volatilityRegime == 'HIGH'
        ? AppConfig.sell
        : data.volatilityRegime == 'LOW'
            ? AppConfig.hold
            : AppConfig.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color:        color.withOpacity(0.1),
        border:       Border.all(color: color.withOpacity(0.4)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text('VOL ${data.volatilityRegime}',
          style: TextStyle(color: color, fontSize: 10,
              fontWeight: FontWeight.w700)),
    );
  }

  Widget _stat(String label, String value, Color color) => Expanded(
        child: Column(children: [
          Text(label, style: const TextStyle(
              color: AppConfig.textSecondary, fontSize: 10)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: color, fontSize: 16,
              fontWeight: FontWeight.w800)),
        ]),
      );

  Widget _tfBox(String label, String? signal) {
    final c = AppConfig.signalColor(signal);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color:        c.withOpacity(0.08),
        border:       Border.all(color: c.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(children: [
        Text(label, style: const TextStyle(
            color: AppConfig.textSecondary, fontSize: 11)),
        const SizedBox(height: 6),
        Text(signal ?? '—', style: TextStyle(color: c, fontSize: 15,
            fontWeight: FontWeight.w800)),
      ]),
    );
  }

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
}
