import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../models/models.dart';
import '../widgets/signal_badge.dart';

class StockCard extends StatelessWidget {
  final WatchlistEntry entry;
  final VoidCallback   onTap;
  final VoidCallback   onRemove;

  const StockCard({
    super.key,
    required this.entry,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final sig   = entry.signal;
    final price = sig?.currentPrice;
    final conf  = sig?.confidence;
    final color = AppConfig.signalColor(sig?.overallSignal);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color:        AppConfig.bgCard,
          borderRadius: BorderRadius.circular(12),
          border:       Border.all(color: AppConfig.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header strip ───────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color:        color.withOpacity(0.08),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                border:       Border(bottom: BorderSide(color: AppConfig.border)),
              ),
              child: Row(
                children: [
                  // Ticker chip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color:        color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      entry.ticker,
                      style: TextStyle(
                        color:      color,
                        fontWeight: FontWeight.w800,
                        fontSize:   13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      entry.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppConfig.textSecondary, fontSize: 12),
                    ),
                  ),
                  // Remove button
                  GestureDetector(
                    onTap: onRemove,
                    child: const Icon(Icons.close, size: 16,
                        color: AppConfig.textSecondary),
                  ),
                ],
              ),
            ),

            // ── Body ───────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(14),
              child: sig == null
                  ? const Center(
                      child: Text('No signal yet',
                          style: TextStyle(color: AppConfig.textSecondary)))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Price + overall signal
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              price != null ? '\$${price.toStringAsFixed(2)}' : '—',
                              style: const TextStyle(
                                color:      AppConfig.textPrimary,
                                fontSize:   20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SignalBadge(
                              sig.overallSignal,
                              fontSize: 12,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 5),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Confidence bar
                        if (conf != null) ...[
                          Row(
                            children: [
                              const Text('Confidence ',
                                  style: TextStyle(
                                      color: AppConfig.textSecondary, fontSize: 11)),
                              Text('${conf.toStringAsFixed(0)}%',
                                  style: TextStyle(
                                      color: color, fontSize: 11,
                                      fontWeight: FontWeight.w700)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value:            (conf / 100).clamp(0, 1),
                              minHeight:        4,
                              backgroundColor:  AppConfig.bgCardAlt,
                              valueColor:       AlwaysStoppedAnimation(color),
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],

                        // Mini indicator row
                        _MiniRow('RSI',   sig.rsiSignal,      '${sig.rsiValue?.toStringAsFixed(1) ?? '—'}'),
                        _MiniRow('MACD',  sig.macdSignal,     '${sig.macdValue?.toStringAsFixed(4) ?? '—'}'),
                        _MiniRow('MA',    sig.maSignal,       'SMA20 ${sig.sma20?.toStringAsFixed(2) ?? '—'}'),
                        _MiniRow('BB',    sig.bbSignal,       '${sig.bbLower?.toStringAsFixed(2) ?? '—'} – ${sig.bbUpper?.toStringAsFixed(2) ?? '—'}'),
                        _MiniRow('Mom',   sig.momentumSignal, '${sig.momentumValue?.toStringAsFixed(2) ?? '—'}%'),

                        // Target / stop-loss badges
                        if (entry.targetPrice != null || entry.stopLoss != null) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            children: [
                              if (entry.targetPrice != null)
                                _PillTag('🎯 \$${entry.targetPrice!.toStringAsFixed(2)}',
                                    AppConfig.buy),
                              if (entry.stopLoss != null)
                                _PillTag('🛑 \$${entry.stopLoss!.toStringAsFixed(2)}',
                                    AppConfig.sell),
                            ],
                          ),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── helpers ──────────────────────────────────────────────────────────────────

class _MiniRow extends StatelessWidget {
  final String  label;
  final String? signal;
  final String  value;
  const _MiniRow(this.label, this.signal, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Text(label,
                style: const TextStyle(
                    color: AppConfig.textSecondary, fontSize: 11)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    color: AppConfig.textPrimary, fontSize: 11)),
          ),
          SignalBadge(signal, fontSize: 10,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2)),
        ],
      ),
    );
  }
}

class _PillTag extends StatelessWidget {
  final String text;
  final Color  color;
  const _PillTag(this.text, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color:        color.withOpacity(0.12),
          border:       Border.all(color: color.withOpacity(0.4)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(text,
            style: TextStyle(color: color, fontSize: 11,
                fontWeight: FontWeight.w600)),
      );
}
