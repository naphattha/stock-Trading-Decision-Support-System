import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'config/app_config.dart';
import 'services/websocket_service.dart';
import 'screens/dashboard_screen.dart';
import 'screens/universe_screen.dart';
import 'screens/checklist_screen.dart';
import 'screens/portfolio_screen.dart';
import 'widgets/bottom_nav.dart';

void main() {
  runApp(const TradingDSSApp());
}

class TradingDSSApp extends StatelessWidget {
  const TradingDSSApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Trading DSS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppConfig.bgDeep,
        cardColor: AppConfig.bgCard,
        colorScheme: const ColorScheme.dark(primary: AppConfig.accent, secondary: AppConfig.accent, surface: AppConfig.bgCard),
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
        useMaterial3: true,
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor:  AppConfig.bgCard,
          labelTextStyle:   WidgetStateProperty.all(
              const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
        ),
      ),
      home: const MainShell(),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  final _ws = WebSocketService.instance;

  static const _screens = [
    DashboardScreen(),
    UniverseScreen(),
    ChecklistScreen(),
    PortfolioScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _ws.connect();
    _ws.startPing();
  }

  @override
  void dispose() {
    _ws.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: BottomNav(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
      ),
    );
  }
}
