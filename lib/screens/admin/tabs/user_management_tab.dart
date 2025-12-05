import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
// -----------------------------------------------------------------------------
// USER MANAGEMENT TAB
// --
// 
// ---------------------------------------------------------------------------
class UserManagementTab extends StatefulWidget {
  const UserManagementTab({super.key});
  @override
  State<UserManagementTab> createState() => _UserManagementTabState();
}

class _UserManagementTabState extends State<UserManagementTab> {
  final TextEditingController _searchController = TextEditingController();
  List<DocumentSnapshot> _searchResults = [];
  Timer? _debounce;

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () => _performSearch(query));
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) { setState(() => _searchResults = []); return; }
    final cleanQuery = query.trim();
    // Simplified logic for brevity - mimics your previous code
    final res = await FirebaseFirestore.instance.collection('users').where('email', isGreaterThanOrEqualTo: cleanQuery).where('email', isLessThan: '$cleanQuery\uf8ff').limit(10).get();
    if(mounted) setState(() => _searchResults = res.docs);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(controller: _searchController, style: TextStyle(color: textColor), decoration: const InputDecoration(hintText: "Search Email...", prefixIcon: Icon(Icons.search), border: OutlineInputBorder()), onChanged: _onSearchChanged),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.builder(
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final data = _searchResults[index].data() as Map<String, dynamic>;
                final uid = _searchResults[index].id;
                final isPremium = data['isPremium'] == true;
                return Card(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  child: ListTile(
                    title: Text(data['email'] ?? 'No Email', style: TextStyle(color: textColor)),
                    subtitle: InkWell(onTap: () => Clipboard.setData(ClipboardData(text: uid)), child: Text("ID: $uid", style: const TextStyle(fontSize: 10, fontFamily: 'monospace'))),
                    trailing: Switch(value: isPremium, onChanged: (val) => FirebaseFirestore.instance.collection('users').doc(uid).update({'isPremium': val})),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}