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

  @override void initState() { super.initState(); _tabs=TabController(length:2,vsync:this); _load(); }
  @override void dispose()   { _tabs.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(()=>_loading=true);
    try {
      final r = await Future.wait([_api.fetchHoldings(),_api.fetchRecommendations()]);
      setState(() { _snapshot=r[0] as PortfolioSnapshot; _recs=r[1] as List<RecommendationItem>; });
    } catch(e){ _snack('$e',AppConfig.sell); }
    finally   { setState(()=>_loading=false); }
  }

  Future<void> _addPositionDialog() async {
    final tCtrl=TextEditingController(), sCtrl=TextEditingController(),
          pCtrl=TextEditingController(), dCtrl=TextEditingController(text:DateFormat('yyyy-MM-dd').format(DateTime.now()));
    await showDialog(context:context,builder:(_)=>AlertDialog(
      backgroundColor: AppConfig.bgCard,
      title:const Text('Add Position',style:TextStyle(color:AppConfig.textPrimary)),
      content:Column(mainAxisSize:MainAxisSize.min,children:[
        _f(tCtrl,'Ticker',TextInputType.text),                          const SizedBox(height:10),
        _f(sCtrl,'Shares',TextInputType.number),                        const SizedBox(height:10),
        _f(pCtrl,'Cost basis per share',TextInputType.number),          const SizedBox(height:10),
        _f(dCtrl,'Date bought (yyyy-MM-dd)',TextInputType.datetime),
      ]),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Cancel')),
        ElevatedButton(
          style:ElevatedButton.styleFrom(backgroundColor:AppConfig.portfolio),
          onPressed:() async {
            final t=tCtrl.text.trim().toUpperCase(); final s=double.tryParse(sCtrl.text); final p=double.tryParse(pCtrl.text);
            if (t.isEmpty||s==null||p==null) return;
            Navigator.pop(context);
            try { await _api.addPosition(t,s,p,date:dCtrl.text); await _load(); }
            catch(e){ _snack('$e',AppConfig.sell); }
          },
          child:Text('Add',style:TextStyle(color:Colors.white,fontWeight:FontWeight.w700)),
        ),
      ],
    ));
  }

  Future<void> _deletePosition(HoldingItem item) async {
    try {
      await _api.deletePosition(item.id);
      await _load();
      _snack('Position deleted', AppConfig.buy);
    } catch(e) { _snack('Delete failed: $e', AppConfig.sell); }
  }

  Future<void> _remove(String ticker) async {
    try { await _api.removeFromUniverse(ticker); await _loadUniverse(); }
    catch(e) { _snack('$e', AppConfig.sell); }
  }

  void _snack(String msg, Color color) {
    if(!mounted)return; 
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(msg),backgroundColor:color));
  }

  Widget _f(TextEditingController c,String h,TextInputType k)=>TextField(controller:c,keyboardType:k,style:const TextStyle(color:AppConfig.textPrimary),decoration:InputDecoration(hintText:h,hintStyle:const TextStyle(color:AppConfig.textSecondary),filled:true,fillColor:AppConfig.bgDeep,contentPadding:const EdgeInsets.symmetric(horizontal:12,vertical:10),border:OutlineInputBorder(borderRadius:BorderRadius.circular(8),borderSide:const BorderSide(color:AppConfig.border)),enabledBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(8),borderSide:const BorderSide(color:AppConfig.border))));

  @override
  Widget build(BuildContext context) {
    final snap=_snapshot;
    return Scaffold(
      backgroundColor: AppConfig.bgDeep,
      appBar: AppBar(
        backgroundColor:AppConfig.bgCard, elevation:0,
        title:const Row(children:[
          Icon(Icons.account_balance,color:AppConfig.portfolio,size:22),
          SizedBox(width:10),
          Text('Portfolio',style:TextStyle(color:AppConfig.textPrimary,fontWeight:FontWeight.w800)),
        ]),
        actions:[
          IconButton(icon:const Icon(Icons.add,color:AppConfig.portfolio),tooltip:'Add position',onPressed:_addPositionDialog),
          IconButton(icon:const Icon(Icons.refresh,color:AppConfig.portfolio),onPressed:_load),
        ],
        bottom:TabBar(
          controller:_tabs,indicatorColor:AppConfig.portfolio,
          labelColor:AppConfig.portfolio,unselectedLabelColor:AppConfig.textSecondary,
          tabs:[
            Tab(text:'Holdings (${snap?.holdings.length??0})'),
            Tab(text:'Recs (${_recs.length})'),
          ],
        ),
      ),
      body:_loading
          ? const Center(child:CircularProgressIndicator(color:AppConfig.portfolio))
          : Column(children:[
              if (snap!=null) _SummaryBar(snap:snap),
              Expanded(child:TabBarView(controller:_tabs,children:[
                _buildHoldings(snap),
                _buildRecs(),
              ])),
            ]),
    );
  }

  Widget _buildHoldings(PortfolioSnapshot? snap) {
    if (snap==null||snap.holdings.isEmpty)
      return const Center(child:Padding(padding:EdgeInsets.all(32),child:Text('No positions yet.\nTap + to add, or mark a Checklist item as Bought.',textAlign:TextAlign.center,style:TextStyle(color:AppConfig.textSecondary,height:1.6))));
    return ListView.separated(
      padding:const EdgeInsets.all(16),
      itemCount:snap.holdings.length,
      separatorBuilder:(_,__)=>const SizedBox(height:10),
      itemBuilder:(_,i)=>_HoldingCard(item:snap.holdings[i],equalWeight:snap.equalWeightPct,onDelete:()=>_deletePosition(snap.holdings[i])),
    );
  }

  Widget _buildRecs() {
    if (_recs.isEmpty)
      return const Center(child:Padding(padding:EdgeInsets.all(32),child:Text('No recommendations yet.\nItems appear when Checklist price\nis triggered AND Signal = BUY.',textAlign:TextAlign.center,style:TextStyle(color:AppConfig.textSecondary,height:1.6))));
    return ListView.separated(
      padding:const EdgeInsets.all(16),
      itemCount:_recs.length,
      separatorBuilder:(_,__)=>const SizedBox(height:10),
      itemBuilder:(_,i)=>_RecommendationCard(item:_recs[i]),
    );
  }

  void _snack(String m,Color c){ if(!mounted)return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(m),backgroundColor:c)); }
  Widget _f(TextEditingController c,String h,TextInputType k)=>TextField(controller:c,keyboardType:k,style:const TextStyle(color:AppConfig.textPrimary),decoration:InputDecoration(hintText:h,hintStyle:const TextStyle(color:AppConfig.textSecondary),filled:true,fillColor:AppConfig.bgDeep,contentPadding:const EdgeInsets.symmetric(horizontal:12,vertical:10),border:OutlineInputBorder(borderRadius:BorderRadius.circular(8),borderSide:const BorderSide(color:AppConfig.border)),enabledBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(8),borderSide:const BorderSide(color:AppConfig.border))));
}

// ── Summary Bar — 2×2 on mobile ───────────────────────────────────────────────
class _SummaryBar extends StatelessWidget {
  final PortfolioSnapshot snap;
  const _SummaryBar({required this.snap});

  @override
  Widget build(BuildContext context) {
    final pnlPos   = snap.totalPnl >= 0;
    final pnlColor = pnlPos ? AppConfig.buy : AppConfig.sell;
    final narrow   = MediaQuery.of(context).size.width < 540;

    final items = [
      _SumItem('Total Value',   '\$${_fmt(snap.totalValue)}',  AppConfig.textPrimary),
      _SumItem('Total Cost',    '\$${_fmt(snap.totalCost)}',   AppConfig.textSecondary),
      _SumItem('P&L',
          '${pnlPos?'+':''}\$${_fmt(snap.totalPnl)}\n${pnlPos?'+':''}${snap.totalPnlPct.toStringAsFixed(1)}%',
          pnlColor),
      _SumItem('Positions',     '${snap.holdings.length}',     AppConfig.accent),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal:12,vertical:10),
      color: AppConfig.bgCard,
      child: narrow
          ? Column(children:[
              Row(children:items.sublist(0,2).map((i)=>Expanded(child:_sumCell(i))).toList()),
              const SizedBox(height:8),
              Row(children:items.sublist(2,4).map((i)=>Expanded(child:_sumCell(i))).toList()),
            ])
          : Row(children:items.map((i)=>Expanded(child:_sumCell(i))).toList()),
    );
  }

  Widget _sumCell(_SumItem i) => Column(children:[
    Text(i.label,style:const TextStyle(color:AppConfig.textSecondary,fontSize:10)),
    const SizedBox(height:3),
    Text(i.value,style:TextStyle(color:i.color,fontSize:12,fontWeight:FontWeight.w700),textAlign:TextAlign.center),
  ]);

  static String _fmt(double v) => v.abs()>=1000000?'${(v/1000000).toStringAsFixed(2)}M':v.abs()>=1000?'${(v/1000).toStringAsFixed(1)}K':v.toStringAsFixed(2);
}
class _SumItem { final String label,value; final Color color; const _SumItem(this.label,this.value,this.color); }

// ── Holding Card — Wrap stats on mobile ───────────────────────────────────────
class _HoldingCard extends StatelessWidget {
  final HoldingItem item;
  final double equalWeight;
  final VoidCallback onDelete;
  const _HoldingCard({required this.item,required this.equalWeight,required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final pnlPos   = item.unrealizedPnl>=0;
    final pnlColor = pnlPos?AppConfig.buy:AppConfig.sell;
    final wColor   = item.weightDiff>5?AppConfig.hold:item.weightDiff<-5?AppConfig.sell:AppConfig.textSecondary;
    final narrow   = MediaQuery.of(context).size.width<540;

    return Container(
      padding:const EdgeInsets.all(14),
      decoration:BoxDecoration(
        color:AppConfig.bgCard,borderRadius:BorderRadius.circular(12),
        border:Border.all(color:pnlPos?AppConfig.buy.withOpacity(0.2):AppConfig.sell.withOpacity(0.2)),
      ),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        // Header
        Row(children:[
          Text(item.ticker,style:const TextStyle(color:AppConfig.textPrimary,fontWeight:FontWeight.w800,fontSize:15)),
          const SizedBox(width:8),
          Text('${item.shares.toStringAsFixed(0)} sh',style:const TextStyle(color:AppConfig.textSecondary,fontSize:12)),
          if (item.dateBought!=null)...[const SizedBox(width:6),Text('· ${item.dateBought}',style:const TextStyle(color:AppConfig.textSecondary,fontSize:11))],
          const Spacer(),
          GestureDetector(onTap:onDelete,child:const Icon(Icons.delete_outline,color:AppConfig.sell,size:18)),
        ]),
        const SizedBox(height:10),

        // Stats — wrap on mobile
        narrow
          ? Wrap(spacing:12,runSpacing:8,children:[
              _stat('Cost','\$${item.costBasisPerShare.toStringAsFixed(2)}/sh',AppConfig.textSecondary),
              _stat('Now', '\$${item.currentPrice.toStringAsFixed(2)}',AppConfig.textPrimary),
              _stat('Value','\$${_fmt(item.marketValue)}',AppConfig.textPrimary),
              _stat('P&L','${pnlPos?'+':''}\$${_fmt(item.unrealizedPnl)} (${pnlPos?'+':''}${item.pnlPct.toStringAsFixed(1)}%)',pnlColor),
            ])
          : Row(children:[
              Expanded(child:_stat('Cost Basis','\$${item.costBasisPerShare.toStringAsFixed(2)}/sh',AppConfig.textSecondary)),
              Expanded(child:_stat('Current',   '\$${item.currentPrice.toStringAsFixed(2)}',AppConfig.textPrimary)),
              Expanded(child:_stat('Mkt Value', '\$${_fmt(item.marketValue)}',AppConfig.textPrimary)),
              Expanded(child:_stat('P&L','${pnlPos?'+':''}\$${_fmt(item.unrealizedPnl)}\n${pnlPos?'+':''}${item.pnlPct.toStringAsFixed(1)}%',pnlColor)),
            ]),

        const SizedBox(height:10),

        // Weight bar
        Row(children:[
          Text('Weight ',style:const TextStyle(color:AppConfig.textSecondary,fontSize:11)),
          Text('${item.actualWeight.toStringAsFixed(1)}%',style:const TextStyle(color:AppConfig.textPrimary,fontSize:11,fontWeight:FontWeight.w700)),
          Text(' / target ${equalWeight.toStringAsFixed(1)}%',style:const TextStyle(color:AppConfig.textSecondary,fontSize:11)),
          const SizedBox(width:6),
          Text(item.weightDiff>0?'+${item.weightDiff.toStringAsFixed(1)}% OW':'${item.weightDiff.toStringAsFixed(1)}% UW',
              style:TextStyle(color:wColor,fontSize:11,fontWeight:FontWeight.w600)),
        ]),
        const SizedBox(height:4),
        ClipRRect(borderRadius:BorderRadius.circular(3),child:LinearProgressIndicator(
          value:(item.actualWeight/100).clamp(0.0,1.0),minHeight:5,
          backgroundColor:AppConfig.bgCardAlt,
          valueColor:AlwaysStoppedAnimation(pnlPos?AppConfig.buy:AppConfig.sell),
        )),
      ]),
    );
  }

  Widget _stat(String l,String v,Color c)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Text(l,style:const TextStyle(color:AppConfig.textSecondary,fontSize:10)),
    const SizedBox(height:2),
    Text(v,style:TextStyle(color:c,fontSize:12,fontWeight:FontWeight.w600)),
  ]);
  static String _fmt(double v)=>v.abs()>=1000?'${(v/1000).toStringAsFixed(1)}K':v.toStringAsFixed(2);
}

// ── Recommendation Card ───────────────────────────────────────────────────────
class _RecommendationCard extends StatelessWidget {
  final RecommendationItem item;
  const _RecommendationCard({required this.item});
  @override
  Widget build(BuildContext context) => Container(
    padding:const EdgeInsets.all(14),
    decoration:BoxDecoration(color:AppConfig.bgCard,borderRadius:BorderRadius.circular(12),border:Border.all(color:AppConfig.buy.withOpacity(0.4))),
    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[
        Text(item.ticker,style:const TextStyle(color:AppConfig.textPrimary,fontWeight:FontWeight.w800,fontSize:16)),
        const SizedBox(width:8),
        SignalBadge(item.signal,fontSize:11),
        const Spacer(),
        Container(padding:const EdgeInsets.symmetric(horizontal:8,vertical:3),decoration:BoxDecoration(color:AppConfig.buy.withOpacity(0.12),borderRadius:BorderRadius.circular(6)),
            child:Text('+${item.upsidePct.toStringAsFixed(1)}%',style:const TextStyle(color:AppConfig.buy,fontSize:12,fontWeight:FontWeight.w700))),
      ]),
      const SizedBox(height:8),
      Wrap(spacing:8,runSpacing:4,children:[
        _pill('Now \$${item.currentPrice.toStringAsFixed(2)}',AppConfig.textSecondary),
        _pill('Target \$${item.targetPrice.toStringAsFixed(2)}',AppConfig.checklist),
        _pill('Conf ${item.confidence.toStringAsFixed(0)}%',AppConfig.accent),
      ]),
      const SizedBox(height:6),
      Text(item.reason,style:const TextStyle(color:AppConfig.textSecondary,fontSize:11,height:1.4)),
    ]),
  );
  Widget _pill(String t,Color c)=>Container(padding:const EdgeInsets.symmetric(horizontal:8,vertical:3),decoration:BoxDecoration(color:c.withOpacity(0.1),borderRadius:BorderRadius.circular(6)),child:Text(t,style:TextStyle(color:c,fontSize:11,fontWeight:FontWeight.w600)));
}
