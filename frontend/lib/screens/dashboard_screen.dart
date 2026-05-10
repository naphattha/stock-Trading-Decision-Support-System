import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../widgets/stock_card.dart';
import '../widgets/alert_list.dart';
import 'stock_detail_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _api = ApiService.instance;

  List<WatchlistEntry> _watchlist = [];
  List<AlertItem>      _alerts    = [];
  PortfolioSummary?    _summary;

  bool   _loading       = false;
  bool   _refreshing    = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ── data ────────────────────────────────────────────────────────────────────

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        _api.fetchWatchlist(),
        _api.fetchAlerts(),
        _api.fetchSummary(),
      ]);
      setState(() {
        _watchlist = results[0] as List<WatchlistEntry>;
        _alerts    = results[1] as List<AlertItem>;
        _summary   = results[2] as PortfolioSummary;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _refreshSignals() async {
    setState(() => _refreshing = true);
    try {
      await _api.refreshSignals();
      await Future.delayed(const Duration(seconds: 2)); // wait for bg task
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Signals refreshed ✓'),
            backgroundColor: AppConfig.buy,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Refresh failed: $e'),
              backgroundColor: AppConfig.sell),
        );
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  // ── dialogs ─────────────────────────────────────────────────────────────────

  Future<void> _showAddDialog() async {
    final tickerCtrl  = TextEditingController();
    final notesCtrl   = TextEditingController();
    final targetCtrl  = TextEditingController();
    final stopCtrl    = TextEditingController();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppConfig.bgCard,
        title: const Text('Add to Watchlist',
            style: TextStyle(color: AppConfig.textPrimary)),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _dlgField(tickerCtrl,  'Ticker (e.g. AAPL)',   TextInputType.text),
            const SizedBox(height: 10),
            _dlgField(targetCtrl, 'Target price (optional)', TextInputType.number),
            const SizedBox(height: 10),
            _dlgField(stopCtrl,   'Stop-loss (optional)',    TextInputType.number),
            const SizedBox(height: 10),
            _dlgField(notesCtrl,  'Notes (optional)',        TextInputType.text),
          ]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: AppConfig.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppConfig.accent),
            onPressed: () async {
              final ticker = tickerCtrl.text.trim().toUpperCase();
              if (ticker.isEmpty) return;
              Navigator.pop(context);
              try {
                await _api.addTicker(
                  ticker,
                  notes:       notesCtrl.text.trim(),
                  targetPrice: double.tryParse(targetCtrl.text),
                  stopLoss:    double.tryParse(stopCtrl.text),
                );
                await _load();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'),
                        backgroundColor: AppConfig.sell),
                  );
                }
              }
            },
            child: const Text('Add', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmRemove(String ticker) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppConfig.bgCard,
        title: Text('Remove $ticker?',
            style: const TextStyle(color: AppConfig.textPrimary)),
        content: const Text('This will remove the ticker from your watchlist.',
            style: TextStyle(color: AppConfig.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppConfig.sell),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _api.removeTicker(ticker);
      await _load();
    }
  }

  // ── build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConfig.bgDeep,
      appBar: _buildAppBar(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed:   _showAddDialog,
        backgroundColor: AppConfig.accent,
        icon:  const Icon(Icons.add, color: Colors.black),
        label: const Text('Add Ticker',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppConfig.accent))
          : _error != null
              ? _buildError()
              : _buildBody(),
    );
  }

  AppBar _buildAppBar() => AppBar(
        backgroundColor:  AppConfig.bgCard,
        elevation:        0,
        title: Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: AppConfig.accent.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.candlestick_chart,
                color: AppConfig.accent, size: 18),
          ),
          const SizedBox(width: 10),
          const Text('Trading DSS',
              style: TextStyle(color: AppConfig.textPrimary,
                  fontWeight: FontWeight.w700, fontSize: 17)),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppConfig.accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text('US Market',
                style: TextStyle(color: AppConfig.accent, fontSize: 10)),
          ),
        ]),
        actions: [
          if (_refreshing)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(child: SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppConfig.accent))),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh, color: AppConfig.accent),
              tooltip: 'Refresh Signals',
              onPressed: _refreshSignals,
            ),
          IconButton(
            icon: const Icon(Icons.refresh_outlined,
                color: AppConfig.textSecondary),
            tooltip: 'Reload',
            onPressed: _load,
          ),
        ],
      );

  Widget _buildError() => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.wifi_off, color: AppConfig.sell, size: 48),
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: AppConfig.textSecondary)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _load,
            style: ElevatedButton.styleFrom(backgroundColor: AppConfig.accent),
            child: const Text('Retry', style: TextStyle(color: Colors.black)),
          ),
        ]),
      );

  Widget _buildBody() {
    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth > 900;
      return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Summary cards ──────────────────────────────────────────────────
          if (_summary != null) _SummaryRow(summary: _summary!),
          const SizedBox(height: 24),

          // ── Watchlist ──────────────────────────────────────────────────────
          _SectionHeader(
            title: 'Watchlist',
            count: _watchlist.length,
            icon:  Icons.bar_chart,
          ),
          const SizedBox(height: 12),
          _watchlist.isEmpty
              ? _EmptyState(
                  icon:    Icons.add_chart,
                  message: 'No stocks yet.\nTap + to add your first ticker.',
                )
              : GridView.builder(
                  shrinkWrap:       true,
                  physics:          const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount:    wide ? 3 : 2,
                    childAspectRatio:  wide ? 1.1 : 0.9,
                    crossAxisSpacing:  12,
                    mainAxisSpacing:   12,
                  ),
                  itemCount: _watchlist.length,
                  itemBuilder: (_, i) {
                    final entry = _watchlist[i];
                    return StockCard(
                      entry:    entry,
                      onTap:    () => _openDetail(entry.ticker),
                      onRemove: () => _confirmRemove(entry.ticker),
                    );
                  },
                ),

          const SizedBox(height: 32),

          // ── Alerts ─────────────────────────────────────────────────────────
          _SectionHeader(
            title: 'Recent Alerts',
            count: _alerts.length,
            icon:  Icons.notifications_active_outlined,
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color:        AppConfig.bgCard,
              borderRadius: BorderRadius.circular(12),
              border:       Border.all(color: AppConfig.border),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AlertList(alerts: _alerts),
            ),
          ),

          const SizedBox(height: 80),
        ]),
      );
    });
  }

  void _openDetail(String ticker) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StockDetailScreen(ticker: ticker),
      ),
    ).then((_) => _load());
  }

  Widget _dlgField(TextEditingController ctrl, String hint, TextInputType kbType) =>
      TextField(
        controller: ctrl,
        keyboardType: kbType,
        style: const TextStyle(color: AppConfig.textPrimary),
        decoration: InputDecoration(
          hintText:      hint,
          hintStyle:     const TextStyle(color: AppConfig.textSecondary),
          filled:        true,
          fillColor:     AppConfig.bgDeep,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide:   const BorderSide(color: AppConfig.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide:   const BorderSide(color: AppConfig.border),
          ),
        ),
      );
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  final PortfolioSummary summary;
  const _SummaryRow({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 12, runSpacing: 12, children: [
      _SummaryCard('Total',      summary.totalStocks.toString(), AppConfig.accent),
      _SummaryCard('🟢 BUY',    summary.buySignals.toString(),  AppConfig.buy),
      _SummaryCard('🔴 SELL',   summary.sellSignals.toString(), AppConfig.sell),
      _SummaryCard('🟡 HOLD',   summary.holdSignals.toString(), AppConfig.hold),
      _SummaryCard('No Signal', summary.noSignal.toString(),    AppConfig.textSecondary),
    ]);
  }
}

class _SummaryCard extends StatelessWidget {
  final String label, value;
  final Color  color;
  const _SummaryCard(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Container(
        width:   140,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color:        AppConfig.bgCard,
          borderRadius: BorderRadius.circular(10),
          border:       Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: TextStyle(color: color, fontSize: 11,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(color: color, fontSize: 28,
                  fontWeight: FontWeight.w800)),
        ]),
      );
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final String title;
  final int    count;
  final IconData icon;
  const _SectionHeader(
      {required this.title, required this.count, required this.icon,
       this.label = ''});

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, color: AppConfig.accent, size: 18),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(
                color: AppConfig.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color:        AppConfig.accent.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text('$count',
              style: const TextStyle(color: AppConfig.accent, fontSize: 12,
                  fontWeight: FontWeight.w700)),
        ),
      ]);
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String   message;
  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) => Container(
        height: 160,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color:        AppConfig.bgCard,
          borderRadius: BorderRadius.circular(12),
          border:       Border.all(color: AppConfig.border),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: AppConfig.textSecondary, size: 36),
          const SizedBox(height: 10),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppConfig.textSecondary, fontSize: 13, height: 1.5)),
        ]),
      );
}
