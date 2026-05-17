import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class UniverseScreen extends StatefulWidget {
  const UniverseScreen({super.key});
  @override State<UniverseScreen> createState() => _UniverseScreenState();
}

class _UniverseScreenState extends State<UniverseScreen>
    with SingleTickerProviderStateMixin {
  final _api = ApiService.instance;
  late TabController _tabs;

  List<UniverseItem> _universe = [];
  List<ScanResult>   _scanResults = [];
  bool _loading = false, _scanning = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _loadUniverse();
  }
  @override void dispose() { _tabs.dispose(); super.dispose(); }

  Future<void> _loadUniverse() async {
    setState(() { _loading = true; _error = null; });
    try {
      final u = await _api.fetchUniverse();
      setState(() => _universe = u);
    } catch (e) { setState(() => _error = e.toString()); }
    finally    { setState(() => _loading = false); }
  }

  Future<void> _runScan() async {
    setState(() { _scanning = true; _scanResults = []; });
    try {
      final results = await _api.runScan();
      setState(() => _scanResults = results);
      await _loadUniverse();
      _snack('Scan complete — ${results.length} stocks found', AppConfig.buy);
      _tabs.animateTo(0);
    } catch (e) { _snack('Scan failed: $e', AppConfig.sell); }
    finally    { setState(() => _scanning = false); }
  }

  Future<void> _addManual() async {
    final ctrl = TextEditingController();
    await showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: AppConfig.bgCard,
      title: const Text('Add to Universe', style: TextStyle(color: AppConfig.textPrimary)),
      content: _dlgField(ctrl, 'Ticker (e.g. AAPL)'),
      actions: [
        TextButton(onPressed: ()=>Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppConfig.universe),
          onPressed: () async {
            final t = ctrl.text.trim().toUpperCase();
            if (t.isEmpty) return;
            Navigator.pop(context);
            try { await _api.addToUniverse(t); await _loadUniverse(); }
            catch(e) { _snack('$e', AppConfig.sell); }
          },
          child: const Text('Add', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ),
      ],
    ));
  }

  Future<void> _remove(String ticker) async {
    try { await _api.removeFromUniverse(ticker); await _loadUniverse(); }
    catch(e) { _snack('$e', AppConfig.sell); }
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConfig.bgDeep,
      appBar: AppBar(
        backgroundColor: AppConfig.bgCard, elevation: 0,
        title: Row(children: [
          const Icon(Icons.travel_explore, color: AppConfig.universe, size: 22),
          const SizedBox(width: 10),
          const Text('Universe', style: TextStyle(color: AppConfig.textPrimary, fontWeight: FontWeight.w800)),
          const SizedBox(width: 8),
          _countBadge(_universe.length, AppConfig.universe),
        ]),
        actions: [
          // Run Scan
          _scanning
              ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width:20,height:20,child:CircularProgressIndicator(strokeWidth:2,color:AppConfig.universe)))
              : IconButton(
                  icon: const Icon(Icons.radar, color: AppConfig.universe),
                  tooltip: 'Run auto scan',
                  onPressed: _runScan,
                ),
          IconButton(icon: const Icon(Icons.add, color: AppConfig.universe), tooltip: 'Add manually', onPressed: _addManual),
        ],
        bottom: TabBar(
          controller: _tabs, indicatorColor: AppConfig.universe,
          labelColor: AppConfig.universe, unselectedLabelColor: AppConfig.textSecondary,
          tabs: [
            Tab(text: 'Universe (${_universe.length})'),
            Tab(text: 'Last Scan (${_scanResults.length})'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppConfig.universe))
          : TabBarView(controller: _tabs, children: [
              _buildUniverseList(),
              _buildScanResults(),
            ]),
    );
  }

  Widget _buildUniverseList() {
    if (_universe.isEmpty) return _empty('Universe is empty.\nUpload a CSV and run scan, or add manually.');
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _universe.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _UniverseCard(
        item:     _universe[i],
        onRemove: () => _remove(_universe[i].ticker),
        onAddChecklist: () => _addToChecklist(_universe[i].ticker),
      ),
    );
  }

  Widget _buildScanResults() {
    if (_scanResults.isEmpty) return _empty('No scan results yet.\nTap 📡 to run auto scan.');
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _scanResults.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _ScanResultCard(result: _scanResults[i]),
    );
  }

  Future<void> _addToChecklist(String ticker) async {
    BuyPriceData? bp;
    try { bp = await _api.fetchBuyPrice(ticker); } catch(_) {}

    final priceCtrl = TextEditingController(
        text: bp?.suggestedBuyPrice.toStringAsFixed(2) ?? '');

    await showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: AppConfig.bgCard,
      title: Text('Add $ticker to Checklist',
          style: const TextStyle(color: AppConfig.textPrimary)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        if (bp != null) ...[
          _infoRow('Current Price',   '\$${bp.currentPrice.toStringAsFixed(2)}'),
          _infoRow('Suggested Buy',   '\$${bp.suggestedBuyPrice.toStringAsFixed(2)} (${bp.suggestionMethod})'),
          _infoRow('Fib 61.8%',       '\$${bp.fib618.toStringAsFixed(2)}'),
          _infoRow('Upside (→Fib38)', '+${bp.upsideToFib382.toStringAsFixed(1)}%'),
          const SizedBox(height: 12),
        ],
        _dlgField(priceCtrl, 'Target buy price'),
      ]),
      actions: [
        TextButton(onPressed: ()=>Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppConfig.checklist),
          onPressed: () async {
            final p = double.tryParse(priceCtrl.text);
            if (p == null) return;
            Navigator.pop(context);
            try { await _api.addToChecklist(ticker, p); _snack('$ticker added to checklist ✓', AppConfig.buy); }
            catch(e) { _snack('$e', AppConfig.sell); }
          },
          child: const Text('Add', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ),
      ],
    ));
  }

  Widget _empty(String msg) => Center(child: Padding(padding: const EdgeInsets.all(32),
      child: Text(msg, textAlign: TextAlign.center,
          style: const TextStyle(color: AppConfig.textSecondary, height: 1.6))));

  Widget _infoRow(String l, String v) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Expanded(child: Text(l, style: const TextStyle(color: AppConfig.textSecondary, fontSize: 12))),
        Text(v, style: const TextStyle(color: AppConfig.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
      ]));

  Widget _dlgField(TextEditingController c, String hint) => TextField(controller: c,
      keyboardType: TextInputType.number,
      style: const TextStyle(color: AppConfig.textPrimary),
      decoration: InputDecoration(hintText: hint, hintStyle: const TextStyle(color: AppConfig.textSecondary),
          filled: true, fillColor: AppConfig.bgDeep,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppConfig.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppConfig.border))));

  Widget _countBadge(int n, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
      child: Text('$n', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)));
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _UniverseCard extends StatelessWidget {
  final UniverseItem item;
  final VoidCallback onRemove, onAddChecklist;
  const _UniverseCard({required this.item, required this.onRemove, required this.onAddChecklist});

  @override
  Widget build(BuildContext context) {
    final scoreColor = item.scanScore >= 4 ? AppConfig.buy : item.scanScore >= 3 ? AppConfig.hold : AppConfig.textSecondary;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppConfig.bgCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppConfig.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          // Score circle
          Container(width:36,height:36,
              decoration: BoxDecoration(color: scoreColor.withOpacity(0.15), shape: BoxShape.circle),
              child: Center(child: Text('${item.scanScore}', style: TextStyle(color: scoreColor, fontWeight: FontWeight.w800, fontSize: 16)))),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(item.ticker, style: const TextStyle(color: AppConfig.textPrimary, fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(width: 6),
              if (item.addedBy == 'scan') _pill('AUTO SCAN', AppConfig.universe) else _pill('MANUAL', AppConfig.accent),
            ]),
            if (item.currentPrice != null)
              Text('\$${item.currentPrice!.toStringAsFixed(2)}  RSI ${item.rsi?.toStringAsFixed(1) ?? '—'}',
                  style: const TextStyle(color: AppConfig.textSecondary, fontSize: 11)),
          ])),
          IconButton(icon: const Icon(Icons.playlist_add, color: AppConfig.checklist, size: 20), tooltip: 'Add to Checklist', onPressed: onAddChecklist),
          IconButton(icon: const Icon(Icons.close, color: AppConfig.textSecondary, size: 18), onPressed: onRemove),
        ]),
        if (item.criteriaMatched.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 4, children: item.criteriaMatched.map((c) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: scoreColor.withOpacity(0.08), border: Border.all(color: scoreColor.withOpacity(0.3)), borderRadius: BorderRadius.circular(20)),
              child: Text(c, style: TextStyle(color: scoreColor, fontSize: 10)))).toList()),
        ],
      ]),
    );
  }
  Widget _pill(String t, Color c) => Container(padding: const EdgeInsets.symmetric(horizontal:6,vertical:2), decoration: BoxDecoration(color:c.withOpacity(0.12),borderRadius:BorderRadius.circular(4)), child: Text(t,style: TextStyle(color:c,fontSize:9,fontWeight:FontWeight.w700)));
}

class _ScanResultCard extends StatelessWidget {
  final ScanResult result;
  const _ScanResultCard({required this.result});
  @override
  Widget build(BuildContext context) {
    final c = result.score >= 4 ? AppConfig.buy : AppConfig.hold;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppConfig.bgCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: c.withOpacity(0.4))),
      child: Row(children: [
        Container(width:40,height:40, decoration: BoxDecoration(color:c.withOpacity(0.12),shape:BoxShape.circle), child: Center(child: Text('${result.score}',style: TextStyle(color:c,fontWeight:FontWeight.w900,fontSize:18)))),
        const SizedBox(width:12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(result.ticker, style: const TextStyle(color:AppConfig.textPrimary,fontWeight:FontWeight.w800,fontSize:14)),
          const SizedBox(height:4),
          Text(result.criteriaMatched.join(' · '), style: const TextStyle(color:AppConfig.textSecondary,fontSize:11)),
        ])),
        if (result.currentPrice!=null) Text('\$${result.currentPrice!.toStringAsFixed(2)}', style: TextStyle(color:c,fontWeight:FontWeight.w700)),
      ]),
    );
  }
}
