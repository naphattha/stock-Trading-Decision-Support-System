import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config/app_config.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../widgets/signal_badge.dart';

class ChecklistScreen extends StatefulWidget {
  const ChecklistScreen({super.key});
  @override State<ChecklistScreen> createState() => _ChecklistScreenState();
}

class _ChecklistScreenState extends State<ChecklistScreen> {
  final _api = ApiService.instance;
  List<ChecklistItem> _items = [];
  Map<String, double> _currentPrices = {};
  bool _loading = false;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await _api.fetchChecklist();
      // Fetch current prices for WAITING/TRIGGERED items
      final prices = <String, double>{};
      for (final item in items.where((i) => i.status == 'WAITING' || i.status == 'TRIGGERED')) {
        try {
          final prices2 = await _api.fetchPrice(item.ticker, period: '5d');
          if (prices2.isNotEmpty) prices[item.ticker] = prices2.last.close;
        } catch(_) {}
      }
      setState(() { _items = items; _currentPrices = prices; });
    } catch(e) { _snack('$e', AppConfig.sell); }
    finally    { setState(() => _loading = false); }
  }

  Future<void> _showBoughtDialog(ChecklistItem item) async {
    final sharesCtrl = TextEditingController();
    final priceCtrl  = TextEditingController(
        text: (_currentPrices[item.ticker] ?? item.targetPrice).toStringAsFixed(2));
    final dateCtrl   = TextEditingController(
        text: DateFormat('yyyy-MM-dd').format(DateTime.now()));

    await showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: AppConfig.bgCard,
      title: Text('Mark ${item.ticker} as Bought',
          style: const TextStyle(color: AppConfig.textPrimary)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        _dlgField(sharesCtrl, 'Number of shares', TextInputType.number),
        const SizedBox(height: 10),
        _dlgField(priceCtrl, 'Price paid per share', TextInputType.number),
        const SizedBox(height: 10),
        _dlgField(dateCtrl, 'Date (yyyy-MM-dd)', TextInputType.datetime),
      ]),
      actions: [
        TextButton(onPressed: ()=>Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppConfig.buy),
          onPressed: () async {
            final shares = double.tryParse(sharesCtrl.text);
            final price  = double.tryParse(priceCtrl.text);
            if (shares == null || price == null) return;
            Navigator.pop(context);
            try {
              await _api.markBought(item.id, ticker: item.ticker,
                  shares: shares, price: price, date: dateCtrl.text);
              await _load();
              _snack('${item.ticker} moved to Portfolio ✓', AppConfig.buy);
            } catch(e) { _snack('$e', AppConfig.sell); }
          },
          child: const Text('Confirm', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ),
      ],
    ));
  }

  Future<void> _showAddDialog() async {
    final tickerCtrl = TextEditingController();
    final priceCtrl  = TextEditingController();
    BuyPriceData? bp;

    await showDialog(context: context, builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => AlertDialog(
        backgroundColor: AppConfig.bgCard,
        title: const Text('Add to Checklist',
            style: TextStyle(color: AppConfig.textPrimary)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Expanded(child: _dlgField(tickerCtrl, 'Ticker', TextInputType.text)),
            const SizedBox(width: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppConfig.accent),
              onPressed: () async {
                final t = tickerCtrl.text.trim().toUpperCase();
                if (t.isEmpty) return;
                try {
                  bp = await _api.fetchBuyPrice(t);
                  priceCtrl.text = bp!.suggestedBuyPrice.toStringAsFixed(2);
                  setS(() {});
                } catch(e) { _snack('$e', AppConfig.sell); }
              },
              child: const Text('Calc', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700)),
            ),
          ]),
          const SizedBox(height: 10),
          if (bp != null) ...[
            _infoRow('Current', '\$${bp!.currentPrice.toStringAsFixed(2)}'),
            _infoRow('BB Lower', '\$${bp!.bbLower.toStringAsFixed(2)}'),
            _infoRow('Fib 61.8%', '\$${bp!.fib618.toStringAsFixed(2)}'),
            _infoRow('Fib 50%', '\$${bp!.fib500.toStringAsFixed(2)}'),
            _infoRow('Fib 38.2%', '\$${bp!.fib382.toStringAsFixed(2)}'),
            _infoRow('Upside → Fib38', '+${bp!.upsideToFib382.toStringAsFixed(1)}%'),
            const SizedBox(height: 8),
          ],
          _dlgField(priceCtrl, 'Target buy price', TextInputType.number),
        ]),
        actions: [
          TextButton(onPressed: ()=>Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppConfig.checklist),
            onPressed: () async {
              final t = tickerCtrl.text.trim().toUpperCase();
              final p = double.tryParse(priceCtrl.text);
              if (t.isEmpty || p == null) return;
              Navigator.pop(context);
              try { await _api.addToChecklist(t, p); await _load(); }
              catch(e) { _snack('$e', AppConfig.sell); }
            },
            child: const Text('Add', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final waiting   = _items.where((i) => i.status == 'WAITING').length;
    final triggered = _items.where((i) => i.status == 'TRIGGERED').length;

    return Scaffold(
      backgroundColor: AppConfig.bgDeep,
      appBar: AppBar(
        backgroundColor: AppConfig.bgCard, elevation: 0,
        title: Row(children: [
          const Icon(Icons.checklist, color: AppConfig.checklist, size: 22),
          const SizedBox(width: 10),
          const Text('Checklist', style: TextStyle(color: AppConfig.textPrimary, fontWeight: FontWeight.w800)),
          const SizedBox(width: 8),
          if (triggered > 0) _pill('$triggered triggered', AppConfig.buy),
          const SizedBox(width: 4),
          _pill('$waiting waiting', AppConfig.hold),
        ]),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: AppConfig.checklist), onPressed: _load),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        backgroundColor: AppConfig.checklist,
        icon:  const Icon(Icons.add, color: Colors.white),
        label: const Text('Add', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppConfig.checklist))
          : _items.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.playlist_add_check, color: AppConfig.textSecondary, size: 48),
                  const SizedBox(height: 12),
                  const Text('No items in checklist yet.',
                      style: TextStyle(color: AppConfig.textSecondary)),
                ]))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _ChecklistCard(
                    item:         _items[i],
                    currentPrice: _currentPrices[_items[i].ticker],
                    onBought:     () => _showBoughtDialog(_items[i]),
                    onExpire:     () async { await _api.expireChecklist(_items[i].id); await _load(); },
                    onDelete:     () async { await _api.deleteChecklist(_items[i].id); await _load(); },
                  ),
                ),
    );
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  Widget _pill(String t, Color c) => Container(padding: const EdgeInsets.symmetric(horizontal:8,vertical:2), decoration: BoxDecoration(color:c.withOpacity(0.15),borderRadius:BorderRadius.circular(20)), child: Text(t,style: TextStyle(color:c,fontSize:11,fontWeight:FontWeight.w700)));
  Widget _dlgField(TextEditingController c, String hint, TextInputType kt) => TextField(controller:c,keyboardType:kt,style:const TextStyle(color:AppConfig.textPrimary),decoration:InputDecoration(hintText:hint,hintStyle:const TextStyle(color:AppConfig.textSecondary),filled:true,fillColor:AppConfig.bgDeep,border:OutlineInputBorder(borderRadius:BorderRadius.circular(8),borderSide:const BorderSide(color:AppConfig.border)),enabledBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(8),borderSide:const BorderSide(color:AppConfig.border))));
  Widget _infoRow(String l, String v) => Padding(padding:const EdgeInsets.symmetric(vertical:2),child:Row(children:[Expanded(child:Text(l,style:const TextStyle(color:AppConfig.textSecondary,fontSize:11))),Text(v,style:const TextStyle(color:AppConfig.textPrimary,fontSize:11,fontWeight:FontWeight.w600))]));
}

// ── Checklist Card ─────────────────────────────────────────────────────────────

class _ChecklistCard extends StatelessWidget {
  final ChecklistItem item;
  final double? currentPrice;
  final VoidCallback onBought, onExpire, onDelete;
  const _ChecklistCard({required this.item, this.currentPrice, required this.onBought, required this.onExpire, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final statusColor = AppConfig.statusColor(item.status);
    final isTriggered = item.status == 'TRIGGERED';
    final isActive    = item.status == 'WAITING' || isTriggered;

    // Progress: how close current price is to target (lower = closer for buy)
    double? progress;
    if (currentPrice != null && item.high52w != null && item.high52w! > item.targetPrice) {
      final range = item.high52w! - item.targetPrice;
      progress = ((item.high52w! - currentPrice!) / range).clamp(0.0, 1.0);
    }

    return Container(
      decoration: BoxDecoration(
        color:  AppConfig.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isTriggered ? AppConfig.buy.withOpacity(0.5) : AppConfig.border),
        boxShadow: isTriggered ? [BoxShadow(color: AppConfig.buy.withOpacity(0.08), blurRadius: 8)] : null,
      ),
      child: Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.06),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            border: Border(bottom: BorderSide(color: AppConfig.border)),
          ),
          child: Row(children: [
            Text(item.ticker, style: const TextStyle(color: AppConfig.textPrimary, fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(width: 8),
            _statusBadge(item.status, statusColor),
            if (isTriggered) ...[
              const SizedBox(width: 6),
              const Text('🔔 Price reached!', style: TextStyle(color: AppConfig.buy, fontSize: 11, fontWeight: FontWeight.w600)),
            ],
            const Spacer(),
            Text(DateFormat('dd MMM').format(item.createdAt),
                style: const TextStyle(color: AppConfig.textSecondary, fontSize: 11)),
          ]),
        ),
        // Body
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Prices row
            Row(children: [
              Expanded(child: _priceCol('Current', currentPrice != null ? '\$${currentPrice!.toStringAsFixed(2)}' : '—',
                  currentPrice != null && currentPrice! <= item.targetPrice ? AppConfig.buy : AppConfig.textPrimary)),
              Expanded(child: _priceCol('Target', '\$${item.targetPrice.toStringAsFixed(2)}', statusColor)),
              if (item.suggestedPrice != null)
                Expanded(child: _priceCol('Suggested', '\$${item.suggestedPrice!.toStringAsFixed(2)} (${item.suggestionMethod ?? ''})', AppConfig.textSecondary)),
            ]),

            // Progress bar
            if (progress != null && isActive) ...[
              const SizedBox(height: 10),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Progress to target', style: TextStyle(color: AppConfig.textSecondary, fontSize: 11)),
                Text('${(progress * 100).toStringAsFixed(0)}%',
                    style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 4),
              ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(
                value: progress, minHeight: 6, backgroundColor: AppConfig.bgCardAlt,
                valueColor: AlwaysStoppedAnimation(statusColor),
              )),
            ],

            // Fib levels
            if (item.fib382 != null) ...[
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 4, children: [
                _fibPill('Fib 38.2%', item.fib382!),
                _fibPill('Fib 50%',   item.fib500!),
                _fibPill('Fib 61.8%', item.fib618!),
                if (item.high52w != null) _fibPill('52w High', item.high52w!),
              ]),
            ],

            // Actions
            if (isActive) ...[
              const SizedBox(height: 12),
              Row(children: [
                if (isTriggered) Expanded(child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: AppConfig.buy, padding: const EdgeInsets.symmetric(vertical: 10)),
                  icon: const Icon(Icons.shopping_cart, size: 16, color: Colors.white),
                  label: const Text('Bought', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  onPressed: onBought,
                )),
                if (isTriggered) const SizedBox(width: 8),
                Expanded(child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: AppConfig.border), padding: const EdgeInsets.symmetric(vertical: 10)),
                  icon: const Icon(Icons.cancel_outlined, size: 16, color: AppConfig.textSecondary),
                  label: const Text('Expire', style: TextStyle(color: AppConfig.textSecondary)),
                  onPressed: onExpire,
                )),
                const SizedBox(width: 8),
                IconButton(icon: const Icon(Icons.delete_outline, color: AppConfig.sell, size: 20), onPressed: onDelete),
              ]),
            ],
          ]),
        ),
      ]),
    );
  }

  Widget _priceCol(String l, String v, Color c) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(l, style: const TextStyle(color: AppConfig.textSecondary, fontSize: 10)),
    const SizedBox(height: 3),
    Text(v, style: TextStyle(color: c, fontSize: 13, fontWeight: FontWeight.w700)),
  ]);

  Widget _statusBadge(String s, Color c) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: c.withOpacity(0.12), border: Border.all(color: c.withOpacity(0.4)), borderRadius: BorderRadius.circular(6)),
      child: Text(s, style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.w700)));

  Widget _fibPill(String l, double v) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: AppConfig.bgCardAlt, borderRadius: BorderRadius.circular(4), border: Border.all(color: AppConfig.border)),
      child: Text('$l  \$${v.toStringAsFixed(2)}', style: const TextStyle(color: AppConfig.textSecondary, fontSize: 10)));
}
