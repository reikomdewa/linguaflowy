import 'package:flutter/material.dart';
import 'package:linguaflow/screens/speak/active_screen/managers/room_global_manager.dart';

class LiveStatsView extends StatelessWidget {
  final RoomGlobalManager manager;

  const LiveStatsView({super.key, required this.manager});

  @override
  Widget build(BuildContext context) {
    // This view mimics the "Overview" swipe in TikTok
    return Container(
      color: Colors.transparent, // Background handled by parent
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            "Live Performance",
            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 30),
          
          _buildStatRow("Total Views", "1.2k"), // Replace with real data from Manager
          _buildStatRow("New Followers", "${manager.roomData?.memberCount ?? 0}"), 
          _buildStatRow("Diamonds Earned", "450"),
          
          const Divider(color: Colors.white24, height: 40),
          
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.tips_and_updates, color: Colors.amber),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Tip: Interact with your audience to boost engagement!",
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 16)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}