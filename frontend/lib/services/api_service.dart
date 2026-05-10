import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/models.dart';

class ApiException implements Exception {
  final String message; final int? statusCode;
  ApiException(this.message, [this.statusCode]);
  @override String toString() => 'ApiException($statusCode): $message';
}

class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();
  final _base = AppConfig.baseUrl;
  final _h = {'Content-Type': 'application/json'};

  Future<dynamic> _get(String p) async { final r=await http.get(Uri.parse('$_base$p')); _chk(r); return jsonDecode(r.body); }
  Future<dynamic> _post(String p,[Map<String,dynamic>? b]) async { final r=await http.post(Uri.parse('$_base$p'),headers:_h,body:b!=null?jsonEncode(b):null); _chk(r); return jsonDecode(r.body); }
  Future<dynamic> _patch(String p,[Map<String,dynamic>? b]) async { final r=await http.patch(Uri.parse('$_base$p'),headers:_h,body:b!=null?jsonEncode(b):null); _chk(r); return jsonDecode(r.body); }
  Future<dynamic> _delete(String p) async { final r=await http.delete(Uri.parse('$_base$p')); _chk(r); return jsonDecode(r.body); }
  void _chk(http.Response r){ if(r.statusCode>=400){ String m=r.body; try{m=(jsonDecode(r.body)as Map)['detail']??m;}catch(_){} throw ApiException(m,r.statusCode); } }

  // ── Watchlist ──────────────────────────────────────────────────────────────
  Future<List<WatchlistEntry>> fetchWatchlist() async { final d=await _get('/signals/latest')as List; return d.map((e)=>WatchlistEntry.fromJson(e)).toList(); }
  Future<void> addTicker(String ticker,{String? notes,double? tp,double? sl}) async => _post('/watchlist',{'ticker':ticker,'notes':notes??'','target_price':tp,'stop_loss':sl});
  Future<void> removeTicker(String ticker) async => _delete('/watchlist/$ticker');

  // ── Signals ────────────────────────────────────────────────────────────────
  Future<void> refreshSignals() async => _post('/signals/refresh');
  Future<SignalData?> fetchLatestSignal(String t) async { try{ final d=await _get('/signals/$t/latest'); return SignalData.fromJson(d); }on ApiException catch(e){ if(e.statusCode==404)return null; rethrow; } }
  Future<List<SignalData>> fetchSignalHistory(String t,{int limit=15}) async { final d=await _get('/signals/$t?limit=$limit')as List; return d.map((e)=>SignalData.fromJson(e)).toList(); }

  // ── Alerts ─────────────────────────────────────────────────────────────────
  Future<List<AlertItem>> fetchAlerts({int limit=30}) async { final d=await _get('/alerts?limit=$limit')as List; return d.map((e)=>AlertItem.fromJson(e)).toList(); }

  // ── Portfolio summary ──────────────────────────────────────────────────────
  Future<PortfolioSummary> fetchSummary() async { final d=await _get('/portfolio/summary'); return PortfolioSummary.fromJson(d); }

  // ── Price ──────────────────────────────────────────────────────────────────
  Future<List<PricePoint>> fetchPrice(String t,{String period='3mo'}) async { final d=await _get('/price/$t?period=$period'); return (d['data']as List).map((e)=>PricePoint.fromJson(e)).toList(); }

  // ── Fundamental ────────────────────────────────────────────────────────────
  Future<FundamentalData> fetchFundamental(String t,{bool refresh=false}) async { final d=await _get('/fundamental/$t${refresh?'?refresh=true':''}'); return FundamentalData.fromJson(d); }

  // ── Regime ─────────────────────────────────────────────────────────────────
  Future<RegimeData> fetchRegime(String t) async { final d=await _get('/regime/$t'); return RegimeData.fromJson(d); }

  // ── Risk ───────────────────────────────────────────────────────────────────
  Future<RiskData> fetchRisk(String t,{double portfolio=100000}) async { final d=await _get('/risk/$t?portfolio=$portfolio'); return RiskData.fromJson(d); }

  // ── Universe Pool ──────────────────────────────────────────────────────────
  Future<void> uploadPoolCsv(List<int> bytes, String filename) async {
    final req = http.MultipartRequest('POST', Uri.parse('$_base/universe/pool/upload'));
    req.files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
    final resp = await req.send();
    if (resp.statusCode >= 400) throw ApiException('Upload failed', resp.statusCode);
  }
  Future<String> downloadPoolCsv() async { final r=await http.get(Uri.parse('$_base/universe/pool/download')); return r.body; }

  // ── Universe ───────────────────────────────────────────────────────────────
  Future<List<UniverseItem>> fetchUniverse() async { final d=await _get('/universe')as List; return d.map((e)=>UniverseItem.fromJson(e)).toList(); }
  Future<void> addToUniverse(String ticker,{String notes=''}) async => _post('/universe/add',{'ticker':ticker,'notes':notes});
  Future<void> removeFromUniverse(String ticker) async => _delete('/universe/$ticker');
  Future<List<ScanResult>> runScan() async { final d=await _post('/universe/scan')as List; return d.map((e)=>ScanResult.fromJson(e)).toList(); }

  // ── Checklist ──────────────────────────────────────────────────────────────
  Future<List<ChecklistItem>> fetchChecklist() async { final d=await _get('/checklist')as List; return d.map((e)=>ChecklistItem.fromJson(e)).toList(); }
  Future<BuyPriceData> fetchBuyPrice(String ticker) async { final d=await _get('/checklist/buy-price/$ticker'); return BuyPriceData.fromJson(d); }
  Future<void> addToChecklist(String ticker, double targetPrice,{String notes=''}) async => _post('/checklist',{'ticker':ticker,'target_price':targetPrice,'notes':notes});
  Future<void> markBought(int id,{required String ticker,required double shares,required double price,String? date}) async => _patch('/checklist/$id/bought',{'ticker':ticker,'shares':shares,'cost_basis_per_share':price,'date_bought':date});
  Future<void> expireChecklist(int id) async => _patch('/checklist/$id/expire');
  Future<void> deleteChecklist(int id) async => _delete('/checklist/$id');

  // ── Portfolio ──────────────────────────────────────────────────────────────
  Future<PortfolioSnapshot> fetchHoldings() async { final d=await _get('/portfolio/holdings'); return PortfolioSnapshot.fromJson(d); }
  Future<List<RecommendationItem>> fetchRecommendations() async { final d=await _get('/portfolio/recommendations')as List; return d.map((e)=>RecommendationItem.fromJson(e)).toList(); }
  Future<void> addPosition(String ticker,double shares,double price,{String? date,String notes=''}) async => _post('/portfolio/positions',{'ticker':ticker,'shares':shares,'cost_basis_per_share':price,'date_bought':date,'notes':notes});
  Future<void> deletePosition(int id) async => _delete('/portfolio/positions/$id');
}
