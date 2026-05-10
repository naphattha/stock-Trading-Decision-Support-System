import 'package:flutter/material.dart';
import '../config/app_config.dart';

class SignalBadge extends StatelessWidget {
  final String? signal;
  final double fontSize;
  final EdgeInsets padding;

  const SignalBadge(
    this.signal, {
    super.key,
    this.fontSize = 11,
    this.padding  = const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
  });

  @override
  Widget build(BuildContext context) {
    final label = signal ?? 'N/A';
    final color = AppConfig.signalColor(signal);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color:        color.withOpacity(0.15),
        border:       Border.all(color: color.withOpacity(0.6)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color:      color,
          fontSize:   fontSize,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

// ── Indicator row used in the detail screen ──────────────────────────────────

class IndicatorRow extends StatelessWidget {
  final String label;
  final String? signal;
  final String value;
  final String? subvalue;

  const IndicatorRow({
    super.key,
    required this.label,
    required this.signal,
    required this.value,
    this.subvalue,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          // Label
          SizedBox(
            width: 160,
            child: Text(
              label,
              style: const TextStyle(color: AppConfig.textSecondary, fontSize: 13),
            ),
          ),
          // Value(s)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: const TextStyle(color: AppConfig.textPrimary, fontSize: 13)),
                if (subvalue != null)
                  Text(subvalue!,
                      style: const TextStyle(
                          color: AppConfig.textSecondary, fontSize: 11)),
              ],
            ),
          ),
          // Badge
          SignalBadge(signal),
        ],
      ),
    );
  }
}
