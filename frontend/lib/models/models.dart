// ── Existing models (kept) ────────────────────────────────────────────────────

class SignalData {
  final int id; final String ticker; final DateTime timestamp;
  final String? maSignal,rsiSignal,macdSignal,bbSignal,momentumSignal,overallSignal;
  final double? confidence,currentPrice,rsiValue,macdValue,macdSignalValue;
  final double? bbUpper,bbLower,bbMiddle,sma20,sma50,momentumValue;
  final bool? fundamentalOk; final String? fundamentalWarn;
  const SignalData({required this.id,required this.ticker,required this.timestamp,this.maSignal,this.rsiSignal,this.macdSignal,this.bbSignal,this.momentumSignal,this.overallSignal,this.confidence,this.currentPrice,this.rsiValue,this.macdValue,this.macdSignalValue,this.bbUpper,this.bbLower,this.bbMiddle,this.sma20,this.sma50,this.momentumValue,this.fundamentalOk,this.fundamentalWarn});
  factory SignalData.fromJson(Map<String,dynamic> j) => SignalData(id:j['id']??0,ticker:j['ticker']??'',timestamp:DateTime.tryParse(j['timestamp']??'')??DateTime.now(),maSignal:j['ma_signal'],rsiSignal:j['rsi_signal'],macdSignal:j['macd_signal'],bbSignal:j['bb_signal'],momentumSignal:j['momentum_signal'],overallSignal:j['overall_signal'],confidence:(j['confidence']as num?)?.toDouble(),currentPrice:(j['current_price']as num?)?.toDouble(),rsiValue:(j['rsi_value']as num?)?.toDouble(),macdValue:(j['macd_value']as num?)?.toDouble(),macdSignalValue:(j['macd_signal_value']as num?)?.toDouble(),bbUpper:(j['bb_upper']as num?)?.toDouble(),bbLower:(j['bb_lower']as num?)?.toDouble(),bbMiddle:(j['bb_middle']as num?)?.toDouble(),sma20:(j['sma20']as num?)?.toDouble(),sma50:(j['sma50']as num?)?.toDouble(),momentumValue:(j['momentum_value']as num?)?.toDouble(),fundamentalOk:j['fundamental_ok'],fundamentalWarn:j['fundamental_warn']);
}
class WatchlistEntry {
  final String ticker,name,sector,notes; final double? targetPrice,stopLoss; final SignalData? signal;
  const WatchlistEntry({required this.ticker,required this.name,required this.sector,this.targetPrice,this.stopLoss,this.notes='',this.signal});
  factory WatchlistEntry.fromJson(Map<String,dynamic> j) => WatchlistEntry(ticker:j['ticker']??'',name:j['name']??j['ticker']??'',sector:j['sector']??'Unknown',notes:j['notes']??'',targetPrice:(j['target_price']as num?)?.toDouble(),stopLoss:(j['stop_loss']as num?)?.toDouble(),signal:j['signal']!=null?SignalData.fromJson(j['signal']):null);
}
class AlertItem {
  final int id; final String ticker,message,signal; final double price; final DateTime createdAt; final bool discordSent;
  const AlertItem({required this.id,required this.ticker,required this.message,required this.signal,required this.price,required this.createdAt,required this.discordSent});
  factory AlertItem.fromJson(Map<String,dynamic> j) => AlertItem(id:j['id']??0,ticker:j['ticker']??'',message:j['message']??'',signal:j['signal']??'HOLD',price:(j['price']as num?)?.toDouble()??0,createdAt:DateTime.tryParse(j['created_at']??'')??DateTime.now(),discordSent:j['discord_sent']??false);
}
class PortfolioSummary {
  final int totalStocks,buySignals,sellSignals,holdSignals,noSignal; final String lastUpdated;
  const PortfolioSummary({required this.totalStocks,required this.buySignals,required this.sellSignals,required this.holdSignals,required this.noSignal,required this.lastUpdated});
  factory PortfolioSummary.fromJson(Map<String,dynamic> j) => PortfolioSummary(totalStocks:j['total_stocks']??0,buySignals:j['buy_signals']??0,sellSignals:j['sell_signals']??0,holdSignals:j['hold_signals']??0,noSignal:j['no_signal']??0,lastUpdated:j['last_updated']??'');
}
class PricePoint {
  final String date; final double open,high,low,close; final int volume;
  const PricePoint({required this.date,required this.open,required this.high,required this.low,required this.close,required this.volume});
  factory PricePoint.fromJson(Map<String,dynamic> j) => PricePoint(date:j['date']??'',open:(j['open']as num).toDouble(),high:(j['high']as num).toDouble(),low:(j['low']as num).toDouble(),close:(j['close']as num).toDouble(),volume:(j['volume']as num).toInt());
}
class FundamentalData {
  final String ticker,name,sector; final double? marketCap,peRatio,forwardPe,epsTtm,revenueGrowth,profitMargin,debtToEquity,priceToBook,dividendYield; final bool passesFilter; final List<String> filterWarnings; final String? updatedAt;
  const FundamentalData({required this.ticker,required this.name,required this.sector,this.marketCap,this.peRatio,this.forwardPe,this.epsTtm,this.revenueGrowth,this.profitMargin,this.debtToEquity,this.priceToBook,this.dividendYield,required this.passesFilter,required this.filterWarnings,this.updatedAt});
  factory FundamentalData.fromJson(Map<String,dynamic> j) => FundamentalData(ticker:j['ticker']??'',name:j['name']??'',sector:j['sector']??'',marketCap:(j['market_cap']as num?)?.toDouble(),peRatio:(j['pe_ratio']as num?)?.toDouble(),forwardPe:(j['forward_pe']as num?)?.toDouble(),epsTtm:(j['eps_ttm']as num?)?.toDouble(),revenueGrowth:(j['revenue_growth']as num?)?.toDouble(),profitMargin:(j['profit_margin']as num?)?.toDouble(),debtToEquity:(j['debt_to_equity']as num?)?.toDouble(),priceToBook:(j['price_to_book']as num?)?.toDouble(),dividendYield:(j['dividend_yield']as num?)?.toDouble(),passesFilter:j['passes_filter']??true,filterWarnings:List<String>.from(j['filter_warnings']??[]),updatedAt:j['updated_at']);
}
class RegimeData {
  final String ticker; final double adx,plusDi,minusDi,bbWidth; final String regime,regimeStrength,volatilityRegime; final String? dailySignal,weeklySignal; final bool mtfConfluence; final String mtfStrength,recommendedStrategy,strategyNote;
  const RegimeData({required this.ticker,required this.adx,required this.plusDi,required this.minusDi,required this.bbWidth,required this.regime,required this.regimeStrength,required this.volatilityRegime,this.dailySignal,this.weeklySignal,required this.mtfConfluence,required this.mtfStrength,required this.recommendedStrategy,required this.strategyNote});
  factory RegimeData.fromJson(Map<String,dynamic> j) => RegimeData(ticker:j['ticker']??'',adx:(j['adx']as num).toDouble(),plusDi:(j['plus_di']as num).toDouble(),minusDi:(j['minus_di']as num).toDouble(),bbWidth:(j['bb_width']as num).toDouble(),regime:j['regime']??'',regimeStrength:j['regime_strength']??'',volatilityRegime:j['volatility_regime']??'',dailySignal:j['daily_signal'],weeklySignal:j['weekly_signal'],mtfConfluence:j['mtf_confluence']??false,mtfStrength:j['mtf_strength']??'',recommendedStrategy:j['recommended_strategy']??'',strategyNote:j['strategy_note']??'');
}
class RiskData {
  final String ticker,kellyNote; final double entryPrice,atr,suggestedStopLoss,suggestedTakeProfit,rrRatio,fixed1PctValue,fixed2PctValue; final int fixed1PctShares,fixed2PctShares; final double? historicalWinRate,kellyFraction,kellyValue; final int? kellyShares;
  const RiskData({required this.ticker,required this.entryPrice,required this.atr,required this.suggestedStopLoss,required this.suggestedTakeProfit,required this.rrRatio,required this.fixed1PctShares,required this.fixed2PctShares,required this.fixed1PctValue,required this.fixed2PctValue,this.historicalWinRate,this.kellyFraction,this.kellyValue,this.kellyShares,required this.kellyNote});
  factory RiskData.fromJson(Map<String,dynamic> j) => RiskData(ticker:j['ticker']??'',entryPrice:(j['entry_price']as num).toDouble(),atr:(j['atr']as num).toDouble(),suggestedStopLoss:(j['suggested_stop_loss']as num).toDouble(),suggestedTakeProfit:(j['suggested_take_profit']as num).toDouble(),rrRatio:(j['rr_ratio']as num).toDouble(),fixed1PctShares:j['fixed_1pct_shares']??0,fixed2PctShares:j['fixed_2pct_shares']??0,fixed1PctValue:(j['fixed_1pct_value']as num).toDouble(),fixed2PctValue:(j['fixed_2pct_value']as num).toDouble(),historicalWinRate:(j['historical_win_rate']as num?)?.toDouble(),kellyFraction:(j['kelly_fraction']as num?)?.toDouble(),kellyValue:(j['kelly_value']as num?)?.toDouble(),kellyShares:j['kelly_shares'],kellyNote:j['kelly_note']??'');
}

// ── NEW: Universe ─────────────────────────────────────────────────────────────
class UniverseItem {
  final int id; final String ticker,addedBy,notes; final int scanScore; final List<String> criteriaMatched; final double? currentPrice,rsi; final String? fibLevel; final DateTime addedAt;
  const UniverseItem({required this.id,required this.ticker,required this.addedBy,required this.scanScore,required this.criteriaMatched,this.currentPrice,this.rsi,this.fibLevel,required this.notes,required this.addedAt});
  factory UniverseItem.fromJson(Map<String,dynamic> j) => UniverseItem(id:j['id']??0,ticker:j['ticker']??'',addedBy:j['added_by']??'manual',scanScore:j['scan_score']??0,criteriaMatched:List<String>.from(j['criteria_matched']??[]),currentPrice:(j['current_price']as num?)?.toDouble(),rsi:(j['rsi']as num?)?.toDouble(),fibLevel:j['fib_level'],notes:j['notes']??'',addedAt:DateTime.tryParse(j['added_at']??'')??DateTime.now());
}
class ScanResult {
  final String ticker; final int score; final List<String> criteriaMatched; final double? currentPrice,rsi; final String? fibLevel;
  const ScanResult({required this.ticker,required this.score,required this.criteriaMatched,this.currentPrice,this.rsi,this.fibLevel});
  factory ScanResult.fromJson(Map<String,dynamic> j) => ScanResult(ticker:j['ticker']??'',score:j['score']??0,criteriaMatched:List<String>.from(j['criteria_matched']??[]),currentPrice:(j['current_price']as num?)?.toDouble(),rsi:(j['rsi']as num?)?.toDouble(),fibLevel:j['fib_level']);
}

// ── NEW: Checklist ────────────────────────────────────────────────────────────
class ChecklistItem {
  final int id; final String ticker,status,notes; final double targetPrice; final double? suggestedPrice,fib382,fib500,fib618,high52w,low52w; final String? suggestionMethod; final DateTime createdAt; final DateTime? triggeredAt;
  const ChecklistItem({required this.id,required this.ticker,required this.targetPrice,this.suggestedPrice,this.suggestionMethod,this.fib382,this.fib500,this.fib618,this.high52w,this.low52w,required this.status,required this.notes,required this.createdAt,this.triggeredAt});
  factory ChecklistItem.fromJson(Map<String,dynamic> j) => ChecklistItem(id:j['id']??0,ticker:j['ticker']??'',targetPrice:(j['target_price']as num).toDouble(),suggestedPrice:(j['suggested_price']as num?)?.toDouble(),suggestionMethod:j['suggestion_method'],fib382:(j['fib_382']as num?)?.toDouble(),fib500:(j['fib_500']as num?)?.toDouble(),fib618:(j['fib_618']as num?)?.toDouble(),high52w:(j['high_52w']as num?)?.toDouble(),low52w:(j['low_52w']as num?)?.toDouble(),status:j['status']??'WAITING',notes:j['notes']??'',createdAt:DateTime.tryParse(j['created_at']??'')??DateTime.now(),triggeredAt:j['triggered_at']!=null?DateTime.tryParse(j['triggered_at']):null);
}
class BuyPriceData {
  final String ticker,suggestionMethod; final double currentPrice,suggestedBuyPrice,bbLower,support20d,fib382,fib500,fib618,high52w,low52w,upsideToFib382,upsideTo52wHigh;
  const BuyPriceData({required this.ticker,required this.currentPrice,required this.suggestedBuyPrice,required this.suggestionMethod,required this.bbLower,required this.support20d,required this.fib382,required this.fib500,required this.fib618,required this.high52w,required this.low52w,required this.upsideToFib382,required this.upsideTo52wHigh});
  factory BuyPriceData.fromJson(Map<String,dynamic> j) => BuyPriceData(ticker:j['ticker']??'',currentPrice:(j['current_price']as num).toDouble(),suggestedBuyPrice:(j['suggested_buy_price']as num).toDouble(),suggestionMethod:j['suggestion_method']??'',bbLower:(j['bb_lower']as num).toDouble(),support20d:(j['support_20d']as num).toDouble(),fib382:(j['fib_382']as num).toDouble(),fib500:(j['fib_500']as num).toDouble(),fib618:(j['fib_618']as num).toDouble(),high52w:(j['high_52w']as num).toDouble(),low52w:(j['low_52w']as num).toDouble(),upsideToFib382:(j['upside_to_fib_382']as num).toDouble(),upsideTo52wHigh:(j['upside_to_52w_high']as num).toDouble());
}

// ── NEW: Portfolio ────────────────────────────────────────────────────────────
class HoldingItem {
  final int id; final String ticker; final double shares,costBasisPerShare,currentPrice,marketValue,costBasisTotal,unrealizedPnl,pnlPct,actualWeight,targetWeight,weightDiff; final String? dateBought,notes;
  const HoldingItem({required this.id,required this.ticker,required this.shares,required this.costBasisPerShare,required this.currentPrice,required this.marketValue,required this.costBasisTotal,required this.unrealizedPnl,required this.pnlPct,required this.actualWeight,required this.targetWeight,required this.weightDiff,this.dateBought,this.notes});
  factory HoldingItem.fromJson(Map<String,dynamic> j) => HoldingItem(id:j['id']??0,ticker:j['ticker']??'',shares:(j['shares']as num).toDouble(),costBasisPerShare:(j['cost_basis_per_share']as num).toDouble(),currentPrice:(j['current_price']as num).toDouble(),marketValue:(j['market_value']as num).toDouble(),costBasisTotal:(j['cost_basis_total']as num).toDouble(),unrealizedPnl:(j['unrealized_pnl']as num).toDouble(),pnlPct:(j['pnl_pct']as num).toDouble(),actualWeight:(j['actual_weight']as num).toDouble(),targetWeight:(j['target_weight']as num).toDouble(),weightDiff:(j['weight_diff']as num).toDouble(),dateBought:j['date_bought'],notes:j['notes']);
}
class PortfolioSnapshot {
  final List<HoldingItem> holdings; final double totalValue,totalCost,totalPnl,totalPnlPct,equalWeightPct;
  const PortfolioSnapshot({required this.holdings,required this.totalValue,required this.totalCost,required this.totalPnl,required this.totalPnlPct,required this.equalWeightPct});
  factory PortfolioSnapshot.fromJson(Map<String,dynamic> j) => PortfolioSnapshot(holdings:(j['holdings']as List).map((e)=>HoldingItem.fromJson(e)).toList(),totalValue:(j['total_value']as num).toDouble(),totalCost:(j['total_cost']as num).toDouble(),totalPnl:(j['total_pnl']as num).toDouble(),totalPnlPct:(j['total_pnl_pct']as num).toDouble(),equalWeightPct:(j['equal_weight_pct']as num).toDouble());
}
class RecommendationItem {
  final String ticker,signal,reason; final double currentPrice,targetPrice,confidence,upsidePct;
  const RecommendationItem({required this.ticker,required this.currentPrice,required this.targetPrice,required this.signal,required this.confidence,required this.upsidePct,required this.reason});
  factory RecommendationItem.fromJson(Map<String,dynamic> j) => RecommendationItem(ticker:j['ticker']??'',currentPrice:(j['current_price']as num).toDouble(),targetPrice:(j['target_price']as num).toDouble(),signal:j['signal']??'BUY',confidence:(j['confidence']as num).toDouble(),upsidePct:(j['upside_pct']as num).toDouble(),reason:j['reason']??'');
}
