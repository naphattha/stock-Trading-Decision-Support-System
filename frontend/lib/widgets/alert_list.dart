import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config/app_config.dart';
import '../models/models.dart';
import '../widgets/signal_badge.dart';

class AlertList extends StatelessWidget {
  final List<AlertItem> alerts;

  const AlertList({super.key, required this.alerts});

  @override
  Widget build(BuildContext context) {
    if (alerts.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('No alerts yet.',
              style: TextStyle(color: AppConfig.textSecondary)),
        ),
      );
    }

    return ListView.separated(
      physics:     const NeverScrollableScrollPhysics(),
      shrinkWrap:  true,
      itemCount:   alerts.length,
      separatorBuilder: (_, __) =>
          const Divider(color: AppConfig.border, height: 1),
      itemBuilder: (context, i) {
        final a     = alerts[i];
        final color = AppConfig.signalColor(a.signal);
        final ts    = DateFormat('dd MMM  HH:mm').format(a.createdAt.toLocal());

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color:   i.isEven ? AppConfig.bgCard : AppConfig.bgCardAlt,
          child: Row(
            children: [
              // Colour indicator
              Container(
                width: 3, height: 36,
                decoration: BoxDecoration(
                  color:        color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              // Ticker + timestamp
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a.ticker,
                      style: TextStyle(
                          color:      color,
                          fontWeight: FontWeight.w700,
                          fontSize:   13)),
                  const SizedBox(height: 2),
                  Text(ts,
                      style: const TextStyle(
                          color: AppConfig.textSecondary, fontSize: 11)),
                ],
              ),
              const SizedBox(width: 12),
              // Price
              Expanded(
                child: Text(
                  '\$${a.price.toStringAsFixed(2)}',
                  style: const TextStyle(
                      color: AppConfig.textPrimary, fontSize: 13),
                ),
              ),
              // Signal badge
              SignalBadge(a.signal),
              const SizedBox(width: 8),
              // Discord icon
              Icon(
                Icons.discord,
                size:  16,
                color: a.discordSent
                    ? const Color(0xFF5865F2)
                    : AppConfig.textSecondary.withOpacity(0.3),
              ),
            ],
          ),
        );
      },
    );
  }
}
