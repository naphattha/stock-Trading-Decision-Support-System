import 'package:flutter/material.dart';
import '../config/app_config.dart';

class BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const BottomNav({super.key, required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color:  AppConfig.bgCard,
        border: Border(top: BorderSide(color: AppConfig.border)),
      ),
      child: NavigationBar(
        backgroundColor:    AppConfig.bgCard,
        indicatorColor:     AppConfig.accent.withOpacity(0.15),
        selectedIndex:      currentIndex,
        onDestinationSelected: onTap,
        labelBehavior:      NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon:          Icon(Icons.candlestick_chart_outlined, color: AppConfig.textSecondary),
            selectedIcon:  Icon(Icons.candlestick_chart,          color: AppConfig.accent),
            label:         'Dashboard',
          ),
          NavigationDestination(
            icon:          Icon(Icons.travel_explore_outlined,    color: AppConfig.textSecondary),
            selectedIcon:  Icon(Icons.travel_explore,             color: AppConfig.universe),
            label:         'Universe',
          ),
          NavigationDestination(
            icon:          Icon(Icons.checklist_outlined,         color: AppConfig.textSecondary),
            selectedIcon:  Icon(Icons.checklist,                  color: AppConfig.checklist),
            label:         'Checklist',
          ),
          NavigationDestination(
            icon:          Icon(Icons.account_balance_outlined,   color: AppConfig.textSecondary),
            selectedIcon:  Icon(Icons.account_balance,            color: AppConfig.portfolio),
            label:         'Portfolio',
          ),
        ],
      ),
    );
  }
}
