import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config/app_config.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../widgets/signal_badge.dart';

class PortfolioScreen extends StatefulWidget {
  const PortfolioScreen({super.key});
  @override State<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends State<PortfolioScreen>
    with SingleTickerProviderStateMixin {
  final _api = ApiService.instance;
  late TabController _tabs;

  PortfolioSnapshot? _snapshot;
  List<RecommendationItem> _recs = [];
  bool _loading = false;

  @override
  void initState() { super.initState(); _tabs = TabController(length: 2, vsync: this); _load(); }
  @override void dispose() { _tabs.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([_api.fetchHoldings(), _api.fetchRecommendations()]);
      setState(() {
        _snapshot = results[0] as PortfolioSnapshot;
        _recs     = results[1] as List<RecommendationItem>;
      });
    } catch(e) { _snack('$e', AppConfig.sell); }
    finally    { setState(() => _loading = false); }
  }

  Future<void> _addPositionDialog() async {
    final tickerCtrl = TextEditingController();
    final sharesCtrl = TextEditingController();
    final priceCtrl  = TextEditingController();
    final dateCtrl   = TextEditingController(text: DateFormat('yyyy-MM-dd').format(DateTime.now()));

    await showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: AppConfig.bgCard,
      title: const Text('Add Position', style: TextStyle(color: AppConfig.textPrimary)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        _field(tickerCtrl, 'Ticker',              TextInputType.text),
        const SizedBox(height: 10),
        _field(sharesCtrl, 'Shares',              TextInputType.number),
        const SizedBox(height: 10),
        _field(priceCtrl,  'Cost basis per share', TextInputType.number),
        const SizedBox(height: 10),
        _field(dateCtrl,   'Date bought (yyyy-MM-dd)', TextInputType.datetime),
      ]),
      actions: [
        TextButton(onPressed: ()=>Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppConfig.portfolio),
          onPressed: () async {
            final t = tickerCtrl.text.trim().toUpperCase();
            final s = double.tryParse(sharesCtrl.text);
            final p = double.tryParse(priceCtrl.text);
            if (t.isEmpty || s == null || p == null) return;
            Navigator.pop(context);
            try { await _api.addPosition(t, s, p, date: dateCtrl.text); await _load(); }
            catch(e) { _snack('$e', AppConfig.sell); }
          },
          child: const Text('Add', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    final snap = _snapshot;
    return Scaffold(
      backgroundColor: AppConfig.bgDeep,
      appBar: AppBar(
        backgroundColor: AppConfig.bgCard, elevation: 0,
        title: const Row(children: [
          Icon(Icons.account_balance, color: AppConfig.portfolio, size: 22),
          SizedBox(width: 10),
          Text('Portfolio', style: TextStyle(color: AppConfig.textPrimary, fontWeight: FontWeight.w800)),
        ]),
        actions: [
          IconButton(icon: const Icon(Icons.add, color: AppConfig.portfolio), tooltip: 'Add position', onPressed: _addPositionDialog),
          IconButton(icon: const Icon(Icons.refresh, color: AppConfig.portfolio), onPressed: _load),
        ],
        bottom: TabBar(
          controller: _tabs, indicatorColor: AppConfig.portfolio,
          labelColor: AppConfig.portfolio, unselectedLabelColor: AppConfig.textSecondary,
          tabs: [
            Tab(text: 'Holdings (${snap?.holdings.length ?? 0})'),
            Tab(text: 'Recommendations (${_recs.length})'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppConfig.portfolio))
          : Column(children: [
              if (snap != null) _SummaryBar(snap: snap),
              Expanded(child: TabBarView(controller: _tabs, children: [
                _buildHoldings(snap),
                _buildRecommendations(),
              ])),
            ]),
    );
  }

  Widget _buildHoldings(PortfolioSnapshot? snap) {
    if (snap == null || snap.holdings.isEmpty)
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.account_balance_wallet_outlined, color: AppConfig.textSecondary, size: 48),
        const SizedBox(height: 12),
        const Text('No positions yet.\nTap + to add, or mark a Checklist item as Bought.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppConfig.textSecondary, height: 1.6)),
      ]));

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: snap.holdings.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _HoldingCard(
        item: snap.holdings[i],
        equalWeight: snap.equalWeightPct,
        onDelete: () async {
          // Find position id - for simplicity reload list and find
          final positions = await _api.fetchHoldings();
          // Just reload
          await _load();
        },
      ),
    );
  }

  Widget _buildRecommendations() {
    if (_recs.isEmpty)
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.lightbulb_outline, color: AppConfig.textSecondary, size: 48),
        const SizedBox(height: 12),
        const Text('No recommendations yet.\nItems appear when Checklist price is\ntriggered AND Signal = BUY.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppConfig.textSecondary, height: 1.6)),
      ]));

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _recs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _RecommendationCard(item: _recs[i]),
    );
  }

  void _snack(String msg, Color c) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: c));
  }

  Widget _field(TextEditingController c, String hint, TextInputType kt) => TextField(controller:c,keyboardType:kt,style:const TextStyle(color:AppConfig.textPrimary),decoration:InputDecoration(hintText:hint,hintStyle:const TextStyle(color:AppConfig.textSecondary),filled:true,fillColor:AppConfig.bgDeep,contentPadding:const EdgeInsets.symmetric(horizontal:12,vertical:10),border:OutlineInputBorder(borderRadius:BorderRadius.circular(8),borderSide:const BorderSide(color:AppConfig.border)),enabledBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(8),borderSide:const BorderSide(color:AppConfig.border))));
}

// ── Summary bar ───────────────────────────────────────────────────────────────
class _SummaryBar extends StatelessWidget {
  final PortfolioSnapshot snap;
  const _SummaryBar({required this.snap});
  @override
  Widget build(BuildContext context) {
    final pnlPos = snap.totalPnl >= 0;
    final pnlColor = pnlPos ? AppConfig.buy : AppConfig.sell;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: AppConfig.bgCard,
      child: Row(children: [
        _col('Total Value',  '\$${_fmt(snap.totalValue)}', AppConfig.textPrimary),
        _col('Total Cost',   '\$${_fmt(snap.totalCost)}',  AppConfig.textSecondary),
        _col('Unrealized P&L',
            '${pnlPos?'+':''}\$${_fmt(snap.totalPnl)}  (${pnlPos?'+':''}${snap.totalPnlPct.toStringAsFixed(1)}%)',
            pnlColor),
        _col('Positions', '${snap.holdings.length}', AppConfig.accent),
      ]),
    );
  }
  Widget _col(String l, String v, Color c) => Expanded(child: Column(children: [
    Text(l, style: const TextStyle(color: AppConfig.textSecondary, fontSize: 10)),
    const SizedBox(height: 4),
    Text(v, style: TextStyle(color: c, fontSize: 13, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
  ]));
  String _fmt(double v) => v >= 1000000 ? '${(v/1000000).toStringAsFixed(2)}M' : v >= 1000 ? '${(v/1000).toStringAsFixed(1)}K' : v.toStringAsFixed(2);
}

// ── Holding Card ──────────────────────────────────────────────────────────────
class _HoldingCard extends StatelessWidget {
  final HoldingItem item;
  final double equalWeight;
  final VoidCallback onDelete;
  const _HoldingCard({required this.item, required this.equalWeight, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final pnlPos   = item.unrealizedPnl >= 0;
    final pnlColor = pnlPos ? AppConfig.buy : AppConfig.sell;
    final wDiffColor = item.weightDiff > 5 ? AppConfig.hold : item.weightDiff < -5 ? AppConfig.sell : AppConfig.textSecondary;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppConfig.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: pnlPos ? AppConfig.buy.withOpacity(0.2) : AppConfig.sell.withOpacity(0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header row
        Row(children: [
          Text(item.ticker, style: const TextStyle(color: AppConfig.textPrimary, fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(width: 8),
          Text('${item.shares.toStringAsFixed(0)} shares',
              style: const TextStyle(color: AppConfig.textSecondary, fontSize: 12)),
          if (item.dateBought != null) ...[
            const SizedBox(width: 6),
            Text('· ${item.dateBought}', style: const TextStyle(color: AppConfig.textSecondary, fontSize: 11)),
          ],
          const Spacer(),
          IconButton(icon: const Icon(Icons.delete_outline, color: AppConfig.sell, size: 18), onPressed: onDelete, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
        ]),
        const SizedBox(height: 12),

        // P&L row
        Row(children: [
          Expanded(child: _stat('Cost Basis', '\$${item.costBasisPerShare.toStringAsFixed(2)}/sh', AppConfig.textSecondary)),
          Expanded(child: _stat('Current',    '\$${item.currentPrice.toStringAsFixed(2)}', AppConfig.textPrimary)),
          Expanded(child: _stat('Market Val', '\$${_fmt(item.marketValue)}', AppConfig.textPrimary)),
          Expanded(child: _stat('P&L',
              '${pnlPos?'+':''}\$${_fmt(item.unrealizedPnl)}\n${pnlPos?'+':''}${item.pnlPct.toStringAsFixed(1)}%', pnlColor)),
        ]),

        const SizedBox(height: 12),

        // Weight bar
        Row(children: [
          const Text('Weight ', style: TextStyle(color: AppConfig.textSecondary, fontSize: 11)),
          Text('${item.actualWeight.toStringAsFixed(1)}%',
              style: const TextStyle(color: AppConfig.textPrimary, fontSize: 11, fontWeight: FontWeight.w700)),
          const Text(' vs target ', style: TextStyle(color: AppConfig.textSecondary, fontSize: 11)),
          Text('${equalWeight.toStringAsFixed(1)}%', style: const TextStyle(color: AppConfig.textSecondary, fontSize: 11)),
          const SizedBox(width: 6),
          Text(
            item.weightDiff > 0 ? '+${item.weightDiff.toStringAsFixed(1)}% OW' : '${item.weightDiff.toStringAsFixed(1)}% UW',
            style: TextStyle(color: wDiffColor, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ]),
        const SizedBox(height: 4),
        Stack(children: [
          Container(height: 6, decoration: BoxDecoration(color: AppConfig.bgCardAlt, borderRadius: BorderRadius.circular(3))),
          FractionallySizedBox(
            widthFactor: (item.actualWeight / 100).clamp(0.0, 1.0),
            child: Container(height: 6, decoration: BoxDecoration(
                color: pnlPos ? AppConfig.buy : AppConfig.sell,
                borderRadius: BorderRadius.circular(3))),
          ),
          if (equalWeight > 0)
            Positioned(
              left: MediaQuery.of(context).size.width * (equalWeight / 100) - 60,
              child: Container(width: 2, height: 6, color: AppConfig.accent),
            ),
        ]),
      ]),
    );
  }
  Widget _stat(String l, String v, Color c) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(l, style: const TextStyle(color: AppConfig.textSecondary, fontSize: 10)),
    const SizedBox(height: 2),
    Text(v, style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w600)),
  ]);
  String _fmt(double v) => v.abs() >= 1000 ? '${(v/1000).toStringAsFixed(1)}K' : v.toStringAsFixed(2);
}

// ── Recommendation Card ───────────────────────────────────────────────────────
class _RecommendationCard extends StatelessWidget {
  final RecommendationItem item;
  const _RecommendationCard({required this.item});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppConfig.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppConfig.buy.withOpacity(0.4)),
        boxShadow: [BoxShadow(color: AppConfig.buy.withOpacity(0.05), blurRadius: 8)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(item.ticker, style: const TextStyle(color: AppConfig.textPrimary, fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(width: 8),
          SignalBadge(item.signal, fontSize: 11),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: AppConfig.buy.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
            child: Text('+${item.upsidePct.toStringAsFixed(1)}% upside',
                style: const TextStyle(color: AppConfig.buy, fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          _pill('Current \$${item.currentPrice.toStringAsFixed(2)}', AppConfig.textSecondary),
          const SizedBox(width: 8),
          _pill('Target \$${item.targetPrice.toStringAsFixed(2)}', AppConfig.checklist),
          const SizedBox(width: 8),
          _pill('Conf ${item.confidence.toStringAsFixed(0)}%', AppConfig.accent),
        ]),
        const SizedBox(height: 8),
        Text(item.reason, style: const TextStyle(color: AppConfig.textSecondary, fontSize: 11, height: 1.4)),
      ]),
    );
  }
  Widget _pill(String t, Color c) => Container(padding: const EdgeInsets.symmetric(horizontal:8,vertical:3), decoration: BoxDecoration(color:c.withOpacity(0.1),borderRadius:BorderRadius.circular(6)), child: Text(t,style: TextStyle(color:c,fontSize:11,fontWeight:FontWeight.w600)));
}
