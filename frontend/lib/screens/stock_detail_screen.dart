import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../config/app_config.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../widgets/signal_badge.dart';
import '../widgets/fundamental_panel.dart';
import '../widgets/risk_panel.dart';
import '../widgets/regime_widget.dart';

class StockDetailScreen extends StatefulWidget {
  final String ticker;
  const StockDetailScreen({super.key, required this.ticker});
  @override
  State<StockDetailScreen> createState() => _StockDetailScreenState();
}

class _StockDetailScreenState extends State<StockDetailScreen>
    with SingleTickerProviderStateMixin {
  final _api = ApiService.instance;
  late TabController _tabs;

  // ── State ────────────────────────────────────────────────────────────────────
  SignalData?       _signal;
  List<SignalData>  _history  = [];
  List<AlertItem>   _alerts   = [];
  List<PricePoint>  _prices   = [];
  FundamentalData?  _fundamental;
  RegimeData?       _regime;
  RiskData?         _risk;

  bool _loading         = true;
  bool _loadingFund     = false;
  bool _loadingRegime   = false;
  bool _loadingRisk     = false;
  String? _error;

  double _portfolioValue = 100000;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
    _tabs.addListener(_onTabChanged);
    _load();
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  void _onTabChanged() {
    if (!_tabs.indexIsChanging) return;
    switch (_tabs.index) {
      case 2: if (_fundamental == null) _loadFundamental(); break;
      case 3: if (_regime == null)      _loadRegime();      break;
      case 4: if (_risk == null)        _loadRisk();        break;
    }
  }

  // ── Loaders ──────────────────────────────────────────────────────────────────

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        _api.fetchLatestSignal(widget.ticker),
        _api.fetchSignalHistory(widget.ticker),
        _api.fetchAlerts(limit: 20),
        _api.fetchPrice(widget.ticker),
      ]);
      setState(() {
        _signal  = results[0] as SignalData?;
        _history = results[1] as List<SignalData>;
        _alerts  = (results[2] as List<AlertItem>)
            .where((a) => a.ticker == widget.ticker).toList();
        _prices  = results[3] as List<PricePoint>;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadFundamental({bool forceRefresh = false}) async {
    setState(() => _loadingFund = true);
    try {
      final d = await _api.fetchFundamental(widget.ticker,
          refresh: forceRefresh);
      setState(() => _fundamental = d);
    } catch (e) {
      _showError(e.toString());
    } finally {
      setState(() => _loadingFund = false);
    }
  }

  Future<void> _loadRegime() async {
    setState(() => _loadingRegime = true);
    try {
      final d = await _api.fetchRegime(widget.ticker);
      setState(() => _regime = d);
    } catch (e) {
      _showError(e.toString());
    } finally {
      setState(() => _loadingRegime = false);
    }
  }

  Future<void> _loadRisk() async {
    setState(() { _loadingRisk = true; _risk = null; });
    try {
      final d = await _api.fetchRisk(widget.ticker,
          portfolio: _portfolioValue);
      setState(() => _risk = d);
    } catch (e) {
      _showError(e.toString());
    } finally {
      setState(() => _loadingRisk = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg), backgroundColor: AppConfig.sell));
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final sig   = _signal;
    final color = AppConfig.signalColor(sig?.overallSignal);

    return Scaffold(
      backgroundColor: AppConfig.bgDeep,
      appBar: AppBar(
        backgroundColor: AppConfig.bgCard,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: AppConfig.textSecondary, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.ticker, style: const TextStyle(
              color: AppConfig.textPrimary, fontSize: 18,
              fontWeight: FontWeight.w800)),
          if (sig?.currentPrice != null)
            Row(children: [
              Text('\$${sig!.currentPrice!.toStringAsFixed(2)}',
                  style: TextStyle(color: color, fontSize: 12,
                      fontWeight: FontWeight.w600)),
              if (sig.fundamentalOk == false) ...[
                const SizedBox(width: 6),
                const Icon(Icons.warning_amber,
                    color: AppConfig.sell, size: 13),
                const Text(' Fund. Warning',
                    style: TextStyle(color: AppConfig.sell, fontSize: 11)),
              ],
            ]),
        ]),
        actions: [
          if (sig != null)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Center(child: SignalBadge(sig.overallSignal,
                  fontSize: 13,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 6))),
            ),
          IconButton(
            icon: const Icon(Icons.refresh, color: AppConfig.accent),
            onPressed: _load,
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: AppConfig.accent,
          labelColor: AppConfig.accent,
          unselectedLabelColor: AppConfig.textSecondary,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: 'Indicators'),
            Tab(text: 'Price Chart'),
            Tab(text: 'Fundamental'),
            Tab(text: 'Regime & MTF'),
            Tab(text: 'Risk Mgmt'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppConfig.accent))
          : _error != null
              ? Center(child: Text(_error!,
                    style: const TextStyle(color: AppConfig.sell)))
              : TabBarView(
                  controller: _tabs,
                  children: [
                    _buildIndicators(),
                    _buildChart(),
                    _buildFundamental(),
                    _buildRegime(),
                    _buildRisk(),
                  ],
                ),
    );
  }

  // ── Tab 0: Indicators ─────────────────────────────────────────────────────────

  Widget _buildIndicators() {
    final s = _signal;
    if (s == null) return _empty('No signal data yet.\nTrigger a refresh.');
    final ts = DateFormat('dd MMM yyyy  HH:mm')
        .format(s.timestamp.toLocal());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          LayoutBuilder(builder: (ctx, cons) {
            final narrow = cons.maxWidth < 340;
            final widgets = [
              _statCol('Price', '\$${s.currentPrice?.toStringAsFixed(2) ?? '—'}', AppConfig.textPrimary),
              _statCol('Signal', s.overallSignal ?? '—', AppConfig.signalColor(s.overallSignal)),
              _statCol('Confidence', '${s.confidence?.toStringAsFixed(0) ?? '—'}%', AppConfig.accent),
            ];
            return narrow
                ? Wrap(spacing: 16, runSpacing: 10, children: widgets)
                : Row(children: widgets.map((w) => Expanded(child: w)).toList());
          }),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: ((s.confidence ?? 0) / 100).clamp(0, 1),
              minHeight: 7,
              backgroundColor: AppConfig.bgCardAlt,
              valueColor: AlwaysStoppedAnimation(
                  AppConfig.signalColor(s.overallSignal)),
            ),
          ),
          const SizedBox(height: 6),
          Text('Last updated  $ts',
              style: const TextStyle(
                  color: AppConfig.textSecondary, fontSize: 11)),
          if (s.fundamentalOk == false) ...[
            const SizedBox(height: 6),
            const Row(children: [
              Icon(Icons.warning_amber, color: AppConfig.sell, size: 14),
              SizedBox(width: 4),
              Flexible(child: Text('Fundamental filter failed — see Fundamental tab',
                  style: TextStyle(color: AppConfig.sell, fontSize: 11))),
            ]),
          ],
        ])),
        const SizedBox(height: 18),
        _card(
          label: 'Indicator Breakdown',
          child: Column(children: [
            IndicatorRow(label: 'MA Crossover (SMA20/50)',
                signal: s.maSignal,
                value: 'SMA20  ${s.sma20?.toStringAsFixed(2) ?? '—'}',
                subvalue: 'SMA50  ${s.sma50?.toStringAsFixed(2) ?? '—'}'),
            const Divider(color: AppConfig.border),
            IndicatorRow(label: 'RSI (14)', signal: s.rsiSignal,
                value: s.rsiValue?.toStringAsFixed(2) ?? '—',
                subvalue: s.rsiValue != null
                    ? (s.rsiValue! < 30 ? 'Oversold (<30)'
                        : s.rsiValue! > 70 ? 'Overbought (>70)'
                        : 'Neutral (30–70)') : null),
            const Divider(color: AppConfig.border),
            IndicatorRow(label: 'MACD (12,26,9)', signal: s.macdSignal,
                value: s.macdValue?.toStringAsFixed(4) ?? '—',
                subvalue: 'Signal  ${s.macdSignalValue?.toStringAsFixed(4) ?? '—'}'),
            const Divider(color: AppConfig.border),
            IndicatorRow(label: 'Bollinger Bands (20)', signal: s.bbSignal,
                value: 'Mid  ${s.bbMiddle?.toStringAsFixed(2) ?? '—'}',
                subvalue:
                    '${s.bbLower?.toStringAsFixed(2) ?? '—'} – ${s.bbUpper?.toStringAsFixed(2) ?? '—'}'),
            const Divider(color: AppConfig.border),
            IndicatorRow(label: 'Momentum ROC (10d)',
                signal: s.momentumSignal,
                value: '${s.momentumValue?.toStringAsFixed(2) ?? '—'}%',
                subvalue: s.momentumValue != null
                    ? (s.momentumValue! > 2 ? 'Strong momentum'
                        : s.momentumValue! < -2 ? 'Weakening' : 'Neutral')
                    : null),
          ]),
        ),
        const SizedBox(height: 18),
        if (_history.isNotEmpty)
          _card(
            label: 'Signal History (last ${_history.length})',
            child: Table(
              columnWidths: const {
                0: FlexColumnWidth(2), 1: FlexColumnWidth(1.5),
                2: FlexColumnWidth(1), 3: FlexColumnWidth(1),
              },
              children: [_tableHeader(), ..._history.map(_tableRow)],
            ),
          ),
      ]),
    );
  }

  TableRow _tableHeader() => TableRow(
        decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppConfig.border))),
        children: ['Date', 'Price', 'Signal', 'Conf.']
            .map((h) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                  child: Text(h, style: const TextStyle(
                      color: AppConfig.textSecondary, fontSize: 11,
                      fontWeight: FontWeight.w600)),
                ))
            .toList(),
      );

  TableRow _tableRow(SignalData h) {
    final c = AppConfig.signalColor(h.overallSignal);
    return TableRow(children: [
      _tCell(DateFormat('dd MMM HH:mm').format(h.timestamp.toLocal()),
          AppConfig.textSecondary),
      _tCell('\$${h.currentPrice?.toStringAsFixed(2) ?? '—'}',
          AppConfig.textPrimary),
      Padding(padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          child: SignalBadge(h.overallSignal, fontSize: 10)),
      _tCell('${h.confidence?.toStringAsFixed(0) ?? '—'}%', c),
    ]);
  }

  Widget _tCell(String t, Color c) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Text(t, style: TextStyle(color: c, fontSize: 11)),
      );

  // ── Tab 1: Price Chart ────────────────────────────────────────────────────────

  Widget _buildChart() {
    if (_prices.isEmpty) return _empty('No price data.');
    final spots = _prices.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.close)).toList();
    final minY   = _prices.map((p) => p.low).reduce((a, b) => a < b ? a : b);
    final maxY   = _prices.map((p) => p.high).reduce((a, b) => a > b ? a : b);
    final last   = _prices.last.close;
    final first  = _prices.first.close;
    final isUp   = last >= first;
    final lc     = isUp ? AppConfig.buy : AppConfig.sell;
    final chg    = (last - first) / first * 100;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 20, runSpacing: 8, children: [
          _statCol('Close',  '\$${last.toStringAsFixed(2)}',                      lc),
          _statCol('Change', '${isUp ? '+' : ''}${chg.toStringAsFixed(2)}%',      lc),
          _statCol('Period', '3 Months',                    AppConfig.textSecondary),
        ]),
        const SizedBox(height: 20),
        Expanded(
          child: LineChart(LineChartData(
            minY: minY * 0.98, maxY: maxY * 1.02,
            gridData: FlGridData(
              show: true,
              horizontalInterval: (maxY - minY) / 5,
              getDrawingHorizontalLine: (_) =>
                  const FlLine(color: AppConfig.border, strokeWidth: 0.5),
              drawVerticalLine: false,
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(sideTitles: SideTitles(
                showTitles: true, reservedSize: 52,
                getTitlesWidget: (v, _) => Text('\$${v.toStringAsFixed(0)}',
                    style: const TextStyle(
                        color: AppConfig.textSecondary, fontSize: 10)),
              )),
              bottomTitles: AxisTitles(sideTitles: SideTitles(
                showTitles: true,
                interval: (_prices.length / 4).roundToDouble(),
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= _prices.length) return const SizedBox.shrink();
                  return Padding(padding: const EdgeInsets.only(top: 4),
                      child: Text(_prices[i].date.substring(5),
                          style: const TextStyle(
                              color: AppConfig.textSecondary, fontSize: 9)));
                },
              )),
              topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            lineBarsData: [LineChartBarData(
              spots: spots, isCurved: true, curveSmoothness: 0.3,
              color: lc, barWidth: 2,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                  show: true, color: lc.withOpacity(0.07)),
            )],
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => AppConfig.bgCard,
                getTooltipItems: (spots) => spots.map((s) {
                  final i = s.x.toInt();
                  final p = i < _prices.length ? _prices[i] : null;
                  return LineTooltipItem(
                    p != null ? '${p.date}\n\$${p.close.toStringAsFixed(2)}' : '',
                    TextStyle(color: lc, fontSize: 11));
                }).toList(),
              ),
            ),
          )),
        ),
      ]),
    );
  }

  // ── Tab 2: Fundamental ────────────────────────────────────────────────────────

  Widget _buildFundamental() {
    if (_loadingFund) {
      return const Center(
          child: CircularProgressIndicator(color: AppConfig.accent));
    }
    if (_fundamental == null) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.analytics_outlined,
            color: AppConfig.textSecondary, size: 40),
        const SizedBox(height: 12),
        const Text('Tap to load fundamental data',
            style: TextStyle(color: AppConfig.textSecondary)),
        const SizedBox(height: 16),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppConfig.accent),
          onPressed: _loadFundamental,
          child: const Text('Load Fundamentals',
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700)),
        ),
      ]));
    }

    return FundamentalPanel(
      data: _fundamental!,
      onRefresh: () => _loadFundamental(forceRefresh: true),
    );
  }

  // ── Tab 3: Regime & MTF ───────────────────────────────────────────────────────

  Widget _buildRegime() {
    if (_loadingRegime) {
      return const Center(
          child: CircularProgressIndicator(color: AppConfig.accent));
    }
    if (_regime == null) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.trending_up, color: AppConfig.textSecondary, size: 40),
        const SizedBox(height: 12),
        const Text('Tap to analyse market regime',
            style: TextStyle(color: AppConfig.textSecondary)),
        const SizedBox(height: 16),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppConfig.accent),
          onPressed: _loadRegime,
          child: const Text('Analyse Regime',
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700)),
        ),
      ]));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        RegimeCard(data: _regime!),
        const SizedBox(height: 80),
      ]),
    );
  }

  // ── Tab 4: Risk Management ────────────────────────────────────────────────────

  Widget _buildRisk() => RiskPanel(
        data:            _risk,
        loading:         _loadingRisk,
        portfolioValue:  _portfolioValue,
        onPortfolioChanged: (v) {
          setState(() => _portfolioValue = v);
          _loadRisk();
        },
      );

  // ── helpers ───────────────────────────────────────────────────────────────────

  Widget _card({required Widget child, String? label}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppConfig.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppConfig.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (label != null) ...[
            Text(label, style: const TextStyle(color: AppConfig.textSecondary,
                fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.8)),
            const SizedBox(height: 12),
          ],
          child,
        ]),
      );

  Widget _statCol(String label, String value, Color color) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(
            color: AppConfig.textSecondary, fontSize: 11)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(
            color: color, fontSize: 18, fontWeight: FontWeight.w800)),
      ]);

  Widget _empty(String msg) => Center(
        child: Text(msg, textAlign: TextAlign.center,
            style: const TextStyle(color: AppConfig.textSecondary, height: 1.6)),
      );

  // ── Alerts tab (preserved) ────────────────────────────────────────────────────
  // (accessible from within Indicators tab's alert list)
}
