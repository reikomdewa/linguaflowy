import 'package:flutter/material.dart';
import 'tabs/analytics_tab.dart';
import 'tabs/promo_codes_tab.dart';
import 'tabs/user_management_tab.dart';
import 'tabs/content_cms_tab.dart';
import 'tabs/leaderboard_tab.dart';
import 'tabs/bug_view_tab.dart';
import 'tabs/reports_tab.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    // 7 Tabs
    _tabController = TabController(length: 7, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text("Admin Dashboard", style: TextStyle(color: textColor)),
        backgroundColor: bgColor,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        bottom: TabBar(
          controller: _tabController,
          tabAlignment: TabAlignment.start,
          padding: EdgeInsets.zero,
          labelPadding: const EdgeInsets.symmetric(horizontal: 6),
          isScrollable: true, // Essential for 7 tabs
          indicatorColor: Colors.amber,
          labelColor: Colors.amber,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(icon: Icon(Icons.bar_chart), text: "Analytics"),
            Tab(icon: Icon(Icons.vpn_key), text: "Codes"),
            Tab(icon: Icon(Icons.people), text: "Users"),
            Tab(icon: Icon(Icons.library_books), text: "CMS"),

            Tab(icon: Icon(Icons.leaderboard), text: "Leaderboard"),
            Tab(icon: Icon(Icons.bug_report), text: "Bugs"),
            Tab(icon: Icon(Icons.bug_report), text: "Reports"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          AnalyticsTab(), // File 2
          PromoCodesTab(), // File 3
          UserManagementTab(), // File 3
          ContentCMSTab(), // File 4

          LeaderboardTab(), // File 5
          BugViewTab(),
          ReportsScreen(), // File 5
        ],
      ),
    );
  }
}
