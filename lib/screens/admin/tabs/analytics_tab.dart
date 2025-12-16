import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart'; // Add intl to pubspec.yaml for date formatting

class AnalyticsTab extends StatefulWidget {
  const AnalyticsTab({super.key});

  @override
  State<AnalyticsTab> createState() => _AnalyticsTabState();
}

class _AnalyticsTabState extends State<AnalyticsTab> {
  // Cache the future so the chart doesn't reload constantly
  late Future<Map<String, dynamic>> _statsFuture;

  @override
  void initState() {
    super.initState();
    _statsFuture = _fetchRealStats();
  }

  Future<Map<String, dynamic>> _fetchRealStats() async {
    final firestore = FirebaseFirestore.instance;

    // 1. Get Total Users
    final totalSnapshot = await firestore.collection('users').count().get();
    final total = totalSnapshot.count ?? 0;

    // 2. Get Premium Users (Assumes field 'isPremium' == true)
    final premiumSnapshot = await firestore
        .collection('users')
        .where('isPremium', isEqualTo: true)
        .count()
        .get();
    final premium = premiumSnapshot.count ?? 0;

    // 3. Get Active Users (Assumes 'lastActiveAt' is within last 24 hours)
    // If you don't have 'lastActiveAt', this will return 0
    final yesterday = DateTime.now().subtract(const Duration(hours: 24));
    final activeSnapshot = await firestore
        .collection('users')
        .where('lastActiveAt', isGreaterThan: yesterday)
        .count()
        .get();
    final active = activeSnapshot.count ?? 0;

    // 4. Get Data for Graph (Users created in last 7 days)
    // We query the last 7 days of users to build the line chart
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
    final recentUsersFn = await firestore
        .collection('users')
        .where('createdAt', isGreaterThan: sevenDaysAgo)
        .get();

    return {
      'total': total,
      'premium': premium,
      'active': active,
      'revenue': premium * 9.99, // Assuming $9.99 price
      'graphData': recentUsersFn.docs,
    };
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _statsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }

        final data = snapshot.data!;
        final docs = data['graphData'] as List<DocumentSnapshot>;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Realtime Overview",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _StatGrid(
                totalUsers: data['total'],
                premiumCount: data['premium'],
                activeCount: data['active'], // Using real data now
                revenue: data['revenue'],
              ),
              const SizedBox(height: 30),
              const Text(
                "New Users (Last 7 Days)",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Container(
                height: 250,
                padding: const EdgeInsets.only(right: 20),
                child: _UsersGrowthChart(recentDocs: docs),
              ),
            ],
          ),
        );
      },
    );
  }
}

// -----------------------------------------------------------------------------
// WIDGETS
// -----------------------------------------------------------------------------

class _StatGrid extends StatelessWidget {
  final int totalUsers;
  final int premiumCount;
  final int activeCount;
  final double revenue;

  const _StatGrid({
    required this.totalUsers,
    required this.premiumCount,
    required this.activeCount,
    required this.revenue,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      shrinkWrap: true,
      childAspectRatio: 1.5,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _StatCard(
          title: "Total Users",
          value: "$totalUsers",
          color: Colors.blue,
        ),
        _StatCard(
          title: "Premium",
          value: "$premiumCount",
          color: Colors.amber,
        ),
        _StatCard(
          title: "Est. Revenue",
          value: "\$${revenue.toStringAsFixed(0)}",
          color: Colors.green,
        ),
        _StatCard(
          title: "Active (24h)",
          value: "$activeCount",
          color: Colors.purple,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  const _StatCard({
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(color: color)),
        ],
      ),
    );
  }
}

class _UsersGrowthChart extends StatelessWidget {
  final List<DocumentSnapshot> recentDocs;

  const _UsersGrowthChart({required this.recentDocs});

  List<FlSpot> _generateSpots() {
    // Logic: distinct users by Day created
    Map<int, int> daysMap = {};
    final now = DateTime.now();

    // Initialize last 7 days with 0
    for (int i = 6; i >= 0; i--) {
      daysMap[i] = 0;
    }

    for (var doc in recentDocs) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['createdAt'] != null) {
        final date = (data['createdAt'] as Timestamp).toDate();
        final diff = now.difference(date).inDays;
        if (diff >= 0 && diff < 7) {
          // Invert index: 0 = today, 6 = 7 days ago
          // For chart X-axis: 0 = 7 days ago, 6 = today
          daysMap[diff] = (daysMap[diff] ?? 0) + 1;
        }
      }
    }

    List<FlSpot> spots = [];
    for (int i = 0; i < 7; i++) {
      // x: 0 to 6, y: count
      // We map "days ago" to x-axis ascending
      int daysAgo = 6 - i;
      spots.add(FlSpot(i.toDouble(), (daysMap[daysAgo] ?? 0).toDouble()));
    }
    return spots;
  }

  @override
  Widget build(BuildContext context) {
    final spots = _generateSpots();

    return LineChart(
      LineChartData(
        gridData: FlGridData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                // Return simpler labels: "Mon", "Tue"
                final date = DateTime.now().subtract(
                  Duration(days: 6 - value.toInt()),
                );
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    DateFormat('E').format(date), // Requires 'intl' package
                    style: const TextStyle(fontSize: 10),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.amber,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.amber.withValues(alpha: 0.2),
            ),
          ),
        ],
      ),
    );
  }
}
